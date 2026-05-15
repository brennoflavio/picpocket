"""
Copyright (C) 2025  Brenno Flávio de Almeida

This program is free software: you can redistribute it and/or modify
it under the terms of the GNU General Public License as published by
the Free Software Foundation; version 3.

ut-components is distributed in the hope that it will be useful,
but WITHOUT ANY WARRANTY; without even the implied warranty of
MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
GNU General Public License for more details.

You should have received a copy of the GNU General Public License
along with this program.  If not, see <http://www.gnu.org/licenses/>.
"""

import json
from dataclasses import dataclass, field
from datetime import datetime, timedelta
from typing import Any, Dict, List, Optional, Union

from . import http


@dataclass
class Vibrate:
    pattern: List[int]
    repeat: int = 1


@dataclass
class EmblemCounter:
    count: int
    visible: bool


NotificationSound = Union[bool, str]
NotificationVibrate = Union[bool, Vibrate]


@dataclass
class Notification:
    """
    Represents a push notification for Ubuntu Touch applications.

    This dataclass encapsulates all properties needed to create and send
    push notifications through the Ubuntu Push Notification Service.
    It provides methods for serialization to the required format.
    """

    icon: str
    summary: str
    body: str
    popup: bool
    persist: bool
    vibrate: NotificationVibrate
    sound: NotificationSound
    actions: List[str] = field(default_factory=list)
    timestamp: Optional[int] = None
    tag: str = ""
    emblem_counter: Optional[EmblemCounter] = None

    def dict(self) -> Dict[str, Any]:
        card = {
            "icon": self.icon,
            "summary": self.summary,
            "body": self.body,
            "popup": self.popup,
            "persist": self.persist,
        }
        if self.actions:
            card["actions"] = list(self.actions)
        if self.timestamp is not None:
            card["timestamp"] = self.timestamp

        notification = {
            "card": card,
            "vibrate": _serialize_vibrate(self.vibrate),
            "sound": self.sound,
        }
        if self.tag:
            notification["tag"] = self.tag
        if self.emblem_counter is not None:
            notification["emblem-counter"] = _serialize_emblem_counter(self.emblem_counter)

        return {"notification": notification}

    def dump(self) -> str:
        return json.dumps(self.dict())


def _serialize_vibrate(vibrate: NotificationVibrate) -> Union[bool, Dict[str, Any]]:
    if isinstance(vibrate, Vibrate):
        return {
            "pattern": list(vibrate.pattern),
            "repeat": vibrate.repeat,
        }
    return vibrate


def _serialize_emblem_counter(emblem_counter: EmblemCounter) -> Dict[str, Any]:
    return {
        "count": emblem_counter.count,
        "visible": emblem_counter.visible,
    }


def _parse_vibrate(value: Any) -> NotificationVibrate:
    if isinstance(value, dict):
        pattern = value.get("pattern")
        repeat = value.get("repeat", 1)
        if isinstance(pattern, list):
            parsed_pattern = [item for item in pattern if isinstance(item, int) and not isinstance(item, bool)]
            parsed_repeat = repeat if isinstance(repeat, int) and not isinstance(repeat, bool) else 1
            return Vibrate(pattern=parsed_pattern, repeat=parsed_repeat)
    if isinstance(value, bool):
        return value
    return False


def _parse_emblem_counter(value: Any) -> Optional[EmblemCounter]:
    if not isinstance(value, dict):
        return None

    count = value.get("count", 0)
    if not isinstance(count, int) or isinstance(count, bool):
        count = 0

    visible = value.get("visible", False)
    if not isinstance(visible, bool):
        visible = False

    return EmblemCounter(
        count=count,
        visible=visible,
    )


def parse_notification(raw_notification: str) -> Notification:
    """
    Parse a JSON string into a Notification object.

    Deserializes a JSON-formatted push notification string (typically received
    from the Ubuntu Push Notification Service) into a Notification dataclass
    instance. Provides sensible defaults for any missing fields.
    """
    data = json.loads(raw_notification)
    notification = data.get("notification", {})
    card = notification.get("card", {})

    actions = card.get("actions", [])
    if not isinstance(actions, list):
        actions = []
    actions = [action for action in actions if isinstance(action, str)]

    timestamp = card.get("timestamp")
    if not isinstance(timestamp, int) or isinstance(timestamp, bool):
        timestamp = None

    sound = notification.get("sound", False)
    if not isinstance(sound, (bool, str)):
        sound = False

    return Notification(
        icon=card.get("icon", "notification"),
        summary=card.get("summary", ""),
        body=card.get("body", ""),
        popup=card.get("popup", False),
        persist=card.get("persist", False),
        vibrate=_parse_vibrate(notification.get("vibrate", False)),
        sound=sound,
        actions=actions,
        timestamp=timestamp,
        tag=str(notification.get("tag", "") or ""),
        emblem_counter=_parse_emblem_counter(notification.get("emblem-counter")),
    )


def send_notification(notification: Notification, token: str, appid: str):
    """
    Send a push notification through the Ubuntu Push Notification Service.

    Transmits a notification to a specific device using the Ubuntu Push
    infrastructure. The notification will be delivered to the device
    identified by the provided token, for the specified application.
    The notification expires after 10 minutes if not delivered.

    Args:
        notification (Notification): The notification object containing all
            the message details, formatting, and behavior settings.
        token (str): The unique push token identifying the target device.
            This token is obtained during the app's push registration process.
        appid (str): The application identifier in the format "appname_version"
            or as registered with the Ubuntu Push service.

    Raises:
        requests.exceptions.HTTPError: If the push service returns an error
            status code (4xx or 5xx).
        requests.exceptions.RequestException: For network-related errors
            during the API call.

    Example:
        >>> from src.ut_components.notification import Notification, send_notification
        >>>
        >>> # Create and send a notification
        >>> notification = Notification(
        ...     icon="alarm-clock",
        ...     summary="Reminder",
        ...     body="Your meeting starts in 5 minutes",
        ...     popup=True,
        ...     persist=False,
        ...     vibrate=True,
        ...     sound=True
        ... )
        >>>
        >>> # Send to a specific device
        >>> send_notification(
        ...     notification=notification,
        ...     token="abc123def456",  # Device push token
        ...     appid="myapp.developer_1.0"
        ... )
    """
    url = "https://push.ubports.com/notify"
    expire_at = datetime.utcnow() + timedelta(minutes=10)
    data = {
        "appid": appid,
        "expire_on": expire_at.isoformat() + "Z",
        "token": token,
        "data": notification.dict(),
    }
    response = http.post(url, json=data)
    response.raise_for_status()
