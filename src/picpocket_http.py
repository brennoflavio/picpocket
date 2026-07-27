"""
Copyright (C) 2025  Brenno Flávio de Almeida

This program is free software: you can redistribute it and/or modify
it under the terms of the GNU General Public License as published by
the Free Software Foundation; version 3.

picpocket is distributed in the hope that it will be useful,
but WITHOUT ANY WARRANTY; without even the implied warranty of
MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
GNU General Public License for more details.

You should have received a copy of the GNU General Public License
along with this program.  If not, see <http://www.gnu.org/licenses/>.
"""

from typing import Dict, Optional

from src.ut_components import http as ut_http

USER_AGENT = "Picpocket (Ubuntu Touch; Linux; Immich client; +https://git.brennoflavio.com.br/brennoflavio/picpocket)"
Response = ut_http.Response


def _headers(headers: Optional[Dict[str, str]] = None) -> Dict[str, str]:
    request_headers = dict(headers or {})
    request_headers["User-Agent"] = USER_AGENT
    return request_headers


def request(
    url: str,
    method: str,
    data: Optional[bytes] = None,
    headers: Optional[Dict[str, str]] = None,
    follow_redirects: bool = True,
    max_redirects: int = 10,
) -> ut_http.Response:
    return ut_http.request(
        url=url,
        method=method,
        data=data,
        headers=_headers(headers),
        follow_redirects=follow_redirects,
        max_redirects=max_redirects,
    )


def get(
    url: str,
    headers: Optional[Dict[str, str]] = None,
    params: Optional[Dict[str, str]] = None,
) -> ut_http.Response:
    return ut_http.get(url=url, headers=_headers(headers), params=params)


def post(url: str, json: Optional[Dict] = None, headers: Optional[Dict[str, str]] = None) -> ut_http.Response:
    return ut_http.post(url=url, json=json, headers=_headers(headers))


def put(url: str, json: Optional[Dict] = None, headers: Optional[Dict[str, str]] = None) -> ut_http.Response:
    return ut_http.put(url=url, json=json, headers=_headers(headers))


def delete(url: str, json: Optional[Dict] = None, headers: Optional[Dict[str, str]] = None) -> ut_http.Response:
    return ut_http.delete(url=url, json=json, headers=_headers(headers))


def post_file(
    url: str,
    file_data: bytes,
    file_name: str,
    file_field: str,
    form_fields: Optional[Dict[str, str]] = None,
    headers: Optional[Dict[str, str]] = None,
) -> ut_http.Response:
    return ut_http.post_file(
        url=url,
        file_data=file_data,
        file_name=file_name,
        file_field=file_field,
        form_fields=form_fields,
        headers=_headers(headers),
    )
