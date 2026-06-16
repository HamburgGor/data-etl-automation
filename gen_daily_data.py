#!/usr/bin/env python3
"""
由 cron 定时触发，每次运行生成未来三天的模拟数据文件
用法：python gen_daily_data.py
输出：
    demo_data/large_input_20260616.csv  (今天)
    demo_data/large_input_20260617.csv  (明天)
    demo_data/large_input_20260618.csv  (后天)
"""
import os
import random
import pandas as pd
from datetime import datetime, timedelta

ROWS_PER_FILE = 5000  # 每个文件行数，方便快速生成

def generate_file(date_str: str):
    """生成带脏数据的单个 CSV 文件"""
    rows = []
    for i in range(1, ROWS_PER_FILE + 1):
        r = random.random()
        if r < 0.02:
            row = {"id": None, "amount": None, "category": None}
        elif r < 0.05:
            row = {"id": i, "amount": round(random.uniform(0.01, 99999.99), 2), "category": None}
        elif r < 0.08:
            row = {"id": i, "amount": round(random.uniform(-1000, -0.01), 2),
                   "category": random.choice(["A","B","C","D","E"])}
        elif r < 0.10:
            row = rows[-1].copy() if rows else {"id": i, "amount": 100.0, "category": "A"}
        else:
            row = {"id": i, "amount": round(random.uniform(0.01, 99999.99), 2),
                   "category": random.choice(["A","B","C","D","E"])}
        rows.append(row)

    df = pd.DataFrame(rows)
    os.makedirs("./demo_data", exist_ok=True)
    file_path = f"./demo_data/large_input_{date_str}.csv"
    df.to_csv(file_path, index=False, encoding="utf-8-sig")

if __name__ == "__main__":
    today = datetime.today()
    for offset in range(3):
        target_date = today + timedelta(days=offset)
        date_str = target_date.strftime("%Y%m%d")
        generate_file(date_str)