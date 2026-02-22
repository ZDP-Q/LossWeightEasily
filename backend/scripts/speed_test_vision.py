import asyncio
import base64
import io
import time
import sys
import os
import yaml
from pathlib import Path
from PIL import Image
from openai import AsyncOpenAI

# 设置环境
backend_dir = Path(__file__).parent.parent
os.chdir(str(backend_dir))
sys.path.append(str(backend_dir))

def load_real_config():
    with open("config.yaml", "r", encoding="utf-8") as f:
        cfg = yaml.safe_load(f)
        return cfg.get("llm", {})

async def get_test_image():
    # 优先使用项目自带的测试图
    local_path = Path("data/test_salad.jpg")
    if local_path.exists():
        return local_path.read_bytes()
    return None

def resize_image(image_bytes, size):
    img = Image.open(io.BytesIO(image_bytes))
    if img.mode != 'RGB':
        img = img.convert('RGB')
    
    # 使用 thumbnail 保持比例
    img.thumbnail((size, size), Image.Resampling.LANCZOS)
    output = io.BytesIO()
    # 质量设为 80 以平衡大小和清晰度
    img.save(output, format="JPEG", quality=80)
    return output.getvalue()

async def call_vision_api(client, model, image_bytes, label):
    base64_image = base64.b64encode(image_bytes).decode("utf-8")
    start_time = time.time()
    try:
        response = await client.chat.completions.create(
            model=model,
            messages=[
                {
                    "role": "user",
                    "content": [
                        {"type": "text", "text": "识别这张图片里的食物名称和热量，直接返回 JSON 格式"},
                        {"type": "image_url", "image_url": {"url": f"data:image/jpeg;base64,{base64_image}"}}
                    ],
                }
            ],
            max_tokens=200,
            temperature=0.1
        )
        duration = time.time() - start_time
        print(f"[{label}] 成功! 耗时: {duration:.2f}s | 图片大小: {len(image_bytes)/1024:.1f}KB")
        return duration
    except Exception as e:
        print(f"[{label}] 错误: {str(e)[:100]}")
        return 999

async def main():
    llm_cfg = load_real_config()
    api_key = llm_cfg.get("api_key")
    base_url = llm_cfg.get("base_url")
    model = "qwen3.5-plus" # 强制使用用户指定的原生多模态模型
    
    client = AsyncOpenAI(api_key=api_key, base_url=base_url)
    
    print(f"--- Vision Performance Test: {model} ---")
    raw_image = await get_test_image()
    if not raw_image:
        print("错误: 找不到测试图片 data/test_salad.jpg")
        return

    resolutions = [256, 512, 1024, 2048]
    results = {}

    print("\n1. [分辨率对照测试] 串行执行...")
    for res in resolutions:
        img = resize_image(raw_image, res)
        duration = await call_vision_api(client, model, img, f"Res-{res}px")
        results[res] = duration

    print("\n2. [策略对比测试] 3路并发 (1024px)...")
    c_img = resize_image(raw_image, 1024)
    start_c = time.time()
    # 模拟项目目前的并发逻辑
    await asyncio.gather(*[call_vision_api(client, model, c_img, f"Parallel-{i+1}") for i in range(3)])
    total_c = time.time() - start_c

    print("\n" + "="*40)
    print(f"测试模型: {model}")
    print("-" * 40)
    for res, d in results.items():
        print(f"分辨率 {res:4}px 耗时: {d:.2f}s")
    
    print("-" * 40)
    print(f"3路并发总耗时 (1024px): {total_c:.2f}s")
    print(f"单次请求耗时 (1024px): {results[1024]:.2f}s")
    
    if total_c > results[1024] * 1.5:
        print("\n[发现瓶颈] 并发调用显著增加了延迟。")
        print("原因分析: API 提供商可能对并发多模态请求有速率限制或排队机制。建议将 3路并发改为 1路请求。")
    elif results[2048] > results[512] * 2:
        print("\n[发现瓶颈] 高分辨率图片极大增加了延迟。")
        print("原因分析: 可能是上传带宽限制，或者是模型编码超大图像非常耗时。建议强制压缩至 1024px 以下。")
    else:
        print("\n[结论] 延迟主要源于 API 固有响应时间。")

if __name__ == "__main__":
    asyncio.run(main())
