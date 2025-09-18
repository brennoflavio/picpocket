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
)
from src.ut_components import setup

setup(APP_NAME, CRASH_REPORT_URL)

import hashlib
import os
import time
from dataclasses import dataclass
from typing import List

from src.immich_utils import (
    upload_photo,
)
from src.ut_components.config import get_cache_path
from src.ut_components.crash import crash_reporter
from src.ut_components.kv import KV
from src.ut_components.notification import Notification, parse_notification


@crash_reporter
def delete_old_assets(path: str, days: int):
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
    thumbnail_folder = os.path.join(get_cache_path(), "thumbnail")
    preview_folder = os.path.join(get_cache_path(), "preview")
    original_folder = os.path.join(get_cache_path(), "original")

    delete_old_assets(thumbnail_folder, cache_days or DEFAULT_CACHE_DAYS)
    delete_old_assets(preview_folder, cache_days or DEFAULT_CACHE_DAYS)
    delete_old_assets(original_folder, cache_days or DEFAULT_CACHE_DAYS)


@dataclass
class File:
    path: str
    creation_time: int

    def hash(self):
        return hashlib.sha1(f"{self.path}.{str(self.creation_time)}".encode()).hexdigest()


def get_all_files() -> List[File]:
    paths = ["/home/phablet/Pictures", "/home/phablet/Videos"]
    files = []
    for path in paths:
        for root, _, filenames in os.walk(path):
            for filename in filenames:
                file_path = os.path.join(root, filename)
                creation_time = os.stat(file_path).st_ctime
                files.append(File(path=file_path, creation_time=int(creation_time)))
    return files


def upload_files():
    total_uploaded = 0
    with KV() as kv:
        url = kv.get("immich.url")
        token = kv.get("immich.token")

        if not url or not token:
            raise ValueError("Missing URL or token")

        files = get_all_files()
        for file in files:
            uploaded = kv.get(f"background_job.{file.hash()}.uploaded")
            if uploaded:
                continue
            success = upload_photo(url, token, file.path)
            if success:
                total_uploaded += 1
                kv.put(f"background_job.{file.hash()}.uploaded", True)
    return total_uploaded


@crash_reporter
def sync_library(raw_notification: str) -> str:
    return raw_notification
    parsed = parse_notification(raw_notification)
    if parsed.summary != "Cron Job":
        return raw_notification

    uploaded = upload_files()
    if uploaded:
        # delete_memoized(timeline)
        notification = Notification(
            icon="stock_image",
            summary="Sync completed successfully",
            body=f"Uploaded {uploaded} photos and videos to remote server.",
            popup=False,
            persist=True,
            vibrate=False,
            sound=False,
        )
        return notification.dump()
    return ""
