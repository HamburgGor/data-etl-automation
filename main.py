#!/usr/bin/env python3
"""ETL Automation Tool - Entry Point"""
import argparse
import sys
import os
import re
import glob
from tasks import run_batch_etl

def main():
    parser = argparse.ArgumentParser(description="ETL Automation Tool")
    parser.add_argument("--input", "-i", default=None,
                        help="Input CSV file path (default: all date-stamped files in demo_data)")
    parser.add_argument("--output", "-o", default=None,
                        help="Output Excel file path (ignored in batch mode)")
    args = parser.parse_args()

    # ----- Batch mode: process all date-stamped files -----
    if args.input is None:
        data_dir = "./demo_data"
        pattern = re.compile(r"large_input_(\d{8})\.csv$")
        files = glob.glob(os.path.join(data_dir, "large_input_*.csv"))
        date_files = []
        for f in files:
            basename = os.path.basename(f)
            m = pattern.match(basename)
            if m:
                date_str = m.group(1)
                date_files.append((date_str, f))

        if not date_files:
            print("No date-stamped files found in demo_data/. Please run gen_test_data.py first.")
            sys.exit(1)

        # Process files sorted by date
        date_files.sort(key=lambda x: x[0])
        for date_str, input_path in date_files:
            output_path = f"./output/result_{date_str}.xlsx"
            if os.path.exists(output_path):
                print(f"[SKIP] Output already exists: {output_path}")
                continue
            run_batch_etl(input_path, output_path)
    else:
        # ----- Manual mode: single file -----
        input_path = args.input
        if args.output is None:
            # Auto-generate output name from input if date pattern matches
            basename = os.path.basename(input_path)
            m = re.match(r"large_input_(\d{8})\.csv$", basename)
            if m:
                output_path = f"./output/result_{m.group(1)}.xlsx"
            else:
                output_path = "./output/result.xlsx"
        else:
            output_path = args.output

        if not os.path.exists(input_path):
            print(f"Error: Input file not found: {input_path}")
            sys.exit(1)

        if os.path.exists(output_path):
            print(f"[SKIP] Output already exists: {output_path}")
        else:
            run_batch_etl(input_path, output_path)

if __name__ == "__main__":
    main()