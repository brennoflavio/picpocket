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

import heapq
import threading
import time
import traceback
import warnings
from abc import ABC, abstractmethod
from dataclasses import asdict, dataclass, is_dataclass
from datetime import datetime, timedelta
from math import ceil
from typing import Dict, List, Optional, Tuple, Union

import pyotherside

from .utils import enum_to_str

EVENT_DISPATCHER = None


class Event(ABC):
    """
    Abstract base class for defining events that can be scheduled and executed.

    Events are the fundamental units of work in the EventDispatcher system.
    Subclass this to create custom events with specific behavior. Each event
    has a unique identifier and can optionally be configured to run at regular
    intervals.

    When an event is triggered, its result (if any) is automatically sent to
    the QML layer via pyotherside using the event's ID as the signal name.

    Attributes:
        id (str): Unique identifier for the event. Used to register, schedule,
            and identify the event in QML signal handlers.
        execution_interval (Optional[timedelta]): If set, the event will be
            automatically re-scheduled at this interval by the dispatcher.
        next_execution_date (Optional[datetime]): Internal tracking for when
            the event should next be automatically enqueued.

    Example:
        >>> from datetime import timedelta
        >>> from src.python.event import Event, EventDispatcher
        >>>
        >>> class RefreshDataEvent(Event):
        ...     def __init__(self):
        ...         super().__init__(
        ...             id="refresh_data",
        ...             execution_interval=timedelta(minutes=5)
        ...         )
        ...
        ...     def trigger(self, metadata):
        ...         data = fetch_latest_data()
        ...         return {"items": data, "timestamp": time.time()}
        >>>
        >>> class SendNotificationEvent(Event):
        ...     def __init__(self):
        ...         super().__init__(
        ...             id="send_notification",
        ...             execution_interval=None  # Manual trigger only
        ...         )
        ...
        ...     def trigger(self, metadata):
        ...         title = metadata.get("title", "Notification")
        ...         body = metadata.get("body", "")
        ...         send_system_notification(title, body)
        ...         return {"success": True}
    """

    def __init__(self, id: str, execution_interval: Optional[timedelta] = None) -> None:
        """
        Initialize a new Event instance.

        Args:
            id (str): Unique identifier for this event. This ID is used to:
                - Register and reference the event in the dispatcher
                - Send results to QML via pyotherside.send(id, result)
                - Set up signal handlers in QML (e.g., setHandler("refresh_data", callback))
            execution_interval (timedelta): Time interval between automatic
                executions. Set to None for events that should only be
                triggered manually via schedule().

        Example:
            >>> from datetime import timedelta
            >>>
            >>> class HeartbeatEvent(Event):
            ...     def __init__(self):
            ...         super().__init__(
            ...             id="heartbeat",
            ...             execution_interval=timedelta(seconds=30)
            ...         )
            ...
            ...     def trigger(self, metadata):
            ...         return {"status": "alive", "uptime": get_uptime()}
        """
        self.id: str = id
        self.execution_interval: Optional[timedelta] = execution_interval
        self.next_execution_date: Optional[datetime] = None

    @abstractmethod
    def trigger(self, metadata: Optional[Dict]) -> Union[object, Dict, None]:
        """
        Execute the event's action and optionally return a result.

        This method is called by the EventDispatcher when the event is due
        for execution. Implement this method in your subclass to define
        the event's behavior.

        Args:
            metadata (Optional[Dict]): Arbitrary data passed when the event
                was scheduled. Can be used to customize event behavior on
                a per-invocation basis. Will be None if no metadata was
                provided during scheduling.

        Returns:
            object | Dict | None: The result of the event execution.
                - If a dataclass is returned, it will be converted to a dict
                  and enum values will be converted to strings.
                - If a dict is returned, it will be sent as-is.
                - If None is returned, no signal will be sent to QML.
                The result is sent to QML via pyotherside.send(event_id, result).

        Example:
            >>> class FetchUserEvent(Event):
            ...     def __init__(self):
            ...         super().__init__("fetch_user", None)
            ...
            ...     def trigger(self, metadata):
            ...         user_id = metadata.get("user_id") if metadata else None
            ...         if not user_id:
            ...             return {"error": "user_id required"}
            ...         user = database.get_user(user_id)
            ...         return {"user": user.to_dict()}
            >>>
            >>> # In QML, handle the result:
            >>> # Python.setHandler("fetch_user", function(result) {
            >>> #     if (result.error) console.log(result.error)
            >>> #     else updateUserDisplay(result.user)
            >>> # })
        """
        raise NotImplementedError


