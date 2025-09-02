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
    DEFAULT_CACHE_DAYS,
    MAX_GALLERY_PER_PAGE,
)
from src.lib import setup

setup(APP_NAME, CRASH_REPORT_URL)

import os
import shutil
import time
from concurrent.futures import ThreadPoolExecutor
from dataclasses import dataclass
from datetime import datetime
from enum import Enum
from typing import List, Optional
from urllib.parse import urljoin

import src.lib.http as http
from src.lib.config import get_cache_path
from src.lib.crash import crash_reporter, get_crash_report, set_crash_report
from src.lib.kv import KV
from src.lib.memoize import delete_memoized, memoize
from src.lib.utils import dataclass_to_dict
from src.utils import add_month, is_webp


def set_crash_logs(crash_logs: bool):
    set_crash_report(crash_logs)


def get_crash_logs() -> bool:
    return get_crash_report()


@crash_reporter
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


@crash_reporter
def cache_routine():
    with KV() as kv:
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


@crash_reporter
def should_login() -> bool:
    with KV() as kv:
        url = kv.get("immich.url")
        token = kv.get("immich.token")
    if not token or not url:
        return True

    response = http.post(
        url=urljoin(url, "/api/auth/validateToken"),
        headers={"Authorization": f"Bearer {token}"},
    )

    if response.success:
        return False
    return True


@crash_reporter
@dataclass_to_dict
def login(url: str, email: str, password: str) -> ImmichResponse:
    response = http.post(url=urljoin(url, "/api/auth/login"), json={"email": email, "password": password})
    json_response = response.json()
    if not response.success:
        return ImmichResponse(success=False, message=json_response.get("error", "Unknown error"))

    token = json_response.get("accessToken")

    with KV() as kv:
        kv.put_cached("immich.url", url)
        kv.put_cached("immich.token", token)
        kv.commit_cached()

    return ImmichResponse(success=True, message="Login successful")


@dataclass
class Image:
    filePath: str
    id: str
    duration: Optional[str]


@crash_reporter
def thumbnail(url: str, token: str, image_id: str, duration: Optional[str]) -> Optional[Image]:
    base_folder = os.path.join(get_cache_path(APP_NAME), "thumbnail")
    os.makedirs(base_folder, exist_ok=True)
    file_path = os.path.join(base_folder, f"{image_id}.webp")

    if os.path.isfile(file_path):
        return Image(filePath=file_path, id=image_id, duration=duration)

    response = http.get(
        url=urljoin(url, f"/api/assets/{image_id}/thumbnail"),
        headers={"Authorization": f"Bearer {token}"},
        params={"size": "thumbnail"},
    )
    data = response.data
    if is_webp(data):
        with open(file_path, "wb+") as f:
            f.write(data)
        return Image(filePath=file_path, id=image_id, duration=duration)
    else:
        return None


@dataclass
class Day:
    date: str
    images: List[Image]


@dataclass
class TimelineResponse:
    month: str
    days: List[Day]
    next: Optional[str]
    previous: str


