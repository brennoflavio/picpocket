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
    APP_ID,
    APP_NAME,
    CRASH_REPORT_URL,
    CRON_DEFAULT_EXPRESSION,
    CRON_URL,
    DEFAULT_CACHE_DAYS,
    MAX_GALLERY_PER_PAGE,
)
from src.lib import setup

setup(APP_NAME, CRASH_REPORT_URL)

import os
import shutil
from concurrent.futures import ThreadPoolExecutor
from dataclasses import dataclass
from datetime import datetime
from enum import Enum
from typing import Dict, List, Optional
from urllib.parse import urljoin

import src.lib.http as http
from src.immich_utils import (
    download_original,
    download_photo_preview,
    download_thumbnail,
    download_video_preview,
    upload_photo,
)
from src.lib.config import get_cache_path
from src.lib.crash import crash_reporter, get_crash_report, set_crash_report
from src.lib.kv import KV
from src.lib.memoize import delete_memoized, memoize
from src.lib.utils import dataclass_to_dict
from src.utils import add_month


def set_crash_logs(crash_logs: bool):
    set_crash_report(crash_logs)


def get_crash_logs() -> bool:
    return get_crash_report()


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
    file_path = download_thumbnail(url, token, image_id)
    return Image(filePath=file_path, id=image_id, duration=duration)


@dataclass
class Day:
    date: str
    images: List[Image]


@dataclass
class TimelineResponse:
    month: str
    days: List[Day]
    next: Optional[str]
    previous: Optional[str]


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
                if i - 1 >= 0:
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
    image_id: str,
    file_name: str,
    favorite: bool,
) -> Preview:
    with KV() as kv:
        previous = kv.get(f"photo.{image_id}.previous")
        next_ = kv.get(f"photo.{image_id}.next")

    file_path = download_photo_preview(url, token, image_id)

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
    image_id: str,
    file_name: str,
    favorite: bool,
) -> Preview:
    with KV() as kv:
        previous = kv.get(f"photo.{image_id}.previous")
        next_ = kv.get(f"photo.{image_id}.next")

    file_path = download_video_preview(url, token, image_id)

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
def timeline_preview(image_id: str) -> Preview:
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

    if file_type == "VIDEO":
        return preview_video(url, token, image_id, file_name, favorite)

    return preview_image(url, token, image_id, file_name, favorite)


@crash_reporter
def original(image_id: str) -> str:
    file_path = download_original(image_id)
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


def delete_cache():
    with KV() as kv:
        kv.delete_partial("photo")

    thumbnail_folder = os.path.join(get_cache_path(), "thumbnail")
    preview_folder = os.path.join(get_cache_path(), "preview")
    original_folder = os.path.join(get_cache_path(), "original")
    memories_folder = os.path.join(get_cache_path(), "memories")
    picpocket_folder = os.path.join(get_cache_path(), "picpocket")

    shutil.rmtree(thumbnail_folder, ignore_errors=True)
    shutil.rmtree(preview_folder, ignore_errors=True)
    shutil.rmtree(original_folder, ignore_errors=True)
    shutil.rmtree(memories_folder, ignore_errors=True)
    shutil.rmtree(picpocket_folder, ignore_errors=True)
    delete_memoized(timeline)
    delete_memoized(memories)
    delete_memoized(albums)


def persist_token(token: str):
    with KV() as kv:
        kv.put("ut.notification.token", token)


@crash_reporter
def set_auto_sync(enabled: bool):
    with KV() as kv:
        token = kv.get("ut.notification.token")
        if enabled:
            data = {
                "appid": APP_ID,
                "token": token,
                "cron_expression": CRON_DEFAULT_EXPRESSION,
            }
            response = http.post(CRON_URL, json=data)
            response.raise_for_status()
        else:
            response = http.delete(CRON_URL, json={"appid": APP_ID, "token": token})
            response.raise_for_status()
        kv.put("settings.sync.auto", enabled)


@crash_reporter
def get_auto_sync() -> bool:
    with KV() as kv:
        return kv.get("settings.sync.auto", False, True) or False


@crash_reporter
def clear_cache():
    with KV() as kv:
        kv.delete_partial("photo")
        kv.delete_partial("album")
        kv.delete_partial("memory")
    delete_memoized(timeline)
    delete_memoized(memories)
    delete_memoized(albums)
    delete_memoized(get_album_assets)
    delete_memoized(album_detail)


@dataclass
class Memory:
    title: str
    thumbnail_url: str
    first_image_id: str


@dataclass
class MemoryContainer:
    memories: List[Memory]