class ErrorEvent(Event):
    def trigger(self, metadata: Dict) -> Dict:
        return metadata


@dataclass
class QueuedEvent:
    """
    Internal dataclass representing an event waiting in the execution queue.

    This is used internally by EventDispatcher to track scheduled events
    along with their associated metadata. You typically don't need to
    interact with this class directly.

    Attributes:
        event (Event): The Event instance to be executed.
        metadata (Optional[Dict]): Data to pass to the event's trigger method.
    """

    event: Event
    metadata: Optional[Dict]


class EventDispatcher:
    """
    A priority queue-based event scheduler and executor for Python/QML applications.

    The EventDispatcher manages the lifecycle of events: registration, scheduling,
    and execution. It uses a min-heap priority queue to efficiently process events
    in chronological order, supporting both one-time and recurring events.

    Events can be triggered in two ways:
    1. Automatically: Events with an execution_interval are re-scheduled
       automatically after each execution.
    2. Manually: Any registered event can be scheduled on-demand with
       optional metadata and delay.

    Results from event execution are sent to the QML layer via pyotherside,
    allowing seamless Python-to-QML communication.

    Features:
        - Priority queue for efficient chronological event processing
        - Support for recurring events with configurable intervals
        - Manual event scheduling with optional delays
        - Metadata support for passing data to event handlers
        - Automatic dataclass-to-dict conversion for QML compatibility
        - Exception handling to prevent individual event failures from
          crashing the dispatcher
        - Background thread execution with start() and stop() methods

    Note:
        Do not instantiate EventDispatcher directly. Use the
        get_event_dispatcher() function to obtain the global singleton
        instance. This ensures all parts of your application share the
        same dispatcher and event registry.

    Example:
        Python module (event_page.py):
        >>> from python import setup
        >>> setup("example")
        >>> from python.event import Event, get_event_dispatcher
        >>> from datetime import datetime, timedelta
        >>> from dataclasses import dataclass
        >>>
        >>> @dataclass
        >>> class FetchTimeResponse:
        ...     time: str
        >>>
        >>> class FetchTime(Event):
        ...     def trigger(self, metadata=None):
        ...         return FetchTimeResponse(time=datetime.now().isoformat())
        >>>
        >>> get_event_dispatcher().register_event(
        ...     FetchTime(id="fetch-time", execution_interval=timedelta(seconds=5))
        ... )
        >>>
        >>> def start_loop():
        ...     get_event_dispatcher().start()
        >>>
        >>> def stop_loop():
        ...     get_event_dispatcher().stop()

    QML Integration (EventPage.qml):
        >>>  Python {
        >>>      id: python
        >>>
        >>>      Component.onCompleted: {
        >>>          addImportPath(Qt.resolvedUrl('.'));
        >>>          importModule('event_page', function() {
        >>>              setHandler('fetch-time', function(result) {
        >>>                  timeLabel.text = "Current time is: " + result.time
        >>>              })
        >>>              call('event_page.start_loop', [], function() {});
        >>>          });
        >>>      }
        >>>
        >>>      Component.onDestruction: {
        >>>          call('event_page.stop_loop', [], function() {});
        >>>      }
        >>>  }
    """

    def __init__(self) -> None:
        """
        Initialize a new EventDispatcher instance.

        Note:
            Do not instantiate EventDispatcher directly. Use the
            get_event_dispatcher() function to obtain the global singleton
            instance instead.

        Example:
            >>> from python.event import get_event_dispatcher
            >>> dispatcher = get_event_dispatcher()
            >>> dispatcher.register_event(MyEvent())
            >>> dispatcher.start()
        """
        self._queue: List[Tuple[int, int, QueuedEvent]] = []
        self._events: Dict[str, Event] = {}
        self._counter: int = 0
        self._running: bool = False
        self._thread: Optional[threading.Thread] = None

    def register_event(self, event: Event) -> str:
        """
        Register an event with the dispatcher.

        Adds the event to the dispatcher's registry, making it available
        for scheduling. If the event has an execution_interval, it will
        be automatically scheduled when run() is called.

        Args:
            event (Event): The Event instance to register. The event's id
                must be unique within this dispatcher.

        Returns:
            str: The event's ID, useful for chaining or reference.

        Example:
            >>> dispatcher = get_event_dispatcher()
            >>>
            >>> # Register events
            >>> sync_id = dispatcher.register_event(SyncEvent(id="sync-event"))
            >>> alert_id = dispatcher.register_event(AlertEvent(id="alert-event"))
            >>>
            >>> # Use the returned ID to schedule
            >>> dispatcher.schedule("sync-event")
        """
        self._events[event.id] = event
        return event.id

    def unregister_event(self, event_id: str) -> None:
        """
        Remove an event from the dispatcher's registry.

        Unregisters the event, preventing it from being scheduled in the
        future. Note that events already in the queue will still execute;
        this only prevents new scheduling.

        Args:
            event_id (str): The ID of the event to unregister.

        Warns:
            UserWarning: If the event_id is not found in the registry.

        Example:
            >>> dispatcher = get_event_dispatcher()
            >>> dispatcher.register_event(TemporaryEvent("temp-event"))
            >>>
            >>> # Later, remove the event
            >>> dispatcher.unregister_event("temp-event")
            >>>
            >>> # Attempting to remove non-existent event warns
            >>> dispatcher.unregister_event("nonexistent")  # Warns
        """
        if event_id not in self._events:
            warnings.warn("attempt to remove an event that does not exists")
            return
        self._events.pop(event_id)

    def _heap_key(self, execution_date: datetime) -> int:
        return ceil(execution_date.timestamp() * 1000)

    def schedule(
        self, event_id: str, metadata: Optional[Dict] = None, execution_interval: Optional[timedelta] = None
    ) -> None:
        """
        Schedule a registered event for execution.

        Adds the event to the execution queue. The event will be executed
        when its scheduled time arrives during the run() loop.

        Args:
            event_id (str): The ID of a previously registered event.
            metadata (Optional[Dict]): Arbitrary data to pass to the event's
                trigger() method. Use this to customize event behavior on a
                per-invocation basis. Defaults to None.
            execution_interval (Optional[timedelta]): Delay before the event
                should execute. If None, the event executes immediately on
                the next run() iteration. Defaults to None.

        Warns:
            UserWarning: If the event_id is not found in the registry.

        Example:
            >>> dispatcher = get_event_dispatcher()
            >>> dispatcher.register_event(NotificationEvent(id="notification"))
            >>>
            >>> # Execute immediately
            >>> dispatcher.schedule("notification")
            >>>
            >>> # Execute with metadata
            >>> dispatcher.schedule("notification",
            ...     metadata={"title": "Reminder", "body": "Meeting in 5 min"}
            ... )
            >>>
            >>> # Execute after a delay
            >>> dispatcher.schedule("notification",
            ...     metadata={"title": "Delayed"},
            ...     execution_interval=timedelta(seconds=30)
            ... )
        """
        if event_id not in self._events:
            warnings.warn("attempt to schedule an event that does not exists")
            return

        event = self._events[event_id]
        queued_event = QueuedEvent(event=event, metadata=metadata)
        if execution_interval:
            execution_date = datetime.now() + execution_interval
        else:
            execution_date = datetime.now()

        heap_key = self._heap_key(execution_date)
        heapq.heappush(self._queue, (heap_key, self._counter, queued_event))
        self._counter += 1

    def _enqueue(self):
        for event in self._events.values():
            if event.execution_interval:
                if not event.next_execution_date or event.next_execution_date < datetime.now():
                    event.next_execution_date = datetime.now() + event.execution_interval
                    self.schedule(event.id)

    def _process(self):
        while self._queue:
            heap_key, counter, queued_event = heapq.heappop(self._queue)
            if heap_key <= self._heap_key(datetime.now()):
                result = queued_event.event.trigger(queued_event.metadata)
                if result:
                    if is_dataclass(result):
                        dict_result: Dict = enum_to_str(asdict(result))  # type: ignore
                    else:
                        dict_result = result  # type: ignore
                    pyotherside.send(queued_event.event.id, dict_result)
            else:
                heapq.heappush(self._queue, (heap_key, counter, queued_event))
                break

    def _run(self, interval_seconds: float = 0.5):
        self.register_event(ErrorEvent(id="error-event"))

        self._running = True
        while self._running:
            try:
                self._enqueue()
                self._process()
                time.sleep(interval_seconds)
            except Exception as e:
                self.schedule("error-event", metadata={"error": str(e), "traceback": traceback.format_exc()})
                traceback.print_exc()

    def start(self, interval_seconds: float = 0.5):
        """
        Start the event dispatcher in a background thread.

        Creates a daemon thread that runs the event loop,
        allowing the main thread to continue execution.

        Args:
            interval_seconds (float): Time in seconds to sleep between
                processing iterations. Defaults to 0.5.

        Example:
            >>> dispatcher = get_event_dispatcher()
            >>> dispatcher.register_event(HeartbeatEvent(id="heartbeat-event"))
            >>> dispatcher.start()
            >>> # Main thread continues executing
        """
        if self._thread and self._thread.is_alive():
            return
        self._thread = threading.Thread(target=self._run, args=(interval_seconds,), daemon=True)
        self._thread.start()

    def stop(self):
        """
        Stop the event dispatcher loop.

        Signals the run loop to exit gracefully. If running in a background
        thread via start(), waits for the thread to terminate.

        Example:
            >>> dispatcher = get_event_dispatcher()
            >>> dispatcher.start()
            >>> # ... later ...
            >>> dispatcher.stop()
        """
        self._running = False
        if self._thread and self._thread.is_alive():
            self._thread.join(timeout=0)
            self._thread = None


def get_event_dispatcher() -> EventDispatcher:
    """
    Get the global singleton EventDispatcher instance.

    This is the recommended way to access the EventDispatcher. Do not
    instantiate EventDispatcher directly; always use this function to
    ensure a single shared instance across your application.

    Returns:
        EventDispatcher: The global singleton dispatcher instance.

    Example:
        >>> from python.event import Event, get_event_dispatcher
        >>> from datetime import timedelta
        >>>
        >>> class MyEvent(Event):
        ...     def trigger(self, metadata=None):
        ...         return {"status": "ok"}
        >>>
        >>> get_event_dispatcher().register_event(
        ...     MyEvent(id="my-event", execution_interval=timedelta(seconds=10))
        ... )
        >>>
        >>> def start_loop():
        ...     get_event_dispatcher().start()
        >>>
        >>> def stop_loop():
        ...     get_event_dispatcher().stop()
    """
    global EVENT_DISPATCHER
    if EVENT_DISPATCHER:
        return EVENT_DISPATCHER
    else:
        EVENT_DISPATCHER = EventDispatcher()
        return EVENT_DISPATCHER
