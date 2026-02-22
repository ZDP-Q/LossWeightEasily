from datetime import datetime, time, timezone, timedelta
from typing import List

from fastapi import APIRouter, Depends, HTTPException
from sqlmodel import Session, select, and_

from ..core.database import get_session
from ..models import FoodLog, User
from ..schemas.food_log import FoodLogCreate, FoodLogRead

router = APIRouter(prefix="/food-logs", tags=["food-logs"])


def get_current_user_id(session: Session = Depends(get_session)) -> int:
    """Mock helper to get the first user's ID for simplicity in this project."""
    user = session.exec(select(User)).first()
    if not user:
        raise HTTPException(status_code=404, detail="User not found")
    return user.id


@router.post("", response_model=FoodLogRead)
def create_food_log(
    data: FoodLogCreate,
    user_id: int = Depends(get_current_user_id),
    session: Session = Depends(get_session),
):
    """记录一次食物摄入。"""
    log = FoodLog(
        user_id=user_id,
        food_name=data.food_name,
        calories=data.calories,
        meal_type=data.meal_type or "unknown",
        timestamp=data.timestamp or datetime.now(timezone.utc),
    )
    session.add(log)
    session.commit()
    session.refresh(log)
    return log


@router.get("/today", response_model=List[FoodLogRead])
def get_today_logs(
    user_id: int = Depends(get_current_user_id),
    session: Session = Depends(get_session),
):
    """获取今日的所有食物摄入记录。"""
    now = datetime.now(timezone.utc)
    # 简单的本地时间起始计算
    start_of_day = datetime.combine(now.date(), time.min, tzinfo=timezone.utc)
    end_of_day = start_of_day + timedelta(days=1)

    statement = (
        select(FoodLog)
        .where(
            and_(
                FoodLog.user_id == user_id,
                FoodLog.timestamp >= start_of_day,
                FoodLog.timestamp < end_of_day,
            )
        )
        .order_by(FoodLog.timestamp.asc())
    )

    return session.exec(statement).all()
