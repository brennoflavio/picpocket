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
import hashlib
import json
from typing import Any, Callable

from .kv import KV


def memoize(app_name: str, ttl_seconds: int):
    def decorator(func: Callable) -> Callable:
        @functools.wraps(func)
        def wrapper(*args, **kwargs) -> Any:
            function_name = f"{func.__module__}.{func.__name__}"
            encoded_args = f"{json.dumps(args, sort_keys=True)}-{json.dumps(kwargs, sort_keys=True)}"
            hashed_function_name = hashlib.sha1(f"{function_name}".encode()).hexdigest()
            hashed_encoded_args = hashlib.sha1(f"{encoded_args}".encode()).hexdigest()
            with KV(app_name) as kv:
                response = kv.get(f"memoize.{hashed_function_name}.{hashed_encoded_args}")
                if response is not None:
                    return response
                result = func(*args, **kwargs)
                kv.put(
                    f"memoize.{hashed_function_name}.{hashed_encoded_args}",
                    result,
                    ttl_seconds=ttl_seconds,
                )
                return result

        return wrapper

    return decorator


def delete_memoized(app_name: str, function: Callable):
    function_name = f"{function.__module__}.{function.__name__}"
    hashed_function_name = hashlib.sha1(f"{function_name}".encode()).hexdigest()
    with KV(app_name) as kv:
        kv.delete_partial(f"memoize.{hashed_function_name}")
