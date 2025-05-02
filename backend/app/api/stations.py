from fastapi import APIRouter, Depends, HTTPException, Query, Body
from sqlalchemy.orm import Session, joinedload
from typing import List, Optional
from app.database.session import get_db
from app.models.stations import Station
from app.models.bookings import Booking
from app.schemas.stations import ChargingConfigResponse, StationCreate, StationCreateResponse, StationResponse, StationSearchRequest, BookingInfo
from app.models.admin import Admin
from app.auth.dependencies import get_current_admin, get_current_user, require_super_admin
from app.services.route_optimizer import OSRMRouteOptimizer
from app.core.config import Settings, settings
from app.models.chargingCosts import ChargingConfig
from datetime import datetime

router = APIRouter()

@router.post("/search", response_model=List[StationResponse])
def get_nearby_stations(
    search_request: StationSearchRequest = Body(...),
    db: Session = Depends(get_db),
    current_user: dict = Depends(get_current_user)
):
    """
    Find nearby charging stations using OSRM-based spatial + real-road filtering
    """
    latitude = search_request.latitude
    longitude = search_request.longitude
    radius = search_request.radius

    # Fetch all available stations
    stations = db.query(Station).options(joinedload(Station.charging_configs)).filter(Station.is_available == True).all()

    if not stations:
        raise HTTPException(status_code=404, detail="No available stations found")

    try:
        optimizer = OSRMRouteOptimizer(
            stations=stations,
            battery_range=settings.MAX_SEARCH_RADIUS,
            osrm_server=settings.OSRM_SERVER_URL
        )

        results = optimizer.find_nearby_stations(latitude, longitude, radius)

        if not results:
            return []

        response = []
        for station, distance, route_info in results:
            charging_configs = [
                ChargingConfigResponse(
                    charging_type=config.charging_type,
                    connector_type=config.connector_type,
                    power_output=config.power_output,
                    cost_per_kwh=config.cost_per_kwh
                )
                for config in station.charging_configs
            ]

            response.append(
                StationResponse(
                    id=station.id,
                    name=station.name,
                    latitude=station.latitude,
                    longitude=station.longitude,
                    is_available=station.is_available,
                    charging_configs=charging_configs,
                    distance_from_start=round(distance, 2)
                )
            )

        return response

    except Exception as e:
        raise HTTPException(status_code=500, detail=str(e))

# New endpoint to get stations along a route using route optimizer
from pydantic import BaseModel

class RouteRequest(BaseModel):
    start_latitude: float
    start_longitude: float
    end_latitude: float
    end_longitude: float

@router.post("/route", response_model=List[StationResponse])
def get_stations_along_route(
    route_request: RouteRequest = Body(...),
    db: Session = Depends(get_db),
    current_user: dict = Depends(get_current_user)
):
    """
    Find optimal route with charging stations between start and end points using route optimizer
    """
    start_coords = (route_request.start_latitude, route_request.start_longitude)
    end_coords = (route_request.end_latitude, route_request.end_longitude)

    # Fetch all available stations
    stations = db.query(Station).options(joinedload(Station.charging_configs)).filter(Station.is_available == True).all()

    if not stations:
        raise HTTPException(status_code=404, detail="No available stations found")

    try:
        optimizer = OSRMRouteOptimizer(
            stations=stations,
            battery_range=settings.MAX_SEARCH_RADIUS,
            osrm_server=settings.OSRM_SERVER_URL
        )

        route = optimizer.dijkstra_route(start_coords, end_coords)

        if not route:
            return []

        response = []
        for station, route_info in route:
            charging_configs = [
                ChargingConfigResponse(
                    charging_type=config.charging_type,
                    connector_type=config.connector_type,
                    power_output=config.power_output,
                    cost_per_kwh=config.cost_per_kwh
                )
                for config in station.charging_configs
            ]

            response.append(
                StationResponse(
                    id=station.id,
                    name=station.name,
                    latitude=station.latitude,
                    longitude=station.longitude,
                    is_available=station.is_available,
                    charging_configs=charging_configs,
                    route_geometry=route_info.get("geometry") if route_info else None
                )
            )

        return response

    except Exception as e:
        raise HTTPException(status_code=500, detail=str(e))

