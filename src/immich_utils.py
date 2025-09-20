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

from enum import Enum

from src.constants import (
    APP_NAME,
    CRASH_REPORT_URL,
)
from src.ut_components import setup

setup(APP_NAME, CRASH_REPORT_URL)

import os
from dataclasses import dataclass
from datetime import datetime
from typing import Any, Dict, List, Optional
from urllib.parse import urljoin

import src.ut_components.http as http
from src.ut_components.config import get_cache_path
from src.ut_components.kv import KV
from src.ut_components.memoize import hash_function_args
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
    if response.status_code >= 300:
        return ""

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


def upload_photo(url: str, token: str, file_path: str) -> http.Response:
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
        return response


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


@dataclass
class Bucket:
    current: str
    next: str
    previous: str


def get_bucket(url: str, token: str, current: str, query_params: Dict[str, str] = {}) -> Bucket:
    hashed_args = hash_function_args(query_params, {})
    with KV() as kv:
        cached = kv.get(f"bucket.{hashed_args}.cached") or False
        if cached:
            if not current:
                final_current = kv.get(f"bucket.{hashed_args}.first") or ""
            else:
                final_current = current
            next_ = kv.get(f"bucket.{hashed_args}.{final_current}.next") or ""
            previous = kv.get(f"bucket.{hashed_args}.{final_current}.previous") or ""
            return Bucket(current=final_current, next=next_, previous=previous)
        else:
            response = http.get(
                url=urljoin(url, "/api/timeline/buckets"),
                headers={"Authorization": f"Bearer {token}"},
                params=query_params,
            )
            response.raise_for_status()
            json_response = response.json()
            time_buckets = [x.get("timeBucket") for x in json_response]

            for i, bucket in enumerate(time_buckets):
                if i == 0:
                    kv.put_cached(f"bucket.{hashed_args}.first", bucket, ttl_seconds=3600)
                    first = bucket
                next_ = time_buckets[i - 1] if i - 1 >= 0 else ""
                previous = time_buckets[i + 1] if i + 1 < len(time_buckets) else ""

                kv.put_cached(f"bucket.{hashed_args}.{bucket}.next", next_, ttl_seconds=3600)
                kv.put_cached(f"bucket.{hashed_args}.{bucket}.previous", previous, ttl_seconds=3600)
            kv.put_cached(f"bucket.{hashed_args}.cached", True, ttl_seconds=3600)
            kv.commit_cached()
            if not current:
                final_current = first
            else:
                final_current = current
            return get_bucket(url, token, current=final_current, query_params=query_params)


def delete_buckets():
    with KV() as kv:
        kv.delete_partial("bucket")


def parse_duration(duration: str) -> Optional[str]:
    if not duration:
        return None
    only_zeros = int(duration.replace(".", "").replace(":", "")) == 0
    if only_zeros:
        return None
    return duration[3:8]


@dataclass
class Asset:
    id: str
    duration: Optional[str]
    title: str
    created_at: str


@dataclass
class SearchResponse:
    assets: List[Asset]
    next: str
    previous: str


def metadata_search(url: str, token: str, query_params: Dict[str, Any], page: str = "") -> SearchResponse:
    if not page:
        final_page = "1"
    else:
        final_page = page

    response = http.post(
        url=urljoin(url, "/api/search/metadata"),
        headers={"Authorization": f"Bearer {token}"},
        json={"page": final_page, **query_params},
    )
    response.raise_for_status()
    json_response = response.json()
    previous_page = json_response.get("assets", {}).get("nextPage", "")
    if int(final_page) - 1 < 1:
        next_page = ""
    else:
        next_page = str(int(final_page) - 1)

    items = json_response.get("assets", {}).get("items", [])
    assets = []
    for item in items:
        assets.append(
            Asset(
                id=item.get("id", ""),
                duration=parse_duration(item.get("duration")),
                title=item.get("originalFileName", ""),
                created_at=item.get("fileCreatedAt", ""),
            )
        )
    return SearchResponse(assets=assets, next=next_page, previous=previous_page)


def smart_search(url: str, token: str, query: str, page: str = "") -> SearchResponse:
    if not page:
        final_page = "1"
    else:
        final_page = page

    response = http.post(
        url=urljoin(url, "/api/search/smart"),
        headers={"Authorization": f"Bearer {token}"},
        json={"page": final_page, "query": query},
    )
    response.raise_for_status()
    json_response = response.json()
    previous_page = json_response.get("assets", {}).get("nextPage", "")
    if int(final_page) - 1 < 1:
        next_page = ""
    else:
        next_page = str(int(final_page) - 1)

    items = json_response.get("assets", {}).get("items", [])
    assets = []
    for item in items:
        assets.append(
            Asset(
                id=item.get("id", ""),
                duration=parse_duration(item.get("duration")),
                title=item.get("originalFileName", ""),
                created_at=item.get("fileCreatedAt", ""),
            )
        )
    return SearchResponse(assets=assets, next=next_page, previous=previous_page)


class FileType(str, Enum):
    IMAGE = "IMAGE"
    VIDEO = "VIDEO"


@dataclass
class AssetInfo:
    file_path: str
    id: str
    name: str
    file_type: FileType
    favorite: bool
    archived: bool
    deleted: bool


def asset_info(image_id: str) -> AssetInfo:
    with KV() as kv:
        url = kv.get("immich.url")
        token = kv.get("immich.token")

        if not url or not token:
            raise ValueError("Missing URL or token")

        file_name = kv.get(f"asset_info.{image_id}.name")
        file_type = kv.get(f"asset_info.{image_id}.type")
        favorite = kv.get(f"asset_info.{image_id}.favorite")
        archived = kv.get(f"asset_info.{image_id}.archived")
        deleted = kv.get(f"asset_info.{image_id}.deleted")

        if not file_name or not file_type or favorite is None or archived is None or deleted is None:
            metadata_response = http.get(
                urljoin(url, f"/api/assets/{image_id}"),
                headers={"Authorization": f"Bearer {token}"},
            )
            metadata_response.raise_for_status()
            json_response = metadata_response.json()
            file_name = json_response.get("originalFileName", "")
            file_type = json_response.get("type", "IMAGE")
            favorite = json_response.get("isFavorite", False)
            archived = json_response.get("isArchived", False)
            deleted = json_response.get("isTrashed", False)

            kv.put_cached(f"asset_info.{image_id}.name", file_name, ttl_seconds=300)
            kv.put_cached(f"asset_info.{image_id}.type", file_type, ttl_seconds=300)
            kv.put_cached(f"asset_info.{image_id}.favorite", favorite, ttl_seconds=300)
            kv.put_cached(f"asset_info.{image_id}.archived", archived, ttl_seconds=300)
            kv.put_cached(f"asset_info.{image_id}.deleted", deleted, ttl_seconds=300)
            kv.commit_cached()

        if file_type == "VIDEO":
            file_type_enum = FileType.VIDEO
            file_path = download_video_preview(url, token, image_id)
        else:
            file_type_enum = FileType.IMAGE
            file_path = download_photo_preview(url, token, image_id)

        return AssetInfo(
            file_path=file_path,
            id=image_id,
            name=file_name,
            file_type=file_type_enum,
            favorite=favorite,
            archived=archived,
            deleted=deleted,
        )


def delete_asset_info():
    with KV() as kv:
        kv.delete_partial("asset_info")
