import psycopg2
from src.core.config import get_settings

def migrate():
    settings = get_settings()
    # 解析数据库连接信息
    db_url = settings.database.url
    print(f"正在连接数据库进行迁移: {db_url}")
    
    try:
        conn = psycopg2.connect(db_url)
        cur = conn.cursor()
        
        # 增加 meal_type 列
        print("正在为 food_logs 表增加 meal_type 列...")
        cur.execute("ALTER TABLE food_logs ADD COLUMN IF NOT EXISTS meal_type VARCHAR DEFAULT 'unknown';")
        
        conn.commit()
        print("迁移成功！")
        cur.close()
        conn.close()
    except Exception as e:
        print(f"迁移失败: {e}")

if __name__ == "__main__":
    migrate()
