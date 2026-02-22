from datetime import datetime, timezone
from typing import Optional, List
from sqlmodel import SQLModel, Field, Relationship
from sqlalchemy.orm import relationship

# ============================================================================
# Database Models
# ============================================================================


class FoodBase(SQLModel):
    fdc_id: int = Field(primary_key=True)
    food_class: Optional[str] = None
    description: str
    data_type: Optional[str] = None
    ndb_number: Optional[int] = None
    publication_date: Optional[str] = None
    food_category: Optional[str] = None
    scientific_name: Optional[str] = None


class Food(FoodBase, table=True):
    __tablename__ = "foods"
    nutrients: List["FoodNutrient"] = Relationship(
        back_populates="food",
        sa_relationship=relationship("FoodNutrient", back_populates="food"),
    )
    portions: List["FoodPortion"] = Relationship(
        back_populates="food",
        sa_relationship=relationship("FoodPortion", back_populates="food"),
    )


class NutrientBase(SQLModel):
    nutrient_id: int = Field(primary_key=True)
    nutrient_number: Optional[str] = None
    nutrient_name: Optional[str] = None
    unit_name: Optional[str] = None
    rank: Optional[int] = None


class Nutrient(NutrientBase, table=True):
    __tablename__ = "nutrients"
    food_links: List["FoodNutrient"] = Relationship(
        back_populates="nutrient",
        sa_relationship=relationship("FoodNutrient", back_populates="nutrient"),
    )


class FoodNutrientBase(SQLModel):
    fdc_id: int = Field(foreign_key="foods.fdc_id")
    nutrient_id: int = Field(foreign_key="nutrients.nutrient_id")
    amount: Optional[float] = None
    data_points: Optional[int] = None
    min_value: Optional[float] = None
    max_value: Optional[float] = None
    median_value: Optional[float] = None


class FoodNutrient(FoodNutrientBase, table=True):
    __tablename__ = "food_nutrients"
    id: Optional[int] = Field(default=None, primary_key=True)
    food: Food = Relationship(back_populates="nutrients")
    nutrient: Nutrient = Relationship(back_populates="food_links")


class FoodPortionBase(SQLModel):
    id: int = Field(primary_key=True)
    fdc_id: int = Field(foreign_key="foods.fdc_id")
    amount: Optional[float] = None
    measure_unit_name: Optional[str] = None
    measure_unit_abbreviation: Optional[str] = None
    gram_weight: Optional[float] = None
    modifier: Optional[str] = None
    sequence_number: Optional[int] = None


class FoodPortion(FoodPortionBase, table=True):
    __tablename__ = "food_portions"
    food: Food = Relationship(back_populates="portions")


class WeightRecordBase(SQLModel):
    weight_kg: float
    recorded_at: datetime = Field(default_factory=lambda: datetime.now(timezone.utc))
    notes: Optional[str] = ""


class WeightRecord(WeightRecordBase, table=True):
    __tablename__ = "weight_records"
    id: Optional[int] = Field(default=None, primary_key=True)
    user_id: Optional[int] = Field(default=None, foreign_key="users.id")
    user: Optional["User"] = Relationship(back_populates="weight_records")


class UserBase(SQLModel):
    username: str = Field(index=True, unique=True)
    nickname: Optional[str] = Field(default=None)
    email: Optional[str] = Field(default=None, index=True)
    full_name: Optional[str] = None
    age: Optional[int] = None
    gender: Optional[str] = None  # "Male", "Female", "Other"
    height_cm: Optional[float] = None
    initial_weight_kg: Optional[float] = None
    target_weight_kg: Optional[float] = None
    activity_level: Optional[str] = Field(default="sedentary")
    bmr: Optional[float] = None
    tdee: Optional[float] = None
    daily_calorie_goal: Optional[float] = None
    created_at: datetime = Field(default_factory=lambda: datetime.now(timezone.utc))
    is_active: bool = Field(default=True)


class User(UserBase, table=True):
    __tablename__ = "users"
    id: Optional[int] = Field(default=None, primary_key=True)
    hashed_password: str

    weight_records: List[WeightRecord] = Relationship(
        back_populates="user", sa_relationship_kwargs={"cascade": "all, delete-orphan"}
    )

    ingredients: List["Ingredient"] = Relationship(
        back_populates="user", sa_relationship_kwargs={"cascade": "all, delete-orphan"}
    )
    food_recognitions: List["FoodRecognition"] = Relationship(
        back_populates="user", sa_relationship_kwargs={"cascade": "all, delete-orphan"}
    )
    food_logs: List["FoodLog"] = Relationship(
        back_populates="user", sa_relationship_kwargs={"cascade": "all, delete-orphan"}
    )
    chat_messages: List["ChatMessage"] = Relationship(
        back_populates="user", sa_relationship_kwargs={"cascade": "all, delete-orphan"}
    )


class Ingredient(SQLModel, table=True):
    __tablename__ = "ingredients"
    id: Optional[int] = Field(default=None, primary_key=True)
    name: str
    user_id: Optional[int] = Field(default=None, foreign_key="users.id")
    user: Optional[User] = Relationship(back_populates="ingredients")


class FoodRecognition(SQLModel, table=True):
    __tablename__ = "food_recognitions"
    id: Optional[int] = Field(default=None, primary_key=True)
    user_id: Optional[int] = Field(default=None, foreign_key="users.id")
    image_path: str
    food_name: str
    calories: float
    verification_status: Optional[str] = None
    reason: Optional[str] = None
    timestamp: datetime = Field(default_factory=lambda: datetime.now(timezone.utc))
    user: Optional[User] = Relationship(back_populates="food_recognitions")


class FoodLog(SQLModel, table=True):
    __tablename__ = "food_logs"
    id: Optional[int] = Field(default=None, primary_key=True)
    user_id: Optional[int] = Field(default=None, foreign_key="users.id")
    food_name: str
    calories: float
    meal_type: Optional[str] = Field(default="unknown") # breakfast, lunch, dinner, snack
    timestamp: datetime = Field(default_factory=lambda: datetime.now(timezone.utc))
    user: Optional[User] = Relationship(back_populates="food_logs")


class ChatMessage(SQLModel, table=True):
    __tablename__ = "chat_messages"
    id: Optional[int] = Field(default=None, primary_key=True)
    user_id: Optional[int] = Field(default=None, foreign_key="users.id")
    role: str  # "user" or "assistant"
    content: str
    timestamp: datetime = Field(default_factory=lambda: datetime.now(timezone.utc))

    user: Optional[User] = Relationship(back_populates="chat_messages")


# Update User model to include chat_messages relationship
# (Since I cannot easily re-read the User class and replace it perfectly without risks,
# I will use a separate replacement for User class if needed,
# but SQLModel/SQLAlchemy will pick up the relationship if I add it to User)
