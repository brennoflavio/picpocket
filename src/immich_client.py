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
)
from src.ut_components import setup

setup(APP_NAME, CRASH_REPORT_URL)

import hashlib
import os
import shutil
from concurrent.futures import ThreadPoolExecutor
from dataclasses import dataclass
from datetime import datetime
from typing import Dict, List, Optional
from urllib.parse import urljoin

import src.ut_components.http as http
from src.immich_utils import (
    asset_info,
    delete_asset_info,
    delete_buckets,
    download_original,
    download_people_thumbnail,
    download_thumbnail,
    get_bucket,
    metadata_search,
    parse_duration,
    smart_search,
    upload_photo,
)
from src.ut_components.config import get_cache_path
from src.ut_components.crash import crash_reporter, get_crash_report, set_crash_report
from src.ut_components.kv import KV
from src.ut_components.memoize import delete_memoized, memoize
from src.ut_components.utils import dataclass_to_dict


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
    title: str


@crash_reporter
def thumbnail(url: str, token: str, image_id: str, duration: Optional[str], title: str) -> Optional[Image]:
    file_path = download_thumbnail(url, token, image_id)
    if file_path:
        return Image(filePath=file_path, id=image_id, duration=duration, title=title)


@dataclass
class TimelineResponse:
    title: str
    images: List[Image]
    previous: str
    next: str


@memoize(300)
@crash_reporter
@dataclass_to_dict
def base_timeline(prefix: str, bucket: str = "", query_args: Dict[str, str] = {}) -> TimelineResponse:
    with KV() as kv:
        url = kv.get("immich.url")
        token = kv.get("immich.token")

        if not url or not token:
            raise ValueError("Missing URL or token")

        bucket_obj = get_bucket(url, token, bucket, query_args)

        response = http.get(
            url=urljoin(url, "/api/timeline/bucket"),
            headers={"Authorization": f"Bearer {token}"},
            params={"timeBucket": bucket_obj.current, **query_args},
        )
        response.raise_for_status()
        json_response = response.json()

        ids = json_response.get("id", [])
        created_ats = [x.split(".")[0] for x in json_response.get("fileCreatedAt", [])]
        days = [x[8:10] for x in json_response.get("fileCreatedAt", [])]
        durations = json_response.get("duration", [])

        with ThreadPoolExecutor() as pool:
            futures = []
            for i, id_ in enumerate(ids):
                duration = durations[i][3:8] if durations[i] else None
                if days[i]:
                    title = datetime.fromisoformat(created_ats[i]).strftime("%B, %d, %Y")
                else:
                    title = ""
                futures.append(pool.submit(thumbnail, url, token, id_, duration, title))
                if i - 1 >= 0:
                    kv.put_cached(f"{prefix}.{id_}.previous", ids[i - 1])
                if i + 1 < len(ids):
                    kv.put_cached(f"{prefix}.{id_}.next", ids[i + 1])
            kv.commit_cached()

            images = []
            for future in futures:
                result = future.result()
                if result:
                    images.append(result)

        title = datetime.fromisoformat(bucket_obj.current).strftime("%B, %Y")
        return TimelineResponse(
            title=title,
            images=images,
            previous=bucket_obj.previous,
            next=bucket_obj.next,
        )


def timeline(bucket: str = "") -> TimelineResponse:
    return base_timeline("timeline", bucket, query_args={"visibility": "timeline"})


@dataclass
class Preview:
    filePath: str
    id: str
    name: str
    file_type: str
    previous: Optional[str]
    next: Optional[str]
    favorite: bool
    archived: bool
    deleted: bool


@crash_reporter
@dataclass_to_dict
def timeline_preview(image_id: str) -> Preview:
    asset_info_data = asset_info(image_id)
    with KV() as kv:
        previous = kv.get(f"timeline.{image_id}.previous")
        next_ = kv.get(f"timeline.{image_id}.next")

        return Preview(
            filePath=asset_info_data.file_path,
            id=image_id,
            name=asset_info_data.name,
            file_type=asset_info_data.file_type,
            previous=previous,
            next=next_,
            favorite=asset_info_data.favorite,
            archived=asset_info_data.archived,
            deleted=asset_info_data.deleted,
        )


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
        kv.delete_partial("favorite")
        delete_memoized(base_timeline)


