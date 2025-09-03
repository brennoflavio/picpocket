import json
from dataclasses import dataclass


@dataclass
class Notification:
    icon: str
    summary: str
    body: str
    popup: bool
    persist: bool
    vibrate: bool
    sound: bool

    def dump(self) -> str:
        return json.dumps(
            {
                "notification": {
                    "card": {
                        "icon": self.icon,
                        "summary": self.summary,
                        "body": self.body,
                        "popup": self.popup,
                        "persist": self.persist,
                    },
                    "vibrate": self.vibrate,
                    "sound": self.sound,
                }
            }
        )


def parse_notification(raw_notification: str) -> Notification:
    data = json.loads(raw_notification)
    notification = data.get("notification", {})
    card = notification.get("card", {})
    return Notification(
        icon=card.get("icon", "notification"),
        summary=card.get("summary", ""),
        body=card.get("body", ""),
        popup=card.get("popup", False),
        persist=card.get("persist", False),
        vibrate=notification.get("vibrate", False),
        sound=notification.get("sound", False),
    )
