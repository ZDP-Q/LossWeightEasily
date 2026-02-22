from datetime import datetime
from typing import Optional
from pydantic import BaseModel


class FoodLogBase(BaseModel):
    food_name: str
    calories: float
    meal_type: Optional[str] = "unknown"
    timestamp: Optional[datetime] = None


class FoodLogCreate(FoodLogBase):
    pass


class FoodLogRead(FoodLogBase):
    id: int
    user_id: int
    meal_type: str
    timestamp: datetime

    class Config:
        from_attributes = True