@crash_reporter
def archive(*image_ids: str):
    with KV() as kv:
        url = kv.get("immich.url")
        token = kv.get("immich.token")

        if not url or not token:
            raise ValueError("Missing URL or token")

        response = http.put(
            url=urljoin(url, "/api/assets"),
            json={"ids": list(image_ids), "visibility": "archive"},
            headers={"Authorization": f"Bearer {token}"},
        )
        response.raise_for_status()
    delete_memoized(base_timeline)


@crash_reporter
def delete(*image_ids: str):
    with KV() as kv:
        url = kv.get("immich.url")
        token = kv.get("immich.token")

        if not url or not token:
            raise ValueError("Missing URL or token")

        response = http.delete(
            url=urljoin(url, "/api/assets"),
            json={"ids": list(image_ids)},
            headers={"Authorization": f"Bearer {token}"},
        )
        response.raise_for_status()
    delete_memoized(base_timeline)


def delete_cache():
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
    clear_cache()


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
        kv.delete_partial("memoize")
        kv.delete_partial("favorite")
        kv.delete_partial("archived")
        kv.delete_partial("deleted")
        kv.delete_partial("person")
    delete_buckets()
    delete_asset_info()
    delete_memoized(base_timeline)


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
                    kv.put_cached(f"memory.{asset_id}.previous", assets[i - 1]["id"])
                if i + 1 < len(assets):
                    kv.put_cached(f"memory.{asset_id}.next", assets[i + 1]["id"])
            kv.commit_cached()

        return MemoryContainer(memories=memories)


@crash_reporter
@dataclass_to_dict
def memory_preview(image_id: str) -> Preview:
    asset_info_data = asset_info(image_id)
    with KV() as kv:
        previous = kv.get(f"memory.{image_id}.previous")
        next_ = kv.get(f"memory.{image_id}.next")

        return Preview(
            filePath=asset_info_data.file_path,
            id=image_id,
            name=asset_info_data.name,
            file_type=asset_info_data.file_type,
            previous=previous,
            next=next_,
            favorite=asset_info_data.favorite,
            archived=asset_info_data.archived,
            deleted=asset_info_data.deleted,
        )


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
@dataclass_to_dict
def upload_immich_photo(file_paths: List[str]) -> ImmichResponse:
    with KV() as kv:
        url = kv.get("immich.url")
        token = kv.get("immich.token")

        if not url or not token:
            raise ValueError("Missing URL or token")

        success_count = 0
        error_count = 0
        for path in file_paths:
            response = upload_photo(url, token, path)
            if response.success:
                success_count += 1
            else:
                error_count += 1
        success = not bool(error_count)
        message = f"Uploaded {success_count} photos with {error_count} errors"
        return ImmichResponse(success=success, message=message)


@memoize(300)
@crash_reporter
@dataclass_to_dict
def album_detail(album_id: str) -> TimelineResponse:
    with KV() as kv:
        url = kv.get("immich.url")
        token = kv.get("immich.token")

        if not url or not token:
            raise ValueError("Missing URL or token")

        response = http.get(
            url=urljoin(url, f"/api/albums/{album_id}"),
            params={"withoutAssets": "false"},
            headers={"Authorization": f"Bearer {token}"},
        )
        response.raise_for_status()
        json_response = response.json()
        assets = json_response.get("assets", [])
        ids = [x.get("id") for x in assets if x.get("id")]

        with ThreadPoolExecutor() as pool:
            futures = []
            for i, asset in enumerate(assets):
                id_ = asset.get("id")
                if not id_:
                    continue

                parsed_duration = parse_duration(asset.get("duration"))

                created_at = asset.get("fileCreatedAt", "").split(".")[0]
                if created_at:
                    title = datetime.fromisoformat(created_at).strftime("%B, %d, %Y")
                else:
                    title = ""

                futures.append(pool.submit(thumbnail, url, token, id_, parsed_duration, title))
                if i - 1 >= 0:
                    kv.put_cached(f"album.{album_id}.{id_}.previous", ids[i - 1])
                if i + 1 < len(ids):
                    kv.put_cached(f"album.{album_id}.{id_}.next", ids[i + 1])
            kv.commit_cached()

            images = []
            for future in futures:
                result = future.result()
                if result:
                    images.append(result)

        if len(images) > 0:
            title = images[0].title
        else:
            title = ""
        return TimelineResponse(
            title=title,
            images=images,
            previous="",
            next="",
        )


