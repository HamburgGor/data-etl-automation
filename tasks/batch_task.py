"""ETL批处理业务逻辑"""
import os
import sys
import logging
import pandas as pd
from core.color_print import (
    print_single_line_progress,
    finish_progress_line,
    print_green,
    print_red,
    print_yellow,
    RESET, BOLD, RED, GREEN, ORANGE
)
from core.data_cleaner import DataCleaner
from core.stable_retry import stable_retry_wrapper


@stable_retry_wrapper(max_retry=3, sleep_sec=2)
def run_batch_etl(input_path: str, output_path: str):
    """
    批量ETL主逻辑：分块读取CSV、清洗、写入CSV
    :param input_path: 输入CSV文件路径
    :param output_path: 输出CSV文件路径（注意：现在输出CSV，可根据需要改回Excel）
    """
    # 自动创建日志目录
    os.makedirs("logs", exist_ok=True)

    # 初始化日志记录器
    logging.basicConfig(
        level=logging.INFO,
        format="%(asctime)s - %(levelname)s - %(message)s",
        filename="./logs/etl_run.log",
        encoding="utf-8"
    )
    logger = logging.getLogger(__name__)

    # ========== 任务头部 ==========
    print("=" * 60)
    print(f"ETL TASK STARTED | Input File: {GREEN}{BOLD}{input_path}{RESET}")
    print("=" * 60)
    logger.info(f"ETL task started, source file: {input_path}")

    # 验证输入文件
    if not os.path.exists(input_path):
        error_msg = f"Source file missing: {input_path}"
        print(f"{RED}{BOLD}[STOP-LOSS CRITICAL]{RESET} {error_msg}")
        logger.error(error_msg)
        raise FileNotFoundError(error_msg)

    # 确保输出目录存在
    output_dir = os.path.dirname(output_path)
    if output_dir:
        os.makedirs(output_dir, exist_ok=True)

    # ========== 读取数据 ==========
    print("Reading raw CSV data...")
    # 先统计总行数（用于进度条）
    with open(input_path, 'r', encoding='utf-8-sig') as f:
        next(f)  # 跳过表头
        total_rows = sum(1 for _ in f)

    logger.info(f"Total rows in source file: {total_rows}")

    # 分块读取与清洗
    chunk_size = 10000
    processed_rows = 0
    cleaned_chunks = []

    try:
        chunk_iterator = pd.read_csv(
            input_path,
            chunksize=chunk_size,
            encoding='utf-8-sig',
            on_bad_lines='skip',
            low_memory=False
        )

        # 获取文本列（用于清洗）
        text_columns = []  # 会在第一次迭代中确定

        for chunk_df in chunk_iterator:
            if not text_columns:
                # 第一次读取时确定文本列
                text_columns = chunk_df.select_dtypes(include=["string", "object"]).columns.tolist()

            # 清洗当前块
            clean_chunk = DataCleaner.batch_clean_dataframe(chunk_df, text_columns)
            if not clean_chunk.empty:
                cleaned_chunks.append(clean_chunk)

            processed_rows += len(chunk_df)
            print_single_line_progress(processed_rows, total_rows)

        finish_progress_line()
        print("")
        print(f"Raw data loaded successfully | Total rows: {ORANGE}{BOLD}{total_rows}{RESET}")
        logger.info(f"Raw data loaded successfully, total original rows: {total_rows}")

        # 合并所有清洗后的块
        if cleaned_chunks:
            df_cleaned = pd.concat(cleaned_chunks, ignore_index=True)
        else:
            df_cleaned = pd.DataFrame()

        clean_rows_count = len(df_cleaned)
        print(f"Data cleaning completed | Valid cleaned rows: {GREEN}{BOLD}{clean_rows_count}{RESET}")
        logger.info(f"Data cleaning finished, valid rows after clean: {clean_rows_count}")

        # 导出结果（这里输出为 CSV，保持与新版本一致；如需 Excel 可自行修改）
        df_cleaned.to_csv(output_path, index=False, encoding="utf-8-sig")

        # ========== 任务结束头部 ==========
        print("\n" + "=" * 60)
        print(f"{GREEN}{BOLD}ETL TASK COMPLETED SUCCESSFULLY{RESET}")
        print(f"Output saved to: {GREEN}{BOLD}{output_path}{RESET}")
        print("=" * 60)
        logger.info(f"Full ETL task finished, target file: {output_path}")

    except Exception as e:
        error_msg = f"ETL process failed: {str(e)}"
        print(f"{RED}{BOLD}[STOP-LOSS CRITICAL]{RESET} {error_msg}")
        logger.error(error_msg)
        raise