@memoize(43200)
@crash_reporter
@dataclass_to_dict
def memories() -> MemoryContainer:
    with KV() as kv:
        url = kv.get("immich.url")
        token = kv.get("immich.token")

        if not url or not token:
            raise ValueError("Missing URL or token")

        response = http.get(
            url=urljoin(url, "/api/memories"),
            params={"for": datetime.now().isoformat()},
            headers={"Authorization": f"Bearer {token}"},
        )
        response.raise_for_status()
        json_response = response.json()
        memories = []
        for memory in json_response:
            year = memory.get("data", {}).get("year")
            assets = memory.get("assets", [])
            if len(assets) == 0:
                continue

            first_asset = assets[0]
            first_asset_type = first_asset.get("type")
            if not first_asset_type:
                continue

            first_asset_image_id = first_asset.get("id")
            if not first_asset_image_id:
                continue

            file_path = download_thumbnail(url, token, first_asset_image_id)
            memories.append(Memory(title=str(year), thumbnail_url=file_path, first_image_id=first_asset_image_id))

            for i, asset in enumerate(assets):
                asset_id = asset.get("id")
                if i - 1 >= 0:
                    kv.put_cached(f"memory.{asset_id}.previous", assets[i - 1]["id"], ttl_seconds=600)
                if i + 1 < len(assets):
                    kv.put_cached(f"memory.{asset_id}.next", assets[i + 1]["id"], ttl_seconds=600)
            kv.commit_cached()

        return MemoryContainer(memories=memories)


@crash_reporter
def memory_preview_video(
    url: str,
    token: str,
    image_id: str,
    file_name: str,
    favorite: bool,
) -> Preview:
    with KV() as kv:
        previous = kv.get(f"memory.{image_id}.previous")
        next_ = kv.get(f"memory.{image_id}.next")

    file_path = download_video_preview(url, token, image_id)

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
def memory_preview_image(
    url: str,
    token: str,
    image_id: str,
    file_name: str,
    favorite: bool,
) -> Preview:
    with KV() as kv:
        previous = kv.get(f"memory.{image_id}.previous")
        next_ = kv.get(f"memory.{image_id}.next")

    file_path = download_photo_preview(url, token, image_id)

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
@dataclass_to_dict
def memory_preview(image_id: str) -> Preview:
    with KV() as kv:
        url = kv.get("immich.url")
        token = kv.get("immich.token")

        if not url or not token:
            raise ValueError("Missing URL or token")

        file_name = kv.get(f"memory.{image_id}.name")
        file_type = kv.get(f"memory.{image_id}.type")
        favorite = kv.get(f"memory.{image_id}.favorite")

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

            kv.put(f"memory.{image_id}.name", file_name, ttl_seconds=300)
            kv.put(f"memory.{image_id}.type", file_type, ttl_seconds=300)
            kv.put(f"memory.{image_id}.favorite", favorite, ttl_seconds=300)

    if file_type == "VIDEO":
        return memory_preview_video(url, token, image_id, file_name, favorite)

    return memory_preview_image(url, token, image_id, file_name, favorite)


@dataclass
class Album:
    id: str
    file_path: str
    name: str
    asset_count: int
    shared: bool


@dataclass
class Albums:
    albums: List[Album]


@memoize(300)
@dataclass_to_dict
def albums():
    with KV() as kv:
        url = kv.get("immich.url")
        token = kv.get("immich.token")

        if not url or not token:
            raise ValueError("Missing URL or token")

        response = http.get(
            url=urljoin(url, "/api/albums"),
            headers={"Authorization": f"Bearer {token}"},
        )
        response.raise_for_status()
        json_response = response.json()

        final_response = []
        for album in json_response:
            id_ = album.get("id")
            name = album.get("albumName", "")
            asset_count = album.get("assetCount", 0)
            shared = album.get("shared", False)

            thumbnail_asset_id = album.get("albumThumbnailAssetId")

            if not id_ or not thumbnail_asset_id:
                continue

            file_path = download_thumbnail(url, token, thumbnail_asset_id)
            final_response.append(Album(id=id_, file_path=file_path, name=name, asset_count=asset_count, shared=shared))

    return Albums(albums=final_response)


@crash_reporter
def upload_immich_photo(file_path: str) -> bool:
    with KV() as kv:
        url = kv.get("immich.url")
        token = kv.get("immich.token")

        if not url or not token:
            raise ValueError("Missing URL or token")

        return upload_photo(url, token, file_path, wait=True)


@memoize(300)
def get_album_assets(url: str, token: str, album_id: str) -> List[Dict]:
    response = http.get(
        url=urljoin(url, f"/api/albums/{album_id}"),
        params={"withoutAssets": "false"},
        headers={"Authorization": f"Bearer {token}"},
    )
    response.raise_for_status()
    json_response = response.json()
    return json_response.get("assets", [])