@crash_reporter
@dataclass_to_dict
def album_preview(image_id: str, album_id: str) -> Preview:
    asset_info_data = asset_info(image_id)
    with KV() as kv:
        previous = kv.get(f"album.{album_id}.{image_id}.previous")
        next_ = kv.get(f"album.{album_id}.{image_id}.next")

        return Preview(
            filePath=asset_info_data.file_path,
            id=image_id,
            name=asset_info_data.name,
            file_type=asset_info_data.file_type,
            previous=previous,
            next=next_,
            favorite=asset_info_data.favorite,
            archived=asset_info_data.archived,
            deleted=asset_info_data.deleted,
        )


@crash_reporter
@dataclass_to_dict
def preview(
    image_id: str, type: str, album_id: str = "", person_id: str = "", city: str = "", query: str = ""
) -> Preview:
    if type == "timeline":
        return timeline_preview(image_id)
    elif type == "memory":
        return memory_preview(image_id)
    elif type == "album":
        return album_preview(image_id, album_id)
    elif type == "person":
        return person_preview(image_id, person_id)
    elif type == "location":
        return location_preview(image_id, city)
    elif type == "favorite":
        return favorite_preview(image_id)
    elif type == "archived":
        return archived_preview(image_id)
    elif type == "deleted":
        return deleted_preview(image_id)
    elif type == "search":
        return search_preview(image_id, query)
    else:
        raise ValueError(f"no preview for type {type}")


@dataclass
class People:
    id: str
    name: str
    face_path: str


@dataclass
class PeopleResponse:
    people: List[People]


@crash_reporter
@memoize(3600)
@dataclass_to_dict
def people() -> PeopleResponse:
    with KV() as kv:
        url = kv.get("immich.url")
        token = kv.get("immich.token")

        if not url or not token:
            raise ValueError("Missing URL or token")

        response = http.get(
            url=urljoin(url, "/api/people"),
            headers={"Authorization": f"Bearer {token}"},
        )
        response.raise_for_status()
        json_response = response.json()
        people = json_response.get("people", [])

        with ThreadPoolExecutor() as pool:
            futures = []
            final_response = []
            for person in people:
                id_ = person.get("id")
                name = person.get("name", "")

                if not id_:
                    continue

                futures.append((id_, name, pool.submit(download_people_thumbnail, url, token, id_)))

            for id_, name, future in futures:
                file_path = future.result()
                final_response.append(People(id=id_, name=name, face_path=file_path))
    return PeopleResponse(people=final_response)


def person_timeline(person_id: str, bucket: str = "") -> TimelineResponse:
    return base_timeline(f"person.{person_id}", bucket, {"personId": person_id, "visibility": "timeline"})


@crash_reporter
@dataclass_to_dict
def person_preview(image_id: str, person_id: str) -> Preview:
    asset_info_data = asset_info(image_id)
    with KV() as kv:
        previous = kv.get(f"person.{person_id}.{image_id}.previous")
        next_ = kv.get(f"person.{person_id}.{image_id}.next")

        return Preview(
            filePath=asset_info_data.file_path,
            id=image_id,
            name=asset_info_data.name,
            file_type=asset_info_data.file_type,
            previous=previous,
            next=next_,
            favorite=asset_info_data.favorite,
            archived=asset_info_data.archived,
            deleted=asset_info_data.deleted,
        )


@dataclass
class Location:
    id: str
    title: str
    subtitle: str
    thumbnail_path: str


@dataclass
class LocationResponse:
    locations: List[Location]


@crash_reporter
@memoize(3600)
@dataclass_to_dict
def locations() -> LocationResponse:
    with KV() as kv:
        url = kv.get("immich.url")
        token = kv.get("immich.token")

        if not url or not token:
            raise ValueError("Missing URL or token")

        response = http.get(
            url=urljoin(url, "/api/search/cities"),
            headers={"Authorization": f"Bearer {token}"},
        )
        response.raise_for_status()
        json_response = response.json()
        locations = json_response

        with ThreadPoolExecutor() as pool:
            futures = []
            final_response = []
            for location in locations:
                id_ = location.get("exifInfo", {}).get("city")

                if not id_:
                    continue

                city = location.get("exifInfo", {}).get("city")
                state = location.get("exifInfo", {}).get("state")
                country = location.get("exifInfo", {}).get("country")
                asset_id = location.get("id")

                futures.append((id_, city, state, country, pool.submit(download_thumbnail, url, token, asset_id)))

            for id_, city, state, country, future in futures:
                file_path = future.result()
                subtitle = ""
                if state:
                    subtitle = state
                if country:
                    subtitle = f"{subtitle}, {country}"
                final_response.append(Location(id=id_, title=city, subtitle=subtitle, thumbnail_path=file_path))
    return LocationResponse(locations=final_response)


