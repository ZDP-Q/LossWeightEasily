"""日志系统初始化。

基于 LoggingSettings 配置，支持控制台 + 文件双输出。
"""

import logging
import sys
from pathlib import Path

from .config import get_settings


def setup_logging() -> None:
    """根据配置初始化日志系统。"""
    settings = get_settings().logging

    level = getattr(logging, settings.level.upper(), logging.DEBUG)

    # 初始化 colorama 支持 Windows 彩色输出
    try:
        import colorama
        colorama.init(autoreset=True)
    except ImportError:
        pass

    # 定义日志颜色（ANSI 转义序列）
    class ColoredFormatter(logging.Formatter):
        """自定义彩色日志格式化器。"""
        
        COLORS = {
            'DEBUG': '\033[36m',     # 青色
            'INFO': '\033[32m',      # 绿色
            'WARNING': '\033[33m',   # 黄色
            'ERROR': '\033[31m',     # 红色
            'CRITICAL': '\033[1;31m', # 加粗红
        }
        RESET = '\033[0m'

        def format(self, record):
            # 获取颜色
            color = self.COLORS.get(record.levelname, '')
            reset = self.RESET
            
            # 简化记录器名称逻辑
            original_name = record.name
            if original_name.startswith("uvicorn."):
                # 对于 uvicorn.error, uvicorn.access 等，显示为 uvicorn
                short_name = "uvicorn"
            else:
                # 默认只保留最后一部分
                short_name = original_name.split('.')[-1][:15]
            
            # 格式化日期和时间
            asctime = self.formatTime(record, "%Y-%m-%d %H:%M:%S")
            
            # 构造带颜色的级别和名称
            level_str = f"{color}{record.levelname:<8}{reset}"
            name_str = f"{color}{short_name:<15}{reset}"
            
            # 组装基本消息
            res = f"[{asctime}] {level_str} | {name_str} | {record.getMessage()}"
            
            # 处理异常堆栈
            if record.exc_info:
                if not res.endswith('\n'):
                    res += '\n'
                res += self.formatException(record.exc_info)
            
            # 处理堆栈信息
            if record.stack_info:
                if not res.endswith('\n'):
                    res += '\n'
                res += self.formatStack(record.stack_info)
                
            return res

    class TruncateLongStringFilter(logging.Filter):
        """全局日志过滤器：截断长字符串并屏蔽特定的冗余日志。"""
        def filter(self, record):
            # 彻底屏蔽 multipart 库的 DEBUG 日志（解析过程太碎了）
            if (record.name == "multipart" or record.name.startswith("multipart.")) and record.levelno < logging.INFO:
                return False

            # 截断 record.args 中的超长字符串
            if record.args:
                if isinstance(record.args, dict):
                    # 如果 args 是字典，处理其 Value
                    record.args = {k: self._recursive_truncate(v) for k, v in record.args.items()}
                else:
                    # 如果 args 是元组或列表，处理每个元素
                    new_args = []
                    for arg in record.args:
                        new_args.append(self._recursive_truncate(arg))
                    record.args = tuple(new_args)
            
            # 截断 record.msg
            if isinstance(record.msg, str) and len(record.msg) > 1000:
                record.msg = record.msg[:1000] + "... [Msg Truncated]"
                
            return True

        def _recursive_truncate(self, obj, max_len=200):
            if isinstance(obj, str):
                if len(obj) > max_len:
                    return obj[:max_len] + f"... [LongString Truncated, total={len(obj)}]"
                return obj
            elif isinstance(obj, dict):
                return {k: self._recursive_truncate(v, max_len) for k, v in obj.items()}
            elif isinstance(obj, list):
                if len(obj) > 20:
                    # 对于超长列表（如 Embedding 向量），只显示前 5 个
                    truncated = [self._recursive_truncate(v, max_len) for v in obj[:5]]
                    return truncated + [f"... [LongList Truncated, total={len(obj)}]"]
                return [self._recursive_truncate(v, max_len) for v in obj]
            return obj

    # 基础格式（文件输出使用，不带颜色）
    file_formatter = logging.Formatter(
        fmt="%(asctime)s | %(levelname)-8s | %(name)s | %(message)s",
        datefmt="%Y-%m-%d %H:%M:%S",
    )

    handlers = []

    # 控制台输出处理器
    if settings.enable_console:
        console_handler = logging.StreamHandler(sys.stdout)
        console_handler.setLevel(level)
        console_handler.setFormatter(ColoredFormatter())
        console_handler.addFilter(TruncateLongStringFilter())
        handlers.append(console_handler)

    # 文件输出处理器
    if settings.enable_file:
        log_dir = Path(settings.dir)
        log_dir.mkdir(parents=True, exist_ok=True)
        file_handler = logging.FileHandler(log_dir / "app.log", encoding="utf-8")
        file_handler.setLevel(level)
        file_handler.setFormatter(file_formatter)
        file_handler.addFilter(TruncateLongStringFilter())
        handlers.append(file_handler)

    # 配置根日志器
    root_logger = logging.getLogger()
    root_logger.setLevel(level)

    # 清理现有的 handler 避免重复
    for handler in root_logger.handlers[:]:
        root_logger.removeHandler(handler)

    for handler in handlers:
        root_logger.addHandler(handler)

    # 专门处理 uvicorn 的日志器，确保它们不使用自己的默认格式
    uvicorn_loggers = ["uvicorn", "uvicorn.error", "uvicorn.access", "fastapi"]
    for logger_name in uvicorn_loggers:
        u_logger = logging.getLogger(logger_name)
        u_logger.handlers = []  # 清空 uvicorn 默认的 handlers
        u_logger.propagate = True  # 让日志流向根日志器

    # 抑制特定第三方库过细的调试信息
    for name in ["multipart", "python_multipart", "openai", "httpx", "httpcore", "asyncio", "dashscope", "PIL", "TiffImagePlugin"]:
        logging.getLogger(name).setLevel(logging.WARNING)

    logging.getLogger("loseweight").info(
        "日志系统初始化完成 (level=%s, file=%s)", settings.level, settings.enable_file
    )