@memoize(300)
@crash_reporter
@dataclass_to_dict
def timeline(bucket: Optional[str] = None) -> TimelineResponse:
    if bucket:
        bucket_date, offset_str = bucket.split(",")
        offset = int(offset_str)
        current = datetime.fromisoformat(bucket_date)
    else:
        current = datetime.now().replace(day=1, hour=0, minute=0, second=0, microsecond=0)
        offset = 0
        bucket_date = current.isoformat()

    with KV() as kv:
        url = kv.get("immich.url")
        token = kv.get("immich.token")

        if not url or not token:
            raise ValueError("Missing URL or token")

        response = http.get(
            url=urljoin(url, "/api/timeline/bucket"),
            headers={"Authorization": f"Bearer {token}"},
            params={"timeBucket": bucket_date, "visibility": "timeline"},
        )
        response.raise_for_status()
        json_response = response.json()

        ids = json_response.get("id", [])[offset : offset + MAX_GALLERY_PER_PAGE]
        days = [x[8:10] for x in json_response.get("fileCreatedAt", [])[offset : offset + MAX_GALLERY_PER_PAGE]]
        durations = json_response.get("duration", [])[offset : offset + MAX_GALLERY_PER_PAGE]

        if len(ids) < MAX_GALLERY_PER_PAGE:
            previous_offset = 0
            previous_date = add_month(current, -1)
        else:
            previous_offset = offset + MAX_GALLERY_PER_PAGE
            previous_date = bucket_date

        if offset == 0:
            next_offset = 0
            next_date = add_month(current, 1)
            if next_date > datetime.now():
                next_date = None
        else:
            next_offset = offset - MAX_GALLERY_PER_PAGE
            next_date = bucket_date

        with ThreadPoolExecutor() as pool:
            futures = {}
            for i, id_ in enumerate(ids):
                duration = durations[i][3:8] if durations[i] else None
                futures[id_] = pool.submit(thumbnail, url, token, id_, duration)
                if i - 1 > 0:
                    kv.put_cached(f"photo.{id_}.previous", ids[i - 1])
                if i + 1 < len(ids):
                    kv.put_cached(f"photo.{id_}.next", ids[i + 1])
            kv.commit_cached()

        data_structure = {}
        for id_, day in zip(ids, days):
            future = futures.get(id_)
            if future:
                result = future.result()
                if result:
                    if day not in data_structure:
                        data_structure[day] = []
                    data_structure[day].append(result)

        days = []
        month = current.strftime("%B")
        for k, v in data_structure.items():
            days.append(Day(date=f"{month} {k}", images=v))

        return TimelineResponse(
            month=month,
            days=days,
            previous=f"{previous_date},{str(previous_offset)}",
            next=f"{next_date},{str(next_offset)}" if next_date else None,
        )


class FileType(str, Enum):
    IMAGE = "IMAGE"
    VIDEO = "VIDEO"


@dataclass
class Preview:
    filePath: str
    id: str
    name: str
    file_type: str
    previous: Optional[str]
    next: Optional[str]
    favorite: bool


@crash_reporter
def preview_image(
    url: str,
    token: str,
    base_folder: str,
    image_id: str,
    file_name: str,
    favorite: bool,
) -> Preview:
    with KV() as kv:
        previous = kv.get(f"photo.{image_id}.previous")
        next_ = kv.get(f"photo.{image_id}.next")

    file_path = os.path.join(base_folder, f"{image_id}.jpeg")

    if os.path.isfile(file_path):
        return Preview(
            filePath=file_path,
            id=image_id,
            name=file_name,
            file_type=FileType.IMAGE,
            previous=previous,
            next=next_,
            favorite=favorite,
        )

    photo_response = http.get(
        url=urljoin(url, f"/api/assets/{image_id}/thumbnail"),
        headers={"Authorization": f"Bearer {token}"},
        params={"size": "preview"},
    )
    photo_response.raise_for_status()
    with open(file_path, "wb+") as f:
        f.write(photo_response.data)

    return Preview(
        filePath=file_path,
        id=image_id,
        name=file_name,
        file_type=FileType.IMAGE,
        previous=previous,
        next=next_,
        favorite=favorite,
    )


@crash_reporter
def preview_video(
    url: str,
    token: str,
    base_folder: str,
    image_id: str,
    file_name: str,
    favorite: bool,
) -> Preview:
    with KV() as kv:
        previous = kv.get(f"photo.{image_id}.previous")
        next_ = kv.get(f"photo.{image_id}.next")

    file_path = os.path.join(base_folder, f"{image_id}.mp4")

    if os.path.isfile(file_path):
        return Preview(
            filePath=file_path,
            id=image_id,
            name=file_name,
            file_type=FileType.VIDEO,
            previous=previous,
            next=next_,
            favorite=favorite,
        )

    video_response = http.get(
        url=urljoin(url, f"/api/assets/{image_id}/video/playback"),
        headers={"Authorization": f"Bearer {token}"},
    )
    video_response.raise_for_status()
    with open(file_path, "wb+") as f:
        f.write(video_response.data)
        f.flush()

    return Preview(
        filePath=file_path,
        id=image_id,
        name=file_name,
        file_type=FileType.VIDEO,
        previous=previous,
        next=next_,
        favorite=favorite,
    )