@memoize(300)
@crash_reporter
@dataclass_to_dict
def location_detail(city: str, bucket: str = "") -> TimelineResponse:
    with KV() as kv:
        url = kv.get("immich.url")
        token = kv.get("immich.token")

        if not url or not token:
            raise ValueError("Missing URL or token")

        search_response = metadata_search(url, token, {"city": city}, bucket)
        ids = [asset.id for asset in search_response.assets]

        with ThreadPoolExecutor() as pool:
            futures = []
            for i, asset in enumerate(search_response.assets):
                id_ = asset.id

                created_at = asset.created_at.split(".")[0]
                if created_at:
                    title = datetime.fromisoformat(created_at).strftime("%B, %d, %Y")
                else:
                    title = ""

                futures.append(pool.submit(thumbnail, url, token, id_, asset.duration, title))
                if i - 1 >= 0:
                    kv.put_cached(f"location.{city}.{id_}.previous", ids[i - 1])
                if i + 1 < len(ids):
                    kv.put_cached(f"location.{city}.{id_}.next", ids[i + 1])
            kv.commit_cached()

            images = []
            for future in futures:
                result = future.result()
                if result:
                    images.append(result)

        if len(images) > 0:
            title = images[0].title
        else:
            title = ""
        return TimelineResponse(
            title=title,
            images=images,
            previous=search_response.previous,
            next=search_response.next,
        )


@crash_reporter
@dataclass_to_dict
def location_preview(image_id: str, city: str) -> Preview:
    asset_info_data = asset_info(image_id)
    with KV() as kv:
        previous = kv.get(f"location.{city}.{image_id}.previous")
        next_ = kv.get(f"location.{city}.{image_id}.next")

        return Preview(
            filePath=asset_info_data.file_path,
            id=image_id,
            name=asset_info_data.name,
            file_type=asset_info_data.file_type,
            previous=previous,
            next=next_,
            favorite=asset_info_data.favorite,
            archived=asset_info_data.archived,
            deleted=asset_info_data.deleted,
        )


def favorite_timeline(bucket: str = "") -> TimelineResponse:
    return base_timeline("favorite", bucket, {"isFavorite": "true", "visibility": "timeline"})


@crash_reporter
@dataclass_to_dict
def favorite_preview(image_id: str) -> Preview:
    asset_info_data = asset_info(image_id)
    with KV() as kv:
        previous = kv.get(f"favorite.{image_id}.previous")
        next_ = kv.get(f"favorite.{image_id}.next")

        return Preview(
            filePath=asset_info_data.file_path,
            id=image_id,
            name=asset_info_data.name,
            file_type=asset_info_data.file_type,
            previous=previous,
            next=next_,
            favorite=asset_info_data.favorite,
            archived=asset_info_data.archived,
            deleted=asset_info_data.deleted,
        )


def archived_timeline(bucket: str = "") -> TimelineResponse:
    return base_timeline("archived", bucket, {"visibility": "archive"})


@crash_reporter
@dataclass_to_dict
def archived_preview(image_id: str) -> Preview:
    asset_info_data = asset_info(image_id)
    with KV() as kv:
        previous = kv.get(f"archived.{image_id}.previous")
        next_ = kv.get(f"archived.{image_id}.next")

        return Preview(
            filePath=asset_info_data.file_path,
            id=image_id,
            name=asset_info_data.name,
            file_type=asset_info_data.file_type,
            previous=previous,
            next=next_,
            favorite=asset_info_data.favorite,
            archived=asset_info_data.archived,
            deleted=asset_info_data.deleted,
        )


