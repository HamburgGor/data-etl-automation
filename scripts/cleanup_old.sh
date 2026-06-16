#!/bin/bash
# Cleanup script: keep only the latest 5 virtual days' files.
set -euo pipefail

if [ -n "${SUDO_USER:-}" ]; then
    TARGET_USER="${SUDO_USER}"
else
    TARGET_USER="${USER}"
fi

DATA_DIR="/home/${TARGET_USER}/data-etl-automation/demo_data"

python3 -c "
import os, re
from datetime import datetime, timedelta

data_dir = '${DATA_DIR}'
pattern = re.compile(r'^large_input_(\d{8})\.csv$')

dates = []
for f in os.listdir(data_dir):
    m = pattern.match(f)
    if m:
        dates.append(m.group(1))

if not dates:
    exit(0)

dates.sort()
latest = dates[-1]
latest_date = datetime.strptime(latest, '%Y%m%d')
threshold = latest_date - timedelta(days=5)

for f in os.listdir(data_dir):
    m = pattern.match(f)
    if m:
        date_str = m.group(1)
        file_date = datetime.strptime(date_str, '%Y%m%d')
        if file_date <= threshold:
            os.remove(os.path.join(data_dir, f))
            print(f'Deleted: {f}')
"