@crash_reporter
@dataclass_to_dict
def preview(image_id: str) -> Preview:
    with KV() as kv:
        url = kv.get("immich.url")
        token = kv.get("immich.token")

        if not url or not token:
            raise ValueError("Missing URL or token")

        file_name = kv.get(f"photo.{image_id}.name")
        file_type = kv.get(f"photo.{image_id}.type")
        favorite = kv.get(f"photo.{image_id}.favorite")

        if not file_name or not file_type or favorite is None:
            metadata_response = http.get(
                urljoin(url, f"/api/assets/{image_id}"),
                headers={"Authorization": f"Bearer {token}"},
            )
            metadata_response.raise_for_status()
            json_response = metadata_response.json()
            file_name = json_response.get("originalFileName", "")
            file_type = json_response.get("type", "IMAGE")
            favorite = json_response.get("isFavorite", False)

            kv.put(f"photo.{image_id}.name", file_name, ttl_seconds=300)
            kv.put(f"photo.{image_id}.type", file_type, ttl_seconds=300)
            kv.put(f"photo.{image_id}.favorite", favorite, ttl_seconds=300)

    base_folder = os.path.join(get_cache_path(APP_NAME), "preview")
    os.makedirs(base_folder, exist_ok=True)

    if file_type == "VIDEO":
        return preview_video(url, token, base_folder, image_id, file_name, favorite)

    return preview_image(url, token, base_folder, image_id, file_name, favorite)


@crash_reporter
def original(image_id: str) -> str:
    with KV() as kv:
        url = kv.get("immich.url")
        token = kv.get("immich.token")

    if not url or not token:
        raise ValueError("Missing URL or token")

    with KV() as kv:
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

    base_folder = os.path.join(get_cache_path(APP_NAME), "original", image_id)
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


@crash_reporter
def set_cache_days(days: int):
    with KV() as kv:
        kv.put("settings.cache.days", days)


@crash_reporter
def get_cache_days() -> int:
    with KV() as kv:
        return kv.get("settings.cache.days", DEFAULT_CACHE_DAYS, True) or DEFAULT_CACHE_DAYS


@crash_reporter
def logout():
    with KV() as kv:
        kv.delete("immich.url")
        kv.delete("immich.token")


@crash_reporter
def favorite(image_id: str, favorite: bool):
    with KV() as kv:
        url = kv.get("immich.url")
        token = kv.get("immich.token")

        if not url or not token:
            raise ValueError("Missing URL or token")

        response = http.put(
            url=urljoin(url, f"/api/assets/{image_id}"),
            json={"isFavorite": favorite},
            headers={"Authorization": f"Bearer {token}"},
        )
        response.raise_for_status()

        kv.put(f"photo.{image_id}.favorite", favorite, ttl_seconds=300)


@crash_reporter
def archive(image_id: str):
    with KV() as kv:
        url = kv.get("immich.url")
        token = kv.get("immich.token")

        if not url or not token:
            raise ValueError("Missing URL or token")

        response = http.put(
            url=urljoin(url, f"/api/assets/{image_id}"),
            json={"visibility": "archive"},
            headers={"Authorization": f"Bearer {token}"},
        )
        response.raise_for_status()
    delete_memoized(timeline)


@crash_reporter
def delete(image_id: str):
    with KV() as kv:
        url = kv.get("immich.url")
        token = kv.get("immich.token")

        if not url or not token:
            raise ValueError("Missing URL or token")

        response = http.delete(
            url=urljoin(url, "/api/assets"),
            json={"ids": [image_id]},
            headers={"Authorization": f"Bearer {token}"},
        )
        response.raise_for_status()
    delete_memoized(timeline)


@crash_reporter
def upload_photo(file_path: str) -> bool:
    with KV() as kv:
        url = kv.get("immich.url")
        token = kv.get("immich.token")

        if not url or not token:
            raise ValueError("Missing URL or token")

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
        delete_memoized(timeline)
        time.sleep(0.5)
        return response.success


def delete_cache():
    with KV() as kv:
        kv.delete_partial("photo")

    thumbnail_folder = os.path.join(get_cache_path(APP_NAME), "thumbnail")
    preview_folder = os.path.join(get_cache_path(APP_NAME), "preview")
    original_folder = os.path.join(get_cache_path(APP_NAME), "original")

    shutil.rmtree(thumbnail_folder, ignore_errors=True)
    shutil.rmtree(preview_folder, ignore_errors=True)
    shutil.rmtree(original_folder, ignore_errors=True)
    delete_memoized(timeline)
