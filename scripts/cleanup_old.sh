#!/bin/bash
# Keep exactly the latest 5 date-stamped CSV files
set -euo pipefail

DATA_DIR="/home/hamburg/data-etl-automation/demo_data"
cd "${DATA_DIR}" || { echo "ERROR: cannot cd to ${DATA_DIR}"; exit 1; }

files=()
for f in large_input_[0-9][0-9][0-9][0-9][0-9][0-9][0-9][0-9].csv; do
    [[ -f "$f" ]] && files+=("$f")
done

total=${#files[@]}
echo "$(date '+%Y-%m-%d %H:%M:%S') - Total date files: $total"

if [ $total -le 5 ]; then
    echo "Nothing to delete."
    exit 0
fi

# 按文件名排序（日期格式保证顺序）
mapfile -t sorted < <(printf '%s\n' "${files[@]}" | sort)
delete_count=$((total - 5))
echo "Deleting $delete_count oldest file(s)."

for ((i=0; i<delete_count; i++)); do
    echo "Deleted: ${sorted[$i]}"
    rm -f "${sorted[$i]}"
done
