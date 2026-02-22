from typing import Optional

from ..models import User
from ..repositories.user_repository import UserRepository
from ..schemas.user import UserCreate, UserProfileUpdate
from ..core.security import get_password_hash


class UserService:
    ACTIVITY_MULTIPLIERS = {
        "sedentary": 1.2,
        "light": 1.375,
        "moderate": 1.55,
        "active": 1.725,
        "very_active": 1.9,
    }

    def __init__(self, repository: UserRepository):
        self.repo = repository

    def calculate_bmr(
        self, weight: float, height: float, age: int, gender: str
    ) -> float:
        if not all([weight, height, age, gender]):
            return 0.0
            
        if gender.lower() == "male":
            return 10 * weight + 6.25 * height - 5 * age + 5
        else:
            return 10 * weight + 6.25 * height - 5 * age - 161

    def calculate_tdee(self, bmr: float, activity_level: str) -> float:
        multiplier = self.ACTIVITY_MULTIPLIERS.get(activity_level.lower(), 1.2)
        return bmr * multiplier

    def register_user(self, user_in: UserCreate) -> User:
        # 检查账号名（username）是否已存在
        existing_user = self.repo.get_user_by_username(user_in.username)
        if existing_user:
            raise ValueError("账号名已存在")

        hashed_password = get_password_hash(user_in.password)
        db_user = User(
            username=user_in.username,
            nickname=user_in.username, # 注册时昵称默认同账号名
            hashed_password=hashed_password,
            email=user_in.email,
        )
        return self.repo.create_user(db_user)

    def get_user_by_username(self, username: str) -> Optional[User]:
        return self.repo.get_user_by_username(username)

    def update_profile(self, user: User, profile: UserProfileUpdate) -> User:
        """更新用户个人身体资料并自动计算代谢指标。"""
        # 仅获取不为 None 的字段
        update_data = profile.model_dump(exclude_unset=True)

        # 合并当前数据与更新数据，用于计算
        temp_data = user.model_dump()
        temp_data.update(update_data)

        # 检查是否具备计算 BMR/TDEE 的所有必要字段
        required_fields = ["initial_weight_kg", "height_cm", "age", "gender"]
        if all(temp_data.get(f) for f in required_fields):
            # 重新计算 BMR 和 TDEE
            bmr = self.calculate_bmr(
                temp_data["initial_weight_kg"], 
                temp_data["height_cm"], 
                temp_data["age"], 
                temp_data["gender"]
            )
            tdee = self.calculate_tdee(bmr, temp_data["activity_level"] or "sedentary")

            update_data["bmr"] = bmr
            update_data["tdee"] = tdee

            # 默认设置为减重目标 (TDEE - 500)
            update_data["daily_calorie_goal"] = max(1200, tdee - 500)

        return self.repo.update_user(user, update_data)
