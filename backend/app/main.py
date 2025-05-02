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

from fastapi import FastAPI
from fastapi.middleware.cors import CORSMiddleware
from app.api import stations, bookings, payments, routes, admin
from app.api.auth import router as auth_router
from app.core.config import settings
from app.database import base
from app.database.session import engine

from fastapi.openapi.utils import get_openapi

from datetime import timedelta
from fastapi import Depends, HTTPException, status
from fastapi.security import OAuth2PasswordRequestForm
from sqlalchemy.orm import Session
from app.auth.dependencies import (
    ACCESS_TOKEN_EXPIRE_MINUTES,
    UserRole,
    create_access_token,
    verify_password,
    get_password_hash,
)
from app.models.admin import Admin
from app.models.user import User
from app.schemas.auth import Token
from app.schemas.user import UserResponse, UserCreate
from fastapi import APIRouter
from fastapi import Depends

# Create database tables
base.Base.metadata.create_all(bind=engine)

app = FastAPI(title=settings.PROJECT_NAME, debug=True)

# CORS middleware
app.add_middleware(
    CORSMiddleware,
    allow_origins=[""],
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)

# Include API routers
app.include_router(auth_router, prefix="/auth", tags=["auth"])
app.include_router(stations.router, prefix="/stations", tags=["stations"])
app.include_router(bookings.router, prefix="/bookings", tags=["bookings"])
app.include_router(payments.router, prefix="/payments", tags=["payments"])
app.include_router(routes.router, prefix="/routes", tags=["routes"])
app.include_router(admin.router, prefix="/admin", tags=["admin"])

# Custom OpenAPI for Swagger UI with security scheme
def custom_openapi():
    if app.openapi_schema:
        return app.openapi_schema

    openapi_schema = get_openapi(
        title=settings.PROJECT_NAME,
        version="1.0.0",
        description="Bus Ticket Booking System API",
        routes=app.routes,
    )

    components = openapi_schema.get("components", {})
    security_schemes = components.get("securitySchemes", {})

    security_schemes["bearerAuth"] = {
        "type": "http",
        "scheme": "bearer",
        "bearerFormat": "JWT",
    }

    components["securitySchemes"] = security_schemes
    openapi_schema["components"] = components

    for path in openapi_schema["paths"].values():
        for operation in path.values():
            operation.setdefault("security", [{"bearerAuth": []}])

    app.openapi_schema = openapi_schema
    return app.openapi_schema


app.openapi = custom_openapi

@app.get("/")
def health_check():
    return {"status": "healthy"}
