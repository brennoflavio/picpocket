from src.constants import (
    APP_NAME,
    CRASH_REPORT_URL,
)
from src.lib import setup

setup(APP_NAME, CRASH_REPORT_URL)

import hashlib
import os
from dataclasses import dataclass
from typing import List

from src.immich_client import timeline, upload_photo
from src.lib.crash import crash_reporter
from src.lib.kv import KV
from src.lib.memoize import delete_memoized
from src.lib.notification import Notification, parse_notification


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
        files = get_all_files()
        for file in files:
            uploaded = kv.get(f"background_job.{file.hash()}.uploaded")
            if uploaded:
                continue
            success = upload_photo(file.path)
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
        delete_memoized(timeline)
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
