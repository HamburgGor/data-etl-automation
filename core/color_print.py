"""Console color constants for selective highlighting"""
import sys

RESET = "\033[0m"
BOLD = "\033[1m"
RED = "\033[1;38;5;196m"    # Bold bright red (critical errors)
GREEN = "\033[1;38;5;46m"   # Bold bright green (success & paths)
ORANGE = "\033[1;38;5;208m" # Bold orange (warnings & metrics)

def print_red(text: str):
    """Print bold red for critical errors"""
    print(f"{RED}{text}{RESET}")

def print_green(text: str):
    """Print bold green for success messages and paths"""
    print(f"{GREEN}{text}{RESET}")

def print_yellow(text: str):
    """Print bold orange for warnings and metrics"""
    print(f"{ORANGE}{text}{RESET}")

def print_single_line_progress(current: int, total: int, bar_length: int = 40):
    """Inline progress bar using \r"""
    if total <= 0:
        ratio = 0.0
    else:
        ratio = current / total
    filled = int(bar_length * ratio)
    bar = "#" * filled + "-" * (bar_length - filled)
    line = f"\rLoading: [{bar}] {current}/{total} | {ratio * 100:.2f}%"
    sys.stdout.write(f"{ORANGE}{line}{RESET}")
    sys.stdout.flush()

def finish_progress_line():
    """Newline after progress bar completion"""
    sys.stdout.write("\n")
    sys.stdout.flush()