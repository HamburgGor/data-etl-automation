# Data ETL Automation 批量数据自动化处理工具

一款基于 Python + Bash 开发的批量数据自动化 ETL 处理工具，原生支持超大文件分块清洗、数据格式标准化、处理进度可视化，同时适配 Linux 服务器一键部署、后台常驻运行，开箱即用、稳定高效。

\---

## ✨ 核心特性

* **Python 智能批量数据清洗**：自动剔除全空行、重复数据行，精准标记负数异常金额，批量清理文本中隐藏的不可见字符，标准化原始脏数据。
* **分块流式处理机制**：摒弃全量加载模式，采用流式分块读取，彻底规避内存溢出问题，轻松支撑百万行级 CSV 大文件处理。
* **终端彩色进度可视化**：实现单行覆盖式进度条刷新，无刷屏干扰，实时同步展示文件处理行数、完成百分比，处理状态一目了然。
* **稳定容错重试机制**：任务执行失败自动重试，达到重试次数上限后触发止损告警，有效避免任务静默中断，保障批量任务完整性。
* **Bash 一站式自动化运维**：支持服务器环境一键初始化、systemd 系统服务自动创建、cron 定时任务自动注册，实现服务健康巡检与定时清理。
* **数据生命周期自动化管理**：定时自动生成带日期戳的测试演示数据，同时自动清理超 5 天的过期旧文件，无需人工维护。

\---

## 📁 完整项目结构

```text
data-etl-automation/
├── .gitignore              # Git 忽略配置
├── README.md               # 项目说明文档
├── requirements.txt        # Python 依赖清单
├── main.py                 # ETL 程序主入口
├── gen\\\_test\\\_data.py        # 生成 50 万行测试脏数据（支持定时生成日期文件）
├── core/                   # 公共工具底层（通用能力封装）
│   ├── \\\_\\\_init\\\_\\\_.py
│   ├── color\\\_print.py      # ANSI 彩色日志 + 可视化进度条
│   ├── data\\\_cleaner.py     # 核心数据清洗工具类与方法
│   └── stable\\\_retry.py     # 任务重试装饰器（容错机制）
├── tasks/                  # 业务逻辑层
│   ├── \\\_\\\_init\\\_\\\_.py
│   └── batch\\\_task.py       # ETL 批处理核心流程
├── scripts/                # 部署与运维脚本
│   ├── deploy.sh           # 服务器一键部署脚本
│   └── cleanup\\\_old.sh      # 过期数据定时清理脚本
└── tests/                  # 测试用例目录（预留）
    └── \\\_\\\_init\\\_\\\_.py
```

自动生成目录：项目运行后将自动创建 demo\_data/（测试数据）、output/（处理结果）、logs/（运行日志），无需手动新建。
🚀 快速开始（本地开发环境）

1. 环境要求
* Python 3.8+
* pip 包管理工具
2. 安装项目依赖

# 创建虚拟环境

```text
python -m venv Myvenv
```

# 激活虚拟环境

# Linux / MacOS

```text
source Myvenv/bin/activate
```

# Windows

```text
Myvenv\\\\Scripts\\\\activate
```

# 安装全部依赖

```text
pip install -r requirements.txt
```

3. 生成测试数据

# 生成50万行超大脏数据（用于演示）

```text
python gen\\\_test\\\_data.py
```

4. 执行 ETL 数据处理

# 自定义输入输出路径运行

```text
python main.py --input demo\\\_data/large\\\_input.csv --output output/result.xlsx
```

# 使用默认配置快速运行

```text
python main.py
```

🖥️ Ubuntu 服务器正式部署
支持一键自动化部署，全程无需手动配置环境、服务与定时任务，部署后永久后台常驻。

# 1\. 克隆项目至服务器指定目录

```text
git clone https://github.com/HamburgGor/data-etl-automation.git
cd \\\~/data-etl-automation
```

# 2\. 赋予运维脚本执行权限并启动部署

```text
chmod +x scripts/\\\*.sh
sudo ./scripts/deploy.sh
```

部署自动完成以下配置

* 自动安装 Python3、pip、venv 基础环境
* 创建独立隔离虚拟环境 \~/Myvenv
* 自动安装 pandas、openpyxl 等核心依赖
* 注册 etl\_auto\_main 系统服务，支持崩溃自动重启
* 配置多项 cron 定时任务：

  * 每日 07:50 / 19:50 巡检服务状态，异常自动拉起
  * 每分钟自动生成下一个虚拟日期的演示数据文件
  * 每分钟（延迟30秒）自动清理，始终保留最新5个文件
  * 每分钟（延迟45秒）自动运行 ETL 主程序，导出结果 Excel
常用运维命令

# 查看服务运行状态

```text
sudo systemctl status etl\\\_auto\\\_main
```

# 查看实时运行日志

```text
journalctl -u etl\\\_auto\\\_main -f
```

# 实时查看数据生成日志

```text

tail -f logs/gen.log

```

# 实时查看自动清理日志

```text
tail -f logs/cleanup.log
```

# 实时查看 ETL 自动运行日志

```text

tail -f logs/main\_cron.log

```

# 重启 ETL 服务

```text
sudo systemctl restart etl\\\_auto\\\_main
```

# 停止 ETL 服务

```text
sudo systemctl stop etl\\\_auto\\\_main
```

🧪 核心数据清洗逻辑
内置标准化清洗规则，适配绝大多数业务脏数据场景，规则可自定义拓展。
清洗步骤
详细处理说明
删除全空行
批量移除所有字段均为空的无效数据行，精简数据集
数据去重
保留首次出现的数据行，彻底删除完全重复的冗余行，保证数据唯一性
异常金额处理
识别 amount 字段负数数据，自动转为 NaN 标记为异常数据，便于后续筛选核查
文本标准化清理
清除文本首尾多余空格、不可见特殊字符、乱码字符，统一文本格式
📊 进度展示与日志体系

* 终端实时进度：手动运行脚本时，彩色动态进度条实时刷新处理行数与百分比，无刷屏干扰
* 任务运行日志：`logs/main\\\_run.log` 记录 ETL 任务的完整执行过程及错误信息。
* 数据生成日志：`logs/gen.log` 每分钟记录一次生成完成信息。
* 数据清理日志：`logs/cleanup.log` 记录每次清理的删除明细。
* ETL 自动运行日志：`logs/main\_cron.log` 记录每分钟自动执行的 ETL 处理结果。
* 部署历史日志：`logs/etl\_deploy\_update.log` 记录每次部署的完整过程。
* 系统服务日志：通过 `journalctl -u etl\_auto\_main` 查看服务启停、崩溃及自动重启记录。
📦 核心依赖项
所有依赖版本可兼容主流服务器环境，详细版本约束见 requirements.txt

```text
- pandas ≥ 1.3.0
- openpyxl ≥ 3.0.0
```

📄 开源许可
本项目基于 MIT License 开源，可自由使用、修改与二次分发。

