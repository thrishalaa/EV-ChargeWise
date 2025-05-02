from pydantic import BaseModel, EmailStr
from datetime import datetime

class UserBase(BaseModel):
    username: str
    email: EmailStr
    phone_number: str


class UserCreate(UserBase):
    password: str  

class UserResponse(UserBase):
    id: int
    is_active: bool
    created_at: datetime

    class Config:
        from_attributes = True
        
class UserWithRoleResponse(BaseModel):
    id: int
    username: str
    email: EmailStr
    phone_number: str
    is_active: bool
    created_at: datetime
    role: str  # "user", "admin", or "super_admin"

    class Config:
        from_attributes = True