import json
import logging
from typing import List

from fastapi import APIRouter, Depends, HTTPException, Request
from fastapi.responses import StreamingResponse
from pydantic import BaseModel
from sqlmodel import Session

from ..core.database import get_session
from ..core.security import get_current_user
from ..models import ChatMessage, User
from ..repositories.weight_repository import WeightRepository
from ..repositories.chat_repository import ChatRepository
from ..services.weight_service import WeightService

logger = logging.getLogger("loseweight.api.chat")

router = APIRouter(prefix="/chat", tags=["chat"])


def _encode_sse(event_type: str, data: str | None = "") -> str:
    """将事件编码为符合 SSE 规范的文本。"""
    normalized = (data or "").replace("\r\n", "\n").replace("\r", "\n")
    lines = normalized.split("\n")
    payload = [f"event: {event_type}"]
    payload.extend(f"data: {line}" for line in lines)
    payload.append("")
    return "\n".join(payload) + "\n"


class ChatRequest(BaseModel):
    message: str


class ChatResponse(BaseModel):
    reply: str


def get_weight_service(session: Session = Depends(get_session)) -> WeightService:
    return WeightService(WeightRepository(session))


def get_chat_repo(session: Session = Depends(get_session)) -> ChatRepository:
    return ChatRepository(session)


def _build_user_info(user, weight_service: WeightService) -> str:
    """构建用户信息上下文字符串。"""
    try:
        if user:
            # 获取最新体重记录
            latest_records = weight_service.get_records(user.id, limit=1)
            current_weight = (
                latest_records[0].weight_kg
                if latest_records
                else user.initial_weight_kg
            )

            # 检查关键信息是否缺失
            missing_info = []
            if not user.height_cm:
                missing_info.append("身高")
            if not current_weight:
                missing_info.append("体重")
            if not user.age:
                missing_info.append("年龄")
            if not user.gender:
                missing_info.append("性别")
            if not user.activity_level:
                missing_info.append("活动水平")

            if missing_info:
                return f"提示：当前用户资料不完整（缺失：{', '.join(missing_info)}）。请引导用户补充这些信息，以便计算 TDEE 并制定个性化减重计划。"

            return (
                f"用户信息：姓名 {user.nickname or user.username}, 性别 {user.gender}, 当前体重 {current_weight}kg, "
                f"身高 {user.height_cm}cm, 年龄 {user.age}, "
                f"活动水平 {user.activity_level}, "
                f"TDEE {user.tdee or 0:.0f}kcal, "
                f"目标体重 {user.target_weight_kg}kg。"
            )
    except Exception as e:
        logger.error(f"构建用户信息上下文失败: {e}", exc_info=True)
    return "提示：无法获取用户详细资料。请礼貌地询问用户的身体基本信息（身高、体重、年龄、活动量等）。"


@router.get("/history", response_model=List[ChatMessage])
async def get_chat_history(
    limit: int = 50,
    current_user: User = Depends(get_current_user),
    chat_repo: ChatRepository = Depends(get_chat_repo),
):
    """获取当前用户的聊天历史记录。"""
    user = current_user
    if not user:
        raise HTTPException(status_code=404, detail="用户不存在")

    safe_limit = max(1, min(limit, 100))
    return chat_repo.get_history(user.id, limit=safe_limit)


@router.post("", response_model=ChatResponse)
async def chat_with_coach(
    request_data: ChatRequest,
    request: Request,
    current_user: User = Depends(get_current_user),
    weight_service: WeightService = Depends(get_weight_service),
    chat_repo: ChatRepository = Depends(get_chat_repo),
):
    """非流式聊天端点（支持历史记录和持久化）。"""
    agent = request.app.state.agent
    if not agent:
        raise HTTPException(status_code=503, detail="AI Agent 未初始化")

    user = current_user
    if not user:
        raise HTTPException(status_code=404, detail="用户不存在")

    user_info = _build_user_info(user, weight_service)

    # 获取历史记录并转换为 OpenAI 格式
    history_objs = chat_repo.get_history(user.id, limit=None)
    history = [{"role": h.role, "content": h.content} for h in history_objs]

    try:
        reply = await agent.get_guidance_direct(
            question=request_data.message,
            user_info=user_info,
            history=history,
            user_id=user.id,
        )

        # 单事务写入，降低提交开销
        chat_repo.add_messages(
            user.id,
            [("user", request_data.message), ("assistant", reply)],
        )

        return ChatResponse(reply=reply)
    except Exception as e:
        logger.error(f"非流式对话出错: {e}")
        raise HTTPException(status_code=500, detail=str(e))


@router.post("/stream")
async def chat_stream(
    request_data: ChatRequest,
    request: Request,
    current_user: User = Depends(get_current_user),
    weight_service: WeightService = Depends(get_weight_service),
    chat_repo: ChatRepository = Depends(get_chat_repo),
):
    """SSE 流式聊天端点（带记忆持久化）。"""
    agent = request.app.state.agent
    if not agent:
        raise HTTPException(status_code=503, detail="AI Agent 未初始化")

    user = current_user
    if not user:
        raise HTTPException(status_code=404, detail="用户不存在")

    user_info = _build_user_info(user, weight_service)

    # 获取历史记录
    history_objs = chat_repo.get_history(user.id, limit=None)
    history = [{"role": h.role, "content": h.content} for h in history_objs]

    async def event_generator():
        full_reply = ""
        done_sent = False
        try:
            async for event in agent.chat_stream(
                message=request_data.message,
                user_info=user_info,
                history=history,
                user_id=user.id,
            ):
                event_type = event.get("event", "text")
                data = event.get("data", "")

                if event_type == "text":
                    full_reply += str(data)
                elif event_type == "action_result":
                    data = json.dumps(data, ensure_ascii=False)
                elif event_type == "usage":
                    data = json.dumps(data, ensure_ascii=False)
                elif event_type == "done":
                    data = ""
                    done_sent = True

                yield _encode_sse(event_type, str(data))

            # 对话结束后保存记录
            payload: list[tuple[str, str]] = [("user", request_data.message)]
            if full_reply:
                payload.append(("assistant", full_reply))
            chat_repo.add_messages(user.id, payload)

        except Exception as e:
            logger.error(f"流式响应生成出错: {e}")
            yield _encode_sse("error", str(e))
        finally:
            if not done_sent:
                yield _encode_sse("done", "")

    return StreamingResponse(
        event_generator(),
        media_type="text/event-stream",
        headers={
            "Cache-Control": "no-cache, no-transform",
            "Connection": "keep-alive",
            "X-Accel-Buffering": "no",
            "Content-Type": "text/event-stream",
        },
    )
