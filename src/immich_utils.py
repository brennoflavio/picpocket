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

from src.constants import (
    APP_NAME,
    CRASH_REPORT_URL,
)
from src.ut_components import setup

setup(APP_NAME, CRASH_REPORT_URL)

import os
import time
from datetime import datetime
from urllib.parse import urljoin

import src.ut_components.http as http
from src.ut_components.config import get_cache_path
from src.ut_components.kv import KV
from src.utils import is_webp


def download_thumbnail(url: str, token: str, image_id: str) -> str:
    base_folder = os.path.join(get_cache_path(), "picpocket/thumbnail")
    os.makedirs(base_folder, exist_ok=True)
    file_path = os.path.join(base_folder, f"{image_id}.webp")

    if os.path.isfile(file_path):
        return file_path

    response = http.get(
        url=urljoin(url, f"/api/assets/{image_id}/thumbnail"),
        headers={"Authorization": f"Bearer {token}"},
        params={"size": "thumbnail"},
    )
    response.raise_for_status()
    data = response.data
    if is_webp(data):
        with open(file_path, "wb+") as f:
            f.write(data)
    return file_path


def download_photo_preview(url: str, token: str, image_id: str) -> str:
    base_folder = os.path.join(get_cache_path(), "picpocket/preview/photo")
    os.makedirs(base_folder, exist_ok=True)
    file_path = os.path.join(base_folder, f"{image_id}.jpeg")

    if os.path.isfile(file_path):
        return file_path

    response = http.get(
        url=urljoin(url, f"/api/assets/{image_id}/thumbnail"),
        headers={"Authorization": f"Bearer {token}"},
        params={"size": "preview"},
    )
    response.raise_for_status()
    with open(file_path, "wb+") as f:
        f.write(response.data)
    return file_path


def download_video_preview(url: str, token: str, video_id: str) -> str:
    base_folder = os.path.join(get_cache_path(), "picpocket/preview/video")
    os.makedirs(base_folder, exist_ok=True)
    file_path = os.path.join(base_folder, f"{video_id}.mp4")

    if os.path.isfile(file_path):
        return file_path

    response = http.get(
        url=urljoin(url, f"/api/assets/{video_id}/video/playback"),
        headers={"Authorization": f"Bearer {token}"},
    )
    response.raise_for_status()
    with open(file_path, "wb+") as f:
        f.write(response.data)
        f.flush()
    return file_path


def download_original(image_id: str) -> str:
    with KV() as kv:
        url = kv.get("immich.url")
        token = kv.get("immich.token")

        if not url or not token:
            raise ValueError("Missing URL or token")

        file_name = kv.get(f"photo.{image_id}.name")

        if not file_name:
            metadata_response = http.get(
                url=urljoin(url, f"/api/assets/{image_id}"),
                headers={"Authorization": f"Bearer {token}"},
            )
            metadata_response.raise_for_status()
            json_response = metadata_response.json()
            file_name = json_response.get("originalFileName", "")
            kv.put(f"photo.{image_id}.name", file_name, ttl_seconds=86400)

    base_folder = os.path.join(get_cache_path(), "picpocket/original", image_id)
    os.makedirs(base_folder, exist_ok=True)
    file_path = os.path.join(base_folder, file_name)

    if os.path.isfile(file_path):
        return file_path

    photo_response = http.get(
        url=urljoin(url, f"/api/assets/{image_id}/original"),
        headers={"Authorization": f"Bearer {token}"},
    )
    photo_response.raise_for_status()
    with open(file_path, "wb+") as f:
        f.write(photo_response.data)

    return file_path


def upload_photo(url: str, token: str, file_path: str, wait: bool = False) -> bool:
    stat_info = os.stat(file_path)
    modified_time = datetime.fromtimestamp(stat_info.st_mtime).isoformat()
    creation_time = datetime.fromtimestamp(stat_info.st_ctime).isoformat()

    file_name = file_path.split("/")[-1]
    now_ts = int(datetime.now().timestamp())
    data = {
        "deviceAssetId": f"ubuntu-touch-{file_name}-{now_ts}",
        "deviceId": "ubuntu-touch",
        "fileCreatedAt": creation_time,
        "fileModifiedAt": modified_time,
    }

    with open(file_path, "rb") as f:
        response = http.post_file(
            url=urljoin(url, "/api/assets"),
            file_data=f.read(),
            file_name=file_name,
            file_field="assetData",
            form_fields=data,
            headers={"Authorization": f"Bearer {token}"},
        )
        response.raise_for_status()
        if wait:
            time.sleep(1)
        return response.success


def download_people_thumbnail(url: str, token: str, person_id: str) -> str:
    base_folder = os.path.join(get_cache_path(), "picpocket/person-thumbnail")
    os.makedirs(base_folder, exist_ok=True)
    file_path = os.path.join(base_folder, f"{person_id}.jpeg")

    if os.path.isfile(file_path):
        return file_path

    response = http.get(
        url=urljoin(url, f"/api/people/{person_id}/thumbnail"),
        headers={"Authorization": f"Bearer {token}"},
    )
    response.raise_for_status()
    data = response.data
    with open(file_path, "wb+") as f:
        f.write(data)
    return file_path