@memoize(300)
@crash_reporter
@dataclass_to_dict
def album_detail(album_id: str, bucket: Optional[str] = None) -> Optional[TimelineResponse]:
    with KV() as kv:
        url = kv.get("immich.url")
        token = kv.get("immich.token")

        if not url or not token:
            raise ValueError("Missing URL or token")

        if bucket:
            index = int(bucket)
        else:
            index = 0

        album_assets = get_album_assets(url, token, album_id)
        if not album_assets:
            return

        filtered_index_assets = album_assets[index:]
        filtered_assets = []
        first_asset_month = None
        for i, asset in enumerate(filtered_index_assets):
            asset_month = datetime.fromisoformat(asset["fileCreatedAt"][:19]).strftime("%B")
            if not first_asset_month:
                first_asset_month = asset_month
            if asset_month != first_asset_month or len(filtered_assets) >= MAX_GALLERY_PER_PAGE:
                break
            filtered_assets.append(asset)

        if len(filtered_assets) == 0 or not first_asset_month:
            return

        if index == 0:
            next_bucket = None
        elif index - MAX_GALLERY_PER_PAGE < 0:
            next_bucket = str(0)
        else:
            next_bucket = str(index - MAX_GALLERY_PER_PAGE)

        if len(filtered_assets) == len(filtered_index_assets):
            previous_bucket = None
        else:
            previous_bucket = str(index + len(filtered_assets))

        with ThreadPoolExecutor() as pool:
            futures = {}
            for i, asset in enumerate(filtered_assets):
                id_ = asset.get("id")
                if not id_:
                    continue

                duration = asset.get("duration")
                if not duration:
                    parsed_duration = None
                else:
                    only_zeros = int(duration.replace(".", "").replace(":", "")) == 0
                    if only_zeros:
                        parsed_duration = None
                    else:
                        parsed_duration = duration[3:8]

                futures[id_] = pool.submit(thumbnail, url, token, id_, parsed_duration)
                if i - 1 >= 0:
                    previous_asset_id = filtered_assets[i - 1].get("id")
                    kv.put_cached(f"album.{album_id}.photo.{id_}.previous", previous_asset_id)
                if i + 1 < len(filtered_assets):
                    next_asset_id = filtered_assets[i + 1].get("id")
                    kv.put_cached(f"album.{album_id}.photo.{id_}.next", next_asset_id)
            kv.commit_cached()

        data_structure = {}
        for asset in filtered_assets:
            id_ = asset.get("id")
            if not id_:
                continue
            future = futures.get(id_)
            if future:
                result = future.result()
                if result:
                    day = asset.get("fileCreatedAt", "")[8:10]
                    if day not in data_structure:
                        data_structure[day] = []
                    data_structure[day].append(result)

        days = []
        for k, v in data_structure.items():
            days.append(Day(date=f"{first_asset_month} {k}", images=v))

        return TimelineResponse(
            month=first_asset_month,
            days=days,
            previous=previous_bucket,
            next=next_bucket,
        )


@crash_reporter
def album_preview_video(
    url: str,
    token: str,
    image_id: str,
    file_name: str,
    favorite: bool,
    album_id: str,
) -> Preview:
    with KV() as kv:
        previous = kv.get(f"album.{album_id}.photo.{image_id}.previous")
        next_ = kv.get(f"album.{album_id}.photo.{image_id}.next")

    file_path = download_video_preview(url, token, image_id)

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
def album_preview_image(
    url: str,
    token: str,
    image_id: str,
    file_name: str,
    favorite: bool,
    album_id: str,
) -> Preview:
    with KV() as kv:
        previous = kv.get(f"album.{album_id}.photo.{image_id}.previous")
        next_ = kv.get(f"album.{album_id}.photo.{image_id}.next")

    file_path = download_photo_preview(url, token, image_id)

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
@dataclass_to_dict
def album_preview(image_id: str, album_id: str) -> Preview:
    with KV() as kv:
        url = kv.get("immich.url")
        token = kv.get("immich.token")

        if not url or not token:
            raise ValueError("Missing URL or token")

        file_name = kv.get(f"album.{album_id}.photo.{image_id}.name")
        file_type = kv.get(f"album.{album_id}.photo.{image_id}.type")
        favorite = kv.get(f"album.{album_id}.photo.{image_id}.favorite")

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

            kv.put(f"album.{album_id}.photo.{image_id}.name", file_name, ttl_seconds=300)
            kv.put(f"album.{album_id}.photo.{image_id}.type", file_type, ttl_seconds=300)
            kv.put(f"album.{album_id}.photo.{image_id}.favorite", favorite, ttl_seconds=300)

    if file_type == "VIDEO":
        return album_preview_video(url, token, image_id, file_name, favorite, album_id)

    return album_preview_image(url, token, image_id, file_name, favorite, album_id)


@crash_reporter
@dataclass_to_dict
def preview(image_id: str, type: str, album_id: str = "") -> Preview:
    if type == "timeline":
        return timeline_preview(image_id)
    elif type == "memory":
        return memory_preview(image_id)
    elif type == "album":
        return album_preview(image_id, album_id)
    else:
        raise ValueError(f"no preview for type f{type}")
