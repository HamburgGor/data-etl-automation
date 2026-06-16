#/usr/bin/env python3
"""ETL Automation Tool - 主入口"""
import argparse
import sys
import os
from tasks import run_batch_etl


def main():
    parser = argparse.ArgumentParser(description="Batch ETL Automation Tool")
    parser.add_argument("--input", "-i", required=False, default="./demo_data/large_input.csv", help="Source CSV file path")
    parser.add_argument("--output", "-o", required=False, default="./output/result.xlsx", help="Target Excel output path")
    args = parser.parse_args()

    if not os.path.exists(args.input):
        print(f"Error: Input file not found: {args.input}")
        sys.exit(1)

    run_batch_etl(args.input, args.output)


if __name__ == "__main__":
    main()
