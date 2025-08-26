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

import os
import time
from concurrent.futures import ThreadPoolExecutor
from dataclasses import dataclass
from datetime import datetime
from enum import Enum
from typing import List
from urllib.parse import urljoin

from src.constants import APP_NAME, CRASH_REPORT_URL, DEFAULT_CACHE_DAYS
from src.lib.config import get_cache_path
from src.lib.crash import crash_reporter
from src.lib.http import get_binary, get_dict, post_dict
from src.lib.kv import KV
from src.lib.utils import dataclass_to_dict


def set_crash_logs(crash_logs: bool):
    with KV(APP_NAME) as kv:
        kv.put("settings.crash.logs", crash_logs)


def get_crash_logs() -> bool:
    with KV(APP_NAME) as kv:
        return kv.get("settings.crash.logs", False, True) or False


@crash_reporter(CRASH_REPORT_URL, get_crash_logs)
def clear_cache(path: str, days: int):
    if not os.path.exists(path):
        return

    current_time = time.time()
    age_limit = days * 24 * 60 * 60

    for root, _, files in os.walk(path):
        for filename in files:
            file_path = os.path.join(root, filename)
            try:
                file_age = current_time - os.path.getmtime(file_path)
                if file_age > age_limit:
                    os.remove(file_path)
            except (OSError, IOError):
                pass


@crash_reporter(CRASH_REPORT_URL, get_crash_logs)
def cache_routine():
    with KV(APP_NAME) as kv:
        cache_days = kv.get("settings.cache.days", DEFAULT_CACHE_DAYS, True)
    thumbnail_folder = os.path.join(get_cache_path(APP_NAME), "thumbnail")
    preview_folder = os.path.join(get_cache_path(APP_NAME), "preview")
    original_folder = os.path.join(get_cache_path(APP_NAME), "original")

    clear_cache(thumbnail_folder, cache_days or DEFAULT_CACHE_DAYS)
    clear_cache(preview_folder, cache_days or DEFAULT_CACHE_DAYS)
    clear_cache(original_folder, cache_days or DEFAULT_CACHE_DAYS)


@dataclass
class ImmichResponse:
    success: bool
    message: str


@crash_reporter(CRASH_REPORT_URL, get_crash_logs)
def should_login() -> bool:
    cache_routine()
    with KV(APP_NAME) as kv:
        url = kv.get("immich.url")
        token = kv.get("immich.token")
    if not token or not url:
        return True

    response = post_dict(
        urljoin(url, "/api/auth/validateToken"),
        {},
        headers={"Authorization": f"Bearer {token}"},
    )

    if response.success:
        return False
    return True


@crash_reporter(CRASH_REPORT_URL, get_crash_logs)
@dataclass_to_dict
def login(url: str, email: str, password: str) -> ImmichResponse:
    response = post_dict(urljoin(url, "/api/auth/login"), {"email": email, "password": password})
    if not response.success:
        return ImmichResponse(success=False, message=response.data.get("error", "Unknown error"))

    token = response.data.get("accessToken")
    user_id = response.data.get("userId")
    user_email = response.data.get("userEmail")
    user_name = response.data.get("name")
    is_admin = response.data.get("isAdmin")
    profile_image_path = response.data.get("profileImagePath")
    should_change_password = response.data.get("shouldChangePassword")
    is_onboarded = response.data.get("isOnboarded")

    with KV(APP_NAME) as kv:
        kv.put("immich.url", url)
        kv.put("immich.token", token)
        kv.put("immich.user_id", user_id)
        kv.put("immich.user_email", user_email)
        kv.put("immich.user_name", user_name)
        kv.put("immich.is_admin", str(is_admin))
        kv.put("immich.profile_image_path", profile_image_path)
        kv.put("immich.should_change_password", str(should_change_password))
        kv.put("immich.is_onboarded", str(is_onboarded))

    return ImmichResponse(success=True, message="Login successful")


@dataclass
class Image:
    filePath: str
    id: str


@crash_reporter(CRASH_REPORT_URL, get_crash_logs)
def thumbnail(url: str, token: str, image_id: str) -> Image:
    base_folder = os.path.join(get_cache_path(APP_NAME), "thumbnail")
    os.makedirs(base_folder, exist_ok=True)
    file_path = os.path.join(base_folder, f"{image_id}.webp")

    if os.path.isfile(file_path):
        return Image(filePath=file_path, id=image_id)

    response = get_binary(
        urljoin(url, f"/api/assets/{image_id}/thumbnail"),
        headers={"Authorization": f"Bearer {token}"},
        params={"size": "thumbnail"},
    )
    with open(file_path, "wb+") as f:
        f.write(response.data)
    return Image(filePath=file_path, id=image_id)


@dataclass
class Day:
    date: str
    images: List[Image]


@dataclass
class TimelineResponse:
    month: str
    days: List[Day]


@crash_reporter(CRASH_REPORT_URL, get_crash_logs)
@dataclass_to_dict
def timeline():
    with KV(APP_NAME) as kv:
        url = kv.get("immich.url")
        token = kv.get("immich.token")

    if not url or not token:
        raise ValueError("Missing URL or token")

    now = datetime.now().replace(day=1, hour=0, minute=0, second=0, microsecond=0)
    month = now.strftime("%B")

    bucket_date = now.isoformat()
    response = get_dict(
        urljoin(url, "/api/timeline/bucket"),
        headers={"Authorization": f"Bearer {token}"},
        params={"timeBucket": bucket_date, "visibility": "timeline"},
    )
    ids = response.data.get("id", [])
    days = [x[8:10] for x in response.data.get("fileCreatedAt", [])]

    with ThreadPoolExecutor() as pool:
        futures = {}
        for id_ in ids:
            futures[id_] = pool.submit(thumbnail, url, token, id_)

    data_structure = {}
    for id_, day in zip(ids, days):
        if day not in data_structure:
            data_structure[day] = []
        data_structure[day].append(futures[id_].result())

    days = []
    for k, v in data_structure.items():
        days.append(Day(date=f"{month} {k}", images=v))

    return TimelineResponse(month=month, days=days)


