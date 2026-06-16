#!/usr/bin/env python3
"""
Scheduled data generation script (invoked by cron every 2 minutes).
Generates a 500k-row CSV for the next day after the latest existing file.
If no file exists, starts from today.
"""
import os
import re
import random
import pandas as pd
from datetime import datetime, timedelta
from core.color_print import print_single_line_progress, finish_progress_line, print_green

TOTAL_ROWS = 500000
DATA_DIR = "./demo_data"
FILE_PATTERN = re.compile(r"^large_input_(\d{8})\.csv$")

def get_latest_date():
    """Return the latest date string YYYYMMDD from existing files, or None."""
    if not os.path.isdir(DATA_DIR):
        return None
    dates = []
    for fname in os.listdir(DATA_DIR):
        m = FILE_PATTERN.match(fname)
        if m:
            dates.append(m.group(1))
    if not dates:
        return None
    dates.sort()
    return dates[-1]

def get_next_date():
    """Return the next date string to generate."""
    latest = get_latest_date()
    if latest is None:
        return datetime.now().strftime("%Y%m%d")
    latest_date = datetime.strptime(latest, "%Y%m%d")
    next_date = latest_date + timedelta(days=1)
    return next_date.strftime("%Y%m%d")

def generate_file(date_str: str):
    """Generate 500k rows of dirty data and save to CSV."""
    file_path = os.path.join(DATA_DIR, f"large_input_{date_str}.csv")
    print_green(f"Generating {TOTAL_ROWS:,} rows for virtual date {date_str}...")

    rows = []
    for idx in range(1, TOTAL_ROWS + 1):
        r = random.random()
        if r < 0.02:
            row = {"id": None, "amount": None, "category": None}
        elif r < 0.05:
            row = {"id": idx, "amount": round(random.uniform(0.01, 99999.99), 2), "category": None}
        elif r < 0.08:
            row = {"id": idx, "amount": round(random.uniform(-1000, -0.01), 2),
                   "category": random.choice(["A", "B", "C", "D", "E"])}
        elif r < 0.10:
            row = rows[-1].copy() if rows else {"id": idx, "amount": 100.0, "category": "A"}
        else:
            row = {"id": idx, "amount": round(random.uniform(0.01, 99999.99), 2),
                   "category": random.choice(["A", "B", "C", "D", "E"])}
        rows.append(row)
        print_single_line_progress(idx, TOTAL_ROWS)

    finish_progress_line()
    os.makedirs(DATA_DIR, exist_ok=True)
    df = pd.DataFrame(rows)
    df.to_csv(file_path, index=False, encoding="utf-8-sig")
    size_mb = os.path.getsize(file_path) / (1024 * 1024)
    print_green(f"Generation complete! File: {file_path}")
    print(f"Rows: {len(df):,} | Size: {size_mb:.2f} MB")

if __name__ == "__main__":
    next_date = get_next_date()
    file_path = os.path.join(DATA_DIR, f"large_input_{next_date}.csv")
    if os.path.exists(file_path):
        print_green(f"File for {next_date} already exists, nothing to do.")
    else:
        generate_file(next_date)