@crash_reporter
def unarchive(*image_ids: str):
    with KV() as kv:
        url = kv.get("immich.url")
        token = kv.get("immich.token")

        if not url or not token:
            raise ValueError("Missing URL or token")

        response = http.put(
            url=urljoin(url, "/api/assets"),
            json={"ids": list(image_ids), "visibility": "timeline"},
            headers={"Authorization": f"Bearer {token}"},
        )
        response.raise_for_status()
        kv.delete_partial("archived")
    delete_memoized(base_timeline)


def deleted_timeline(bucket: str = "") -> TimelineResponse:
    return base_timeline("deleted", bucket, {"isTrashed": "true"})


@crash_reporter
@dataclass_to_dict
def deleted_preview(image_id: str) -> Preview:
    asset_info_data = asset_info(image_id)
    with KV() as kv:
        previous = kv.get(f"deleted.{image_id}.previous")
        next_ = kv.get(f"deleted.{image_id}.next")

        return Preview(
            filePath=asset_info_data.file_path,
            id=image_id,
            name=asset_info_data.name,
            file_type=asset_info_data.file_type,
            previous=previous,
            next=next_,
            favorite=asset_info_data.favorite,
            archived=asset_info_data.archived,
            deleted=asset_info_data.deleted,
        )


@crash_reporter
def undelete(*image_ids: str):
    with KV() as kv:
        url = kv.get("immich.url")
        token = kv.get("immich.token")

        if not url or not token:
            raise ValueError("Missing URL or token")

        response = http.post(
            url=urljoin(url, "/api/trash/restore/assets"),
            json={"ids": list(image_ids)},
            headers={"Authorization": f"Bearer {token}"},
        )
        response.raise_for_status()
        kv.delete_partial("deleted")
    delete_memoized(base_timeline)


@crash_reporter
def permanently_delete(*image_ids: str):
    with KV() as kv:
        url = kv.get("immich.url")
        token = kv.get("immich.token")

        if not url or not token:
            raise ValueError("Missing URL or token")

        response = http.delete(
            url=urljoin(url, "/api/assets"),
            json={"force": "true", "ids": list(image_ids)},
            headers={"Authorization": f"Bearer {token}"},
        )
        response.raise_for_status()
        kv.delete_partial("deleted")
    delete_memoized(base_timeline)


@crash_reporter
@memoize(300)
@dataclass_to_dict
def search(query: str, bucket: str) -> TimelineResponse:
    with KV() as kv:
        url = kv.get("immich.url")
        token = kv.get("immich.token")

        if not url or not token:
            raise ValueError("Missing URL or token")

        search_response = smart_search(url, token, query, bucket)
        ids = [asset.id for asset in search_response.assets]
        query_hash = hashlib.sha1(query.encode()).hexdigest()

        with ThreadPoolExecutor() as pool:
            futures = []
            for i, asset in enumerate(search_response.assets):
                id_ = asset.id

                created_at = asset.created_at.split(".")[0]
                if created_at:
                    title = datetime.fromisoformat(created_at).strftime("%B, %d, %Y")
                else:
                    title = ""

                futures.append(pool.submit(thumbnail, url, token, id_, asset.duration, title))
                if i - 1 >= 0:
                    kv.put_cached(f"search.{query_hash}.{id_}.previous", ids[i - 1])
                if i + 1 < len(ids):
                    kv.put_cached(f"search.{query_hash}.{id_}.next", ids[i + 1])
            kv.commit_cached()

            images = []
            for future in futures:
                result = future.result()
                if result:
                    images.append(result)

        if len(images) > 0:
            title = images[0].title
        else:
            title = ""
        return TimelineResponse(
            title=title,
            images=images,
            previous=search_response.previous,
            next=search_response.next,
        )


@crash_reporter
@dataclass_to_dict
def search_preview(image_id: str, query: str) -> Preview:
    asset_info_data = asset_info(image_id)
    with KV() as kv:
        query_hash = hashlib.sha1(query.encode()).hexdigest()
        previous = kv.get(f"search.{query_hash}.{image_id}.previous")
        next_ = kv.get(f"search.{query_hash}.{image_id}.next")

        return Preview(
            filePath=asset_info_data.file_path,
            id=image_id,
            name=asset_info_data.name,
            file_type=asset_info_data.file_type,
            previous=previous,
            next=next_,
            favorite=asset_info_data.favorite,
            archived=asset_info_data.archived,
            deleted=asset_info_data.deleted,
        )