@router.get("/search-with-bookings", response_model=List[StationResponse])
def search_stations_with_bookings(
    name: Optional[str] = Query(None, description="Station name to search for"),
    db: Session = Depends(get_db)
):
    """
    Search stations by name and include their booking details.
    """
    query = db.query(Station).options(joinedload(Station.charging_configs))

    if name:
        query = query.filter(Station.name.ilike(f"%{name}%"))

    stations = query.all()
    
    # Get bookings for these stations
    station_ids = [station.id for station in stations]
    bookings = db.query(Booking).filter(Booking.station_id.in_(station_ids)).all()
    
    # Group bookings by station_id
    station_bookings = {}
    for booking in bookings:
        if booking.station_id not in station_bookings:
            station_bookings[booking.station_id] = []
        station_bookings[booking.station_id].append(booking)

    station_responses = []
    for station in stations:
        charging_configs = [
            ChargingConfigResponse(
                charging_type=config.charging_type,
                connector_type=config.connector_type,
                power_output=config.power_output,
                cost_per_kwh=config.cost_per_kwh
            )
            for config in station.charging_configs
        ]
        
        bookings_info = []
        if station.id in station_bookings:
            for booking in station_bookings[station.id]:
                # Calculate end_time based on start_time and duration
                end_time = booking.start_time
                if booking.duration_minutes:
                    end_time = booking.start_time.replace(
                        minute=booking.start_time.minute + booking.duration_minutes
                    )
                
                bookings_info.append(
                    BookingInfo(
                        start_time=booking.start_time,
                        end_time=end_time,
                        duration_minutes=booking.duration_minutes or 0
                    )
                )
                
        station_responses.append(
            StationResponse(
                id=station.id,
                name=station.name,
                latitude=station.latitude,
                longitude=station.longitude,
                is_available=station.is_available,
                distance_to_next=None,
                distance_from_previous=None,
                distance_from_start=None,
                distance_to_destination=None,
                charging_configs=charging_configs,
                route_geometry=None,
                bookings=bookings_info
            )
        )
    return station_responses

@router.get("/recent", response_model=List[StationResponse])
def get_recent_stations(
    db: Session = Depends(get_db),
    current_user = Depends(get_current_user)
):
    """
    Get stations that the current user has recently booked
    """
    # Get the user's bookings, ordered by most recent first
    recent_bookings = db.query(Booking).filter(
        Booking.user_id == current_user.id
    ).order_by(Booking.created_at.desc()).limit(5).all()
    
    # Extract unique station IDs
    station_ids = set()
    for booking in recent_bookings:
        station_ids.add(booking.station_id)
    
    # Query for these stations with their charging configs
    stations = db.query(Station).options(
        joinedload(Station.charging_configs)
    ).filter(Station.id.in_(station_ids)).all()
    
    # Convert to response model
    station_responses = []
    for station in stations:
        charging_configs = [
            ChargingConfigResponse(
                charging_type=config.charging_type,
                connector_type=config.connector_type,
                power_output=config.power_output,
                cost_per_kwh=config.cost_per_kwh
            )
            for config in station.charging_configs
        ]
        
        station_responses.append(
            StationResponse(
                id=station.id,
                name=station.name,
                latitude=station.latitude,
                longitude=station.longitude,
                is_available=station.is_available,
                charging_configs=charging_configs,
                distance_from_start=None,
                distance_to_next=None,
                distance_from_previous=None,
                distance_to_destination=None,
                route_geometry=None,
                bookings=[]
            )
        )
    
    return station_responses

