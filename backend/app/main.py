# from datetime import timedelta
# from app.auth.dependencies import verify_password
# from fastapi import Depends, FastAPI, HTTPException
# from fastapi.middleware.cors import CORSMiddleware
# from fastapi.security import OAuth2PasswordRequestForm
# from requests import Session
# from streamlit import status
# from app.api import stations, bookings, payments, routes, admin
# from app.core.config import settings
# from app.database.session import engine, get_db
# from app.database import base
# from backend.app.models.admin import Admin
# from dependencies import ACCESS_TOKEN_EXPIRE_MINUTES, UserRole, create_access_token


# # Create database tables
# base.Base.metadata.create_all(bind=engine)

# app = FastAPI(title=settings.PROJECT_NAME)

# # CORS middleware
# app.add_middleware(
#     CORSMiddleware,
#     allow_origins=["*"],           #settings.ALLOWED_HOSTS,
#     allow_credentials=True,
#     allow_methods=["*"],
#     allow_headers=["*"],
# )

# # Include API routers
# app.include_router(stations.router, prefix="/stations", tags=["stations"])
# app.include_router(bookings.router, prefix="/bookings", tags=["bookings"])
# app.include_router(payments.router, prefix="/payments", tags=["payments"])
# app.include_router(routes.router, prefix="/routes", tags=["routes"])
# app.include_router(admin.router, prefix="/admin", tags=["admin"])

# @app.get("/")
# def health_check():
#     return {"status": "healthy"}

from datetime import datetime, timedelta
from typing import Dict, Any, Union

from fastapi import Depends, FastAPI, HTTPException, status
from fastapi.middleware.cors import CORSMiddleware
from fastapi.security import OAuth2PasswordRequestForm
from fastapi.openapi.utils import get_openapi
from sqlalchemy.orm import Session
from app.api import stations, bookings, payments, routes, admin
from app.core.config import settings
from app.database.session import engine, get_db
from app.database import base
from app.models.admin import Admin
from app.models.user import User
from app.schemas.auth import Token  # Import the actual Token schema
from app.auth.dependencies import (
    ACCESS_TOKEN_EXPIRE_MINUTES, 
    UserRole, 
    create_access_token,
    get_current_user,
    get_password_hash,
    verify_password
)
from app.schemas.user import UserCreate, UserResponse, UserWithRoleResponse

# Create database tables
base.Base.metadata.create_all(bind=engine)

app = FastAPI(title=settings.PROJECT_NAME,debug=True)

# CORS middleware
app.add_middleware(
    CORSMiddleware,
    allow_origins=[""],
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)

# Include API routers
app.include_router(stations.router, prefix="/stations", tags=["stations"])
app.include_router(bookings.router, prefix="/bookings", tags=["bookings"])
app.include_router(payments.router, prefix="/payments", tags=["payments"])
app.include_router(routes.router, prefix="/routes", tags=["routes"])
app.include_router(admin.router, prefix="/admin", tags=["admin"])

# Custom OpenAPI for Swagger UI with security scheme
from fastapi.openapi.utils import get_openapi

def custom_openapi():
    if app.openapi_schema:
        return app.openapi_schema

    openapi_schema = get_openapi(
        title=settings.PROJECT_NAME,
        version="1.0.0",
        description="Bus Ticket Booking System API",
        routes=app.routes,
    )

    # Don't overwrite components, just add the security scheme
    components = openapi_schema.get("components", {})
    security_schemes = components.get("securitySchemes", {})

    security_schemes["bearerAuth"] = {
        "type": "http",
        "scheme": "bearer",
        "bearerFormat": "JWT",
    }

    components["securitySchemes"] = security_schemes
    openapi_schema["components"] = components

    # Apply security globally
    for path in openapi_schema["paths"].values():
        for operation in path.values():
            operation.setdefault("security", [{"bearerAuth": []}])

    app.openapi_schema = openapi_schema
    return app.openapi_schema