class FileType(str, Enum):
    IMAGE = "IMAGE"
    VIDEO = "VIDEO"


@dataclass
class Preview:
    filePath: str
    id: str
    name: str
    file_type: str


@crash_reporter(CRASH_REPORT_URL, get_crash_logs)
def preview_image(url: str, token: str, base_folder: str, image_id: str, file_name: str) -> Preview:
    file_path = os.path.join(base_folder, f"{image_id}.jpeg")

    if os.path.isfile(file_path):
        return Preview(filePath=file_path, id=image_id, name=file_name, file_type=FileType.IMAGE)

    photo_response = get_binary(
        urljoin(url, f"/api/assets/{image_id}/thumbnail"),
        headers={"Authorization": f"Bearer {token}"},
        params={"size": "preview"},
    )
    with open(file_path, "wb+") as f:
        f.write(photo_response.data)

    return Preview(filePath=file_path, id=image_id, name=file_name, file_type=FileType.IMAGE)


@crash_reporter(CRASH_REPORT_URL, get_crash_logs)
def preview_video(url: str, token: str, base_folder: str, image_id: str, file_name: str) -> Preview:
    file_path = os.path.join(base_folder, f"{image_id}.mp4")

    if os.path.isfile(file_path):
        return Preview(filePath=file_path, id=image_id, name=file_name, file_type=FileType.VIDEO)

    video_response = get_binary(
        urljoin(url, f"/api/assets/{image_id}/video/playback"),
        headers={"Authorization": f"Bearer {token}"},
    )
    with open(file_path, "wb+") as f:
        f.write(video_response.data)
        f.flush()

    return Preview(filePath=file_path, id=image_id, name=file_name, file_type=FileType.VIDEO)


@crash_reporter(CRASH_REPORT_URL, get_crash_logs)
@dataclass_to_dict
def preview(image_id: str) -> Preview:
    with KV(APP_NAME) as kv:
        url = kv.get("immich.url")
        token = kv.get("immich.token")

        if not url or not token:
            raise ValueError("Missing URL or token")

        file_name = kv.get(f"photo.{image_id}.name")
        file_type = kv.get(f"photo.{image_id}.type")

        if not file_name or not file_type:
            metadata_response = get_dict(
                urljoin(url, f"/api/assets/{image_id}"),
                headers={"Authorization": f"Bearer {token}"},
            )
            file_name = metadata_response.data.get("originalFileName", "")
            file_type = metadata_response.data.get("type", "IMAGE")

    base_folder = os.path.join(get_cache_path(APP_NAME), "preview")
    os.makedirs(base_folder, exist_ok=True)

    if file_type == "VIDEO":
        return preview_video(url, token, base_folder, image_id, file_name)

    return preview_image(url, token, base_folder, image_id, file_name)


@crash_reporter(CRASH_REPORT_URL, get_crash_logs)
def original(image_id: str) -> str:
    with KV(APP_NAME) as kv:
        url = kv.get("immich.url")
        token = kv.get("immich.token")

    if not url or not token:
        raise ValueError("Missing URL or token")

    with KV(APP_NAME) as kv:
        file_name = kv.get(f"photo.{image_id}.name")

        if not file_name:
            metadata_response = get_dict(
                urljoin(url, f"/api/assets/{image_id}"),
                headers={"Authorization": f"Bearer {token}"},
            )
            file_name = metadata_response.data.get("originalFileName", "")
            kv.put(f"photo.{image_id}.name", file_name, ttl_seconds=86400)

    base_folder = os.path.join(get_cache_path(APP_NAME), "original", image_id)
    os.makedirs(base_folder, exist_ok=True)
    file_path = os.path.join(base_folder, file_name)

    if os.path.isfile(file_path):
        return file_path

    photo_response = get_binary(
        urljoin(url, f"/api/assets/{image_id}/original"),
        headers={"Authorization": f"Bearer {token}"},
    )
    with open(file_path, "wb+") as f:
        f.write(photo_response.data)

    return file_path


@crash_reporter(CRASH_REPORT_URL, get_crash_logs)
def set_cache_days(days: int):
    with KV(APP_NAME) as kv:
        kv.put("settings.cache.days", days)


@crash_reporter(CRASH_REPORT_URL, get_crash_logs)
def get_cache_days() -> int:
    with KV(APP_NAME) as kv:
        return kv.get("settings.cache.days", DEFAULT_CACHE_DAYS, True) or DEFAULT_CACHE_DAYS


@crash_reporter(CRASH_REPORT_URL, get_crash_logs)
def logout():
    with KV(APP_NAME) as kv:
        kv.delete("immich.url")
        kv.delete("immich.token")
        kv.delete("immich.user_id")
        kv.delete("immich.user_email")
        kv.delete("immich.user_name")
        kv.delete("immich.is_admin")
        kv.delete("immich.profile_image_path")
        kv.delete("immich.should_change_password")
        kv.delete("immich.is_onboarded")
