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

import json
import urllib.error
import urllib.parse
import urllib.request
from dataclasses import dataclass
from typing import Dict, Optional


@dataclass
class DictResponse:
    success: bool
    status_code: int
    data: dict


@dataclass
class BinaryResponse:
    success: bool
    status_code: int
    data: bytes


def post_dict(url: str, data: Dict, headers: Optional[Dict[str, str]] = None) -> DictResponse:
    json_data = json.dumps(data).encode("utf-8")

    request_headers = {"Content-Type": "application/json"}
    if headers:
        request_headers.update(headers)

    request = urllib.request.Request(url, data=json_data, headers=request_headers)

    try:
        with urllib.request.urlopen(request) as response:
            response_data = response.read().decode("utf-8")
            return DictResponse(success=True, status_code=response.code, data=json.loads(response_data))
    except urllib.error.HTTPError as e:
        error_data = {}
        try:
            if e.fp:
                error_content = e.fp.read().decode("utf-8")
                error_data = json.loads(error_content)
        except Exception:
            pass

        return DictResponse(success=False, status_code=e.code, data=error_data)
    except urllib.error.URLError as e:
        return DictResponse(success=False, status_code=0, data={"error": str(e.reason)})
    except Exception as e:
        return DictResponse(success=False, status_code=0, data={"error": str(e)})


def get_dict(
    url: str,
    headers: Optional[Dict[str, str]] = None,
    params: Optional[Dict[str, str]] = None,
) -> DictResponse:
    if params:
        query_string = urllib.parse.urlencode(params)
        url = f"{url}?{query_string}"

    request_headers = {}
    if headers:
        request_headers.update(headers)

    request = urllib.request.Request(url, headers=request_headers)

    try:
        with urllib.request.urlopen(request) as response:
            response_data = response.read().decode("utf-8")
            return DictResponse(success=True, status_code=response.code, data=json.loads(response_data))
    except urllib.error.HTTPError as e:
        error_data = {}
        try:
            if e.fp:
                error_content = e.fp.read().decode("utf-8")
                error_data = json.loads(error_content)
        except Exception:
            pass

        return DictResponse(success=False, status_code=e.code, data=error_data)
    except urllib.error.URLError as e:
        return DictResponse(success=False, status_code=0, data={"error": str(e.reason)})
    except Exception as e:
        return DictResponse(success=False, status_code=0, data={"error": str(e)})


def get_binary(
    url: str,
    headers: Optional[Dict[str, str]] = None,
    params: Optional[Dict[str, str]] = None,
) -> BinaryResponse:
    if params:
        query_string = urllib.parse.urlencode(params)
        url = f"{url}?{query_string}"

    request_headers = {}
    if headers:
        request_headers.update(headers)

    request = urllib.request.Request(url, headers=request_headers)

    try:
        with urllib.request.urlopen(request) as response:
            response_data = response.read()
            return BinaryResponse(success=True, status_code=response.code, data=response_data)
    except urllib.error.HTTPError as e:
        error_data = b""
        try:
            if e.fp:
                error_data = e.fp.read()
        except Exception:
            pass

        return BinaryResponse(success=False, status_code=e.code, data=error_data)
    except urllib.error.URLError as e:
        return BinaryResponse(success=False, status_code=0, data=str(e.reason).encode("utf-8"))
    except Exception as e:
        return BinaryResponse(success=False, status_code=0, data=str(e).encode("utf-8"))


def put_dict(url: str, data: Dict, headers: Optional[Dict[str, str]] = None) -> DictResponse:
    json_data = json.dumps(data).encode("utf-8")

    request_headers = {"Content-Type": "application/json"}
    if headers:
        request_headers.update(headers)

    request = urllib.request.Request(url, data=json_data, headers=request_headers, method="PUT")

    try:
        with urllib.request.urlopen(request) as response:
            response_data = response.read().decode("utf-8")
            return DictResponse(success=True, status_code=response.code, data=json.loads(response_data))
    except urllib.error.HTTPError as e:
        error_data = {}
        try:
            if e.fp:
                error_content = e.fp.read().decode("utf-8")
                error_data = json.loads(error_content)
        except Exception:
            pass

        return DictResponse(success=False, status_code=e.code, data=error_data)
    except urllib.error.URLError as e:
        return DictResponse(success=False, status_code=0, data={"error": str(e.reason)})
    except Exception as e:
        return DictResponse(success=False, status_code=0, data={"error": str(e)})