app.openapi = custom_openapi

@app.get("/")
def health_check():
    return {"status": "healthy"}

def authenticate_user(db: Session, username: str, password: str):
    print("🔍 Looking up user or admin:", username)

    # First, check if it's an admin
    admin = db.query(Admin).filter(Admin.username == username).first()
    if admin:
        print("👤 Found admin:", admin.username)
        if verify_password(password, admin.hashed_password):
            print("🔐 Password match for admin")
            return admin
        else:
            print("❌ Admin password mismatch")
            return None

    # If not an admin, try checking the user table
    user = db.query(User).filter(User.username == username).first()
    if user:
        print("👤 Found user:", user.username)
        if verify_password(password, user.hashed_password):
            print("🔐 Password match for user")
            return user
        else:
            print("❌ User password mismatch")
            return None

    print("❓ No admin or user found with that username")
    return None

@app.post("/token", response_model=Token)
async def login_for_access_token(
    form_data: OAuth2PasswordRequestForm = Depends(), 
    db: Session = Depends(get_db)
):
    try:
        print("🟡 Login attempt received")
        print(f"➡️ Username: {form_data.username}")

        # Verify user credentials
        user = authenticate_user(db, form_data.username, form_data.password)
        
        if not user:
            print("❌ Authentication failed")
            raise HTTPException(
                status_code=status.HTTP_401_UNAUTHORIZED,
                detail="Incorrect username or password",
                headers={"WWW-Authenticate": "Bearer"},
            )


        # Determine role
        if isinstance(user, Admin):
            role = UserRole.SUPER_ADMIN.value if user.is_super_admin else UserRole.ADMIN.value
        else:
            role = UserRole.USER.value

        # Create token
        access_token_expires = timedelta(minutes=ACCESS_TOKEN_EXPIRE_MINUTES)
        access_token = create_access_token(
            data={"sub": str(user.id), "role": role}, 
            expires_delta=access_token_expires
        )

        return {"access_token": access_token, "token_type": "bearer", "role": role}

    except Exception as e:
        print("❌ Error during login:", str(e))
        raise HTTPException(
            status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
            detail="Internal server error",
            headers={"WWW-Authenticate": "Bearer"},
        )
    
@app.post("/users/register", response_model=UserResponse)
async def register_user(user: UserCreate, db: Session = Depends(get_db)):
    # Check if the username or email already exists
    existing_user = db.query(User).filter(User.username == user.username).first()
    if existing_user:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail="Username already registered",
        )

    existing_email = db.query(User).filter(User.email == user.email).first()
    if existing_email:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail="Email already registered",
        )

    # Hash the user's password
    hashed_password = get_password_hash(user.password)

    # Create the new user
    new_user = User(
        username=user.username,
        email=user.email,
        phone_number=user.phone_number,
        hashed_password=hashed_password,
        is_active=True,  # Set default active status
        created_at=datetime.utcnow(),  # Set the created time
    )

    # Add the user to the database
    db.add(new_user)
    db.commit()
    db.refresh(new_user)

    return new_user

@app.get("/users/me", response_model=UserWithRoleResponse)
async def get_current_user_info(
    current_user: User | Admin = Depends(get_current_user),
    db: Session = Depends(get_db)
):
    # Determine role
    if isinstance(current_user, Admin):
        role = UserRole.SUPER_ADMIN if current_user.is_super_admin else UserRole.ADMIN
    else:
        role = UserRole.USER

    # Create a dictionary with only the fields needed for UserWithRoleResponse
    user_data = {
        "id": current_user.id,
        "username": current_user.username,
        "email": current_user.email,
        "phone_number": current_user.phone_number,
        "is_active": current_user.is_active,
        "created_at": current_user.created_at,
        "role": role  # Add the role field
    }

    # Return the Pydantic model
    return UserWithRoleResponse(**user_data)