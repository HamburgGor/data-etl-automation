"""Retry decorator with stop-loss"""
import time
from core.color_print import print_yellow, print_red

def stable_retry_wrapper(max_retry: int = 3, sleep_sec: int = 2):
    """
    Decorator that retries on failure and raises if all attempts exhausted.
    """
    def decorator(task_func):
        def wrapper(*args, **kwargs):
            last_exception = None
            for attempt in range(1, max_retry + 1):
                try:
                    return task_func(*args, **kwargs)
                except Exception as e:
                    last_exception = e
                    msg = f"[RETRY] Attempt {attempt}/{max_retry} failed: {str(e)}"
                    print_yellow(msg)
                    if attempt < max_retry:
                        time.sleep(sleep_sec)
            crash_msg = f"[CRITICAL] All {max_retry} attempts failed, task terminated."
            print_red(crash_msg)
            raise RuntimeError(crash_msg) from last_exception
        return wrapper
    return decorator