@router.get("/nearby", response_model=List[StationResponse])
def get_stations_by_coordinates(
    lat: float = Query(..., ge=-90, le=90),
    lng: float = Query(..., ge=-180, le=180),
    max_range: float = Query(30.0),
    db: Session = Depends(get_db),
    current_user: dict = Depends(get_current_user)
):
    """
    GET alternative for finding nearby stations via query parameters.
    This supports clients like Flutter that use GET /stations/nearby?lat=...&lng=...
    """
    # Reuse the logic from the /search POST endpoint
    stations = db.query(Station).options(joinedload(Station.charging_configs)).filter(
        Station.is_available == True
    ).all()

    if not stations:
        raise HTTPException(status_code=404, detail="No available stations found")

    try:
        optimizer = OSRMRouteOptimizer(
            stations=stations,
            battery_range=settings.MAX_SEARCH_RADIUS,
            osrm_server=settings.OSRM_SERVER_URL
        )

        results = optimizer.find_nearby_stations(lat, lng, max_range)

        response = []
        for station, distance, route_info in results:
            charging_configs = [
                ChargingConfigResponse(
                    charging_type=config.charging_type,
                    connector_type=config.connector_type,
                    power_output=config.power_output,
                    cost_per_kwh=config.cost_per_kwh
                )
                for config in station.charging_configs
            ]

            response.append(
                StationResponse(
                    id=station.id,
                    name=station.name,
                    latitude=station.latitude,
                    longitude=station.longitude,
                    is_available=station.is_available,
                    charging_configs=charging_configs,
                    distance_from_start=round(distance, 2)
                )
            )

        return response
    except Exception as e:
        raise HTTPException(status_code=500, detail=str(e))


@router.post("/super-admin/create-station", response_model=StationCreateResponse)
def create_station(
    station: StationCreate, 
    current_admin: Admin = Depends(require_super_admin),
    db: Session = Depends(get_db)
):
    if not current_admin.is_super_admin:
        raise HTTPException(status_code=403, detail="Only super admins can create new stations")

    db_station = Station(
        name=station.name,
        latitude=station.latitude,
        longitude=station.longitude,
        is_available=station.is_available
    )

    try:
        db.add(db_station)
        current_admin.stations.append(db_station)
        db.commit()
        db.refresh(db_station)

        # If charging configs are included, add them
        if station.charging_configs:
            for config in station.charging_configs:
                db_config = ChargingConfig(
                    charging_type=config.charging_type,
                    connector_type=config.connector_type,
                    power_output=config.power_output,
                    cost_per_kwh=config.cost_per_kwh,
                    station_id=db_station.id
                )
                db.add(db_config)

            db.commit()

        return StationCreateResponse(
            id=db_station.id,
            name=db_station.name,
            latitude=db_station.latitude,
            longitude=db_station.longitude,
            is_available=db_station.is_available,
            message="Station created successfully"
        )
    except Exception as e:
        db.rollback()
        raise HTTPException(
            status_code=500,
            detail="Failed to create charging station"
        )
    
@router.delete("/super-admin/delete-station/{station_id}", response_model=StationCreateResponse)
def delete_station(
    station_id: int,
    current_admin: Admin = Depends(require_super_admin),
    db: Session = Depends(get_db)
):
    """Delete a charging station (super admin only)"""
    if not current_admin.is_super_admin:
        raise HTTPException(
            status_code=403,
            detail="Only super admins can delete stations"
        )
    
    # Fetch the station to be deleted
    db_station = db.query(Station).filter(Station.id == station_id).first()
    
    if db_station is None:
        raise HTTPException(
            status_code=404,
            detail="Charging station not found"
        )
    
    try:
        # Delete associated charging configs if they exist
        db.query(ChargingConfig).filter(ChargingConfig.station_id == db_station.id).delete()
        
        # Now delete the station itself
        db.delete(db_station)
        db.commit()

        # Return a success response
        return StationCreateResponse(
            id=db_station.id,
            name=db_station.name,
            latitude=db_station.latitude,
            longitude=db_station.longitude,
            is_available=db_station.is_available,
            message="Station deleted successfully"
        )
    except Exception as e:
        db.rollback()
        raise HTTPException(
            status_code=500,
            detail="Failed to delete charging station"
        )