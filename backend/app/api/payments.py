from typing import Any, Dict, Union
from fastapi import APIRouter, Body, Depends, HTTPException, BackgroundTasks
from sqlalchemy.orm import Session
from app.database.session import get_db
from app.schemas.bookings import PaymentRequest, PaymentResponse
from app.services.payment_services import PayPalService
from app.models.payments import Payment
from app.models.bookings import Booking
from app.auth.dependencies import get_current_user
from app.models.admin import Admin
from app.models.user import User
from app.services.payment_tasks import check_payment_status

router = APIRouter()

@router.get("/payment/{payment_id}", response_model=Dict[str, Any])
def get_payment_details(
    payment_id: int,
    db: Session = Depends(get_db),
    current_user: Union[User, Admin] = Depends(get_current_user)  # Require authentication
):
    # Fetch payment from the database
    payment = db.query(Payment).filter(Payment.id == payment_id).first()
    
    if not payment:
        raise HTTPException(status_code=404, detail="Payment not found")

    # Ensure only the user who made the payment or an admin can access it
    if isinstance(current_user, User) and payment.user_id != current_user.id:
        raise HTTPException(status_code=403, detail="You are not authorized to view this payment")

    return {
        "id": payment.id,
        "order_id": payment.order_id,
        "amount": payment.amount,
        "currency": payment.currency,
        "status": payment.status,
        "created_at": payment.created_at,
        "booking_id": payment.booking_id
    }


@router.post("/capture-order/{order_id}")
def capture_order(
    order_id: str,
    db: Session = Depends(get_db),
    current_user: Union[User, Admin] = Depends(get_current_user)  # Require authentication
):
    paypal_service = PayPalService()

    # Fetch payment from the database
    payment = db.query(Payment).filter(Payment.order_id == order_id).first()

    if not payment:
        raise HTTPException(status_code=404, detail="Payment not found")

    # Ensure only the owner of the payment or an admin can capture it
    if isinstance(current_user, User) and payment.user_id != current_user.id:
        raise HTTPException(status_code=403, detail="You are not authorized to capture this payment")

    try:
        capture_result = paypal_service.capture_order(order_id)

        # Extract payment status from PayPal response
        payment_status = capture_result.get("status", "failed")
        payment.status = payment_status

        # Update associated booking status if payment is successful
        if payment_status == "COMPLETED" and payment.booking:
            payment.booking.status = "paid"

        db.commit()
        db.refresh(payment)
        
        # If booking exists, refresh it too
        if payment.booking:
            db.refresh(payment.booking)

        return {
            "status": payment_status,
            "details": capture_result
        }
    except Exception as e:
        db.rollback()
        raise HTTPException(status_code=400, detail=str(e))

@router.post("/verify-order/{order_id}")
def verify_paypalorder(
    order_id: str,
    db: Session = Depends(get_db),
    current_user: Union[User, Admin] = Depends(get_current_user),
):
    # Debug the input
    print(f"Verifying order with ID: {order_id}")
    
    # Fetch payment from DB using PayPal order ID with more careful comparison
    # Try case-insensitive comparison
    payment = db.query(Payment).filter(
        Payment.order_id.ilike(f"%{order_id}%")
    ).first()
    
    # If not found, try with exact match
    if not payment:
        print(f"Payment not found with ilike match, trying exact match for: {order_id}")
        payment = db.query(Payment).filter(Payment.order_id == order_id).first()
        
    # If still not found, log all available order IDs for debugging
    if not payment:
        all_payments = db.query(Payment).all()
        print(f"Payment not found. Available order IDs in database:")
        for p in all_payments:
            print(f"  - '{p.order_id}'")
        raise HTTPException(status_code=404, detail="Payment not found")

    # Only allow the user who made the payment or an admin
    if isinstance(current_user, User) and payment.user_id != current_user.id:
        raise HTTPException(status_code=403, detail="You are not authorized to verify this payment")

    # Use your PayPal utility to verify the order
    paypal_service = PayPalService() # Make sure this is properly initialized
    try:
        order_details = paypal_service.verify_order(order_id)
    except Exception as e:
        raise HTTPException(status_code=502, detail=f"Failed to verify order: {str(e)}")

    order_status = order_details.get("status")

    # Update payment status in DB if payment is completed
    if order_status == "COMPLETED":
        payment.status = "COMPLETED"  # Or "paid", depending on your schema
        db.commit()
        return {
            "message": "Payment verified successfully",
            "order_status": order_status,
            "payment_id": payment.id,
            "verified": True
        }
    else:
        return {
            "message": f"Order is not completed yet (status: {order_status})",
            "order_status": order_status,
            "payment_id": payment.id,
            "verified": False
        }

# Webhook handler for PayPal payment status updates
@router.post("/webhook/paypal")
async def handle_paypal_webhook(
    payload: Dict[str, Any] = Body(...),
    db: Session = Depends(get_db)
):
    """Handle PayPal webhooks for payment status updates"""
    event_type = payload.get("event_type")
    resource = payload.get("resource", {})
    order_id = resource.get("id")
    
    if not order_id:
        raise HTTPException(status_code=400, detail="Invalid webhook payload")
    
    # Find associated payment
    payment = db.query(Payment).filter(Payment.order_id == order_id).first()
    
    if not payment:
        raise HTTPException(status_code=404, detail="Payment not found")
    
    # Update payment status based on event type
    if event_type == "PAYMENT.CAPTURE.COMPLETED":
        payment.status = "COMPLETED"
        
        # Update booking status
        if payment.booking:
            payment.booking.status = "paid"
            
        db.commit()
    elif event_type == "PAYMENT.CAPTURE.DENIED":
        payment.status = "DENIED"
        db.commit()
    
    return {"status": "success"}