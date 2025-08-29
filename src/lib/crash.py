"""
Copyright (C) 2025  Brenno Flávio de Almeida

This program is free software: you can redistribute it and/or modify
it under the terms of the GNU General Public License as published by
the Free Software Foundation; version 3.

calpal is distributed in the hope that it will be useful,
but WITHOUT ANY WARRANTY; without even the implied warranty of
MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
GNU General Public License for more details.

You should have received a copy of the GNU General Public License
along with this program.  If not, see <http://www.gnu.org/licenses/>.
"""

import functools
import traceback
from typing import Any, Callable

from .http import post_dict


def crash_reporter(crash_url: str, crash_enabled_function: Callable[[], bool]):
    def decorator(func: Callable) -> Callable:
        @functools.wraps(func)
        def wrapper(*args, **kwargs) -> Any:
            try:
                return func(*args, **kwargs)
            except Exception:
                if crash_enabled_function():
                    traceback_str = traceback.format_exc()
                    post_dict(crash_url, {"report": traceback_str})
                raise

        return wrapper

    return decorator
