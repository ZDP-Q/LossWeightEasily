from pydantic import BaseModel, Field, EmailStr
from datetime import datetime
from typing import Optional


class UserCreate(BaseModel):
    # 限制账号仅支持数字、字母、下划线
    username: str = Field(
        min_length=3, 
        max_length=50, 
        pattern=r"^[a-zA-Z0-9_]+$",
        description="账号仅支持数字、字母和下划线"
    )
    password: str = Field(min_length=6)
    email: Optional[EmailStr] = None


class UserLogin(BaseModel):
    username: str
    password: str


class Token(BaseModel):
    access_token: str
    token_type: str


class UserRead(BaseModel):
    id: int
    username: str
    nickname: Optional[str] = None
    email: Optional[str] = None
    age: Optional[int] = None
    gender: Optional[str] = None
    height_cm: Optional[float] = None
    initial_weight_kg: Optional[float] = None
    target_weight_kg: Optional[float] = None
    activity_level: Optional[str] = "sedentary"
    bmr: Optional[float] = None
    tdee: Optional[float] = None
    daily_calorie_goal: Optional[float] = None
    created_at: datetime

    class Config:
        from_attributes = True


class UserProfileUpdate(BaseModel):
    # 昵称修改（可选）
    nickname: Optional[str] = Field(default=None, max_length=50)
    age: Optional[int] = Field(default=None, ge=1, le=150)
    gender: Optional[str] = Field(default=None, pattern=r"^(male|female|other)$")
    height_cm: Optional[float] = Field(default=None, ge=50, le=300)
    initial_weight_kg: Optional[float] = Field(default=None, ge=10, le=500)
    target_weight_kg: Optional[float] = Field(default=None, ge=10, le=500)
    activity_level: Optional[str] = Field(default="sedentary")
