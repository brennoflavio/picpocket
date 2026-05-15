import Lomiri.Components 1.3
import QtMultimedia 5.12
import QtQuick 2.12
import QtQuick.Layouts 1.3

/*!
 * \brief VideoViewer - A reusable video viewer with app-driven adjacent-item navigation
 *
 * VideoViewer provides a consistent video playback experience for Ubuntu Touch apps:
 * play/pause, scrub/progress controls, current time and duration labels, horizontal navigation
 * intent, and optional previous/next overlay buttons.
 *
 * The component renders only `currentItem`. Adjacent navigation is app-driven through
 * `previousItem` and `nextItem` so apps can support finite or infinite galleries without the
 * viewer owning a full list.
 *
 * Adjacent item state:
 * - `undefined`: availability is unknown or still loading
 * - `null`: confirmed unavailable
 * - string/object: available and can be navigated to
 *
 * Accepted video input formats:
 * - string: direct video source/path
 * - object with `source`
 * - object with `filePath`
 * - object with `videoPath`
 * - object with `url`
 * - object with `path`
 *
 * Absolute filesystem paths are normalized to `file://` automatically.
 *
 * Example usage:
 * \qml
 * VideoViewer {
 *     anchors.fill: parent
 *     currentItem: currentVideo
 *     previousItem: previousVideo
 *     nextItem: nextVideo
 *
 *     onRequestPrevious: page.loadPrevious(video)
 *     onRequestNext: page.loadNext(video)
 *     onPreviousTriggered: page.showPrevious(video)
 *     onNextTriggered: page.showNext(video)
 * }
 * \endqml
 *
 * Properties:
 * - currentItem (var): Active video to render.
 * - previousItem / nextItem (var): Adjacent video state using the `undefined` / `null` / available convention.
 * - navigationEnabled (bool): Enables any back/forward navigation logic (default: true).
 * - swipeNavigationEnabled (bool): Enables horizontal swipe navigation intent (default: true).
 * - showNavigationButtons (bool): Shows previous/next overlay buttons (default: true).
 * - autoHideControls (bool): Hides playback controls automatically while a video is playing (default: true).
 * - canGoPrevious / canGoNext (bool, read-only): Whether navigation is currently available in each direction.
 * - playing (bool, read-only): Whether the active video is currently playing.
 * - controlsVisible (bool, read-only): Whether the active video's controls are visible.
 * - position (int, read-only): Current playback position in milliseconds.
 * - duration (int, read-only): Active video duration in milliseconds.
 *
 * Signals:
 * - clicked(): Emitted on single tap/click on the video area.
 * - requestPrevious(var currentItem): Ask the app to resolve `previousItem` for the current video.
 * - requestNext(var currentItem): Ask the app to resolve `nextItem` for the current video.
 * - previousTriggered(var currentItem): Emitted when the user intends to navigate backward.
 * - nextTriggered(var currentItem): Emitted when the user intends to navigate forward.
 * - playbackChanged(bool playing): Emitted when the active video's playback state changes.
 *
 * Methods:
 * - goPrevious(): Emit backward navigation intent when available.
 * - goNext(): Emit forward navigation intent when available.
 * - play(): Start playback of the active video.
 * - pause(): Pause playback of the active video.
 * - togglePlayback(): Toggle play/pause on the active video.
 * - seek(position): Seek the active video to the specified position in milliseconds.
 * - resetPlayback(): Pause and return the active video to the beginning.
 */
Item {
    id: videoViewer

    //! Active video to render.
    property var currentItem: null
    //! Previous adjacent video state: undefined = unknown/loading, null = unavailable, item = available.
    property var previousItem: undefined
    //! Next adjacent video state: undefined = unknown/loading, null = unavailable, item = available.
    property var nextItem: undefined
    //! Enables previous/next navigation behavior.
    property bool navigationEnabled: true
    //! Enables horizontal swipe navigation between adjacent items.
    property bool swipeNavigationEnabled: true
    //! Shows previous/next overlay buttons.
    property bool showNavigationButtons: true
    //! Hides playback controls automatically while the active video is playing.
    property bool autoHideControls: true
    readonly property bool hasCurrentItem: currentItem !== undefined && currentItem !== null
    readonly property bool canGoPrevious: navigationEnabled && previousItem !== undefined && previousItem !== null
    readonly property bool canGoNext: navigationEnabled && nextItem !== undefined && nextItem !== null
    //! Whether the active video is currently playing.
    readonly property bool playing: activeVideo.isPlaying === undefined ? false : activeVideo.isPlaying
    //! Whether the active video's controls are visible.
    readonly property bool controlsVisible: activeVideo.controlsVisible === undefined ? false : activeVideo.controlsVisible
    //! Current playback position of the active video in milliseconds.
    readonly property int position: activeVideo.position === undefined ? 0 : activeVideo.position
    //! Total duration of the active video in milliseconds.
    readonly property int duration: activeVideo.duration === undefined ? 0 : activeVideo.duration
    readonly property string currentSource: sourceFor(currentItem)
    property bool componentCompleted: false

    //! Emitted on single tap/click on the video area.
    signal clicked()
    //! Ask the app to resolve the previous adjacent item for the current video.
    signal requestPrevious(var currentItem)
    //! Ask the app to resolve the next adjacent item for the current video.
    signal requestNext(var currentItem)
    //! Emitted when the user intends to navigate to the previous item.
    signal previousTriggered(var currentItem)
    //! Emitted when the user intends to navigate to the next item.
    signal nextTriggered(var currentItem)
    //! Emitted whenever the active video toggles between playing and paused.
    signal playbackChanged(bool playing)

    function normalizeSource(source) {
        if (!source)
            return "";

        var sourceString = source.toString();
        if (sourceString.indexOf("://") !== -1 || sourceString.indexOf("qrc:/") === 0 || sourceString.indexOf("data:") === 0)
            return sourceString;

        if (sourceString.charAt(0) === "/")
            return "file://" + sourceString;

        return sourceString;
    }

    function sourceFor(videoData) {
        if (videoData === undefined || videoData === null)
            return "";

        if (typeof videoData === "string")
            return normalizeSource(videoData);

        if (videoData.source !== undefined)
            return normalizeSource(videoData.source);

        if (videoData.filePath !== undefined)
            return normalizeSource(videoData.filePath);

        if (videoData.videoPath !== undefined)
            return normalizeSource(videoData.videoPath);

        if (videoData.url !== undefined)
            return normalizeSource(videoData.url);

        if (videoData.path !== undefined)
            return normalizeSource(videoData.path);

        return "";
    }

    function formatTime(milliseconds) {
        if (!milliseconds || milliseconds < 0)
            return "0:00";

        var totalSeconds = Math.floor(milliseconds / 1000);
        var hours = Math.floor(totalSeconds / 3600);
        var minutes = Math.floor((totalSeconds % 3600) / 60);
        var seconds = totalSeconds % 60;
        if (hours > 0)
            return hours + ":" + (minutes < 10 ? "0" : "") + minutes + ":" + (seconds < 10 ? "0" : "") + seconds;

        return minutes + ":" + (seconds < 10 ? "0" : "") + seconds;
    }

    function requestAdjacentItems() {
        if (!hasCurrentItem)
            return ;

        requestPrevious(currentItem);
        requestNext(currentItem);
    }

    function scheduleAdjacentRequests() {
        if (!componentCompleted)
            return ;

        adjacentRequestTimer.restart();
    }

    function goPrevious() {
        if (!canGoPrevious || activeVideo.userInteracting)
            return false;

        previousTriggered(currentItem);
        return true;
    }

    function goNext() {
        if (!canGoNext || activeVideo.userInteracting)
            return false;

        nextTriggered(currentItem);
        return true;
    }

    function play() {
        activeVideo.playVideo();
    }

    function pause() {
        activeVideo.pauseVideo();
    }

    function togglePlayback() {
        activeVideo.togglePlayback();
    }

    function seek(playbackPosition) {
        activeVideo.seekTo(playbackPosition);
    }

    function resetPlayback() {
        activeVideo.resetPlayback();
    }

    onCurrentItemChanged: {
        resetPlayback();
        activeVideo.playbackSource = "";
        sourceRefreshTimer.restart();
        scheduleAdjacentRequests();
    }
    Component.onCompleted: {
        componentCompleted = true;
        activeVideo.playbackSource = "";
        sourceRefreshTimer.restart();
        scheduleAdjacentRequests();
    }

    Timer {
        id: adjacentRequestTimer

        interval: 0
        repeat: false
        onTriggered: videoViewer.requestAdjacentItems()
    }

    Timer {
        id: sourceRefreshTimer

        interval: 0
        repeat: false
        onTriggered: activeVideo.playbackSource = videoViewer.currentSource
    }

    Rectangle {
        anchors.fill: parent
        color: "black"
    }

    Item {
        id: activeVideo

        property bool controlsVisible: true
        property string playbackSource: ""
        property int scrubPosition: videoPlayer.position
        property bool resumeAfterSeek: false
        property bool playRequested: false
        readonly property bool isPlaying: videoPlayer.playbackState === MediaPlayer.PlayingState
        readonly property bool userInteracting: progressArea.pressed
        readonly property int position: progressArea.pressed ? scrubPosition : videoPlayer.position
        readonly property int duration: videoPlayer.duration

        function showControls() {
            controlsVisible = true;
            if (isPlaying && videoViewer.autoHideControls && !progressArea.pressed)
                hideControlsTimer.restart();
            else
                hideControlsTimer.stop();
        }

        function playVideo() {
            if (videoPlayer.source === "")
                return ;

            playRequested = true;
            showControls();
            if (videoPlayer.status === MediaPlayer.EndOfMedia || (videoPlayer.duration > 0 && videoPlayer.position >= videoPlayer.duration)) {
                if (videoPlayer.seekable)
                    videoPlayer.seek(0);

            }
            videoPlayer.play();
        }

        function pauseVideo() {
            playRequested = false;
            videoPlayer.pause();
            controlsVisible = true;
            hideControlsTimer.stop();
        }

        function togglePlayback() {
            if (isPlaying)
                pauseVideo();
            else
                playVideo();
        }

        function seekTo(playbackPosition) {
            if (!videoPlayer.seekable)
                return ;

            var boundedPosition = Math.max(0, Math.min(playbackPosition, videoPlayer.duration > 0 ? videoPlayer.duration : playbackPosition));
            scrubPosition = boundedPosition;
            videoPlayer.seek(boundedPosition);
            controlsVisible = true;
            if (isPlaying && videoViewer.autoHideControls)
                hideControlsTimer.restart();

        }

        function resetPlayback() {
            hideControlsTimer.stop();
            controlsVisible = true;
            resumeAfterSeek = false;
            playRequested = false;
            scrubPosition = 0;
            videoPlayer.pause();
            if (videoPlayer.seekable)
                videoPlayer.seek(0);

        }

        anchors.fill: parent
        visible: videoViewer.hasCurrentItem

        Timer {
            id: hideControlsTimer

            interval: 2500
            onTriggered: {
                if (activeVideo.isPlaying && !progressArea.pressed)
                    activeVideo.controlsVisible = false;

            }
        }

        Video {
            id: videoPlayer

            anchors.fill: parent
            source: activeVideo.playbackSource
            autoPlay: false
            fillMode: VideoOutput.PreserveAspectFit
            onPlaybackStateChanged: {
                if (activeVideo.isPlaying)
                    activeVideo.playRequested = false;

                videoViewer.playbackChanged(activeVideo.isPlaying);
                if (activeVideo.isPlaying) {
                    activeVideo.showControls();
                } else {
                    activeVideo.controlsVisible = true;
                    hideControlsTimer.stop();
                }
            }
            onStatusChanged: {
                if (activeVideo.playRequested && (status === MediaPlayer.Loaded || status === MediaPlayer.Buffered))
                    play();

                if (status === MediaPlayer.InvalidMedia)
                    activeVideo.playRequested = false;

                if (status === MediaPlayer.EndOfMedia) {
                    activeVideo.playRequested = false;
                    pause();
                    if (seekable)
                        seek(0);

                    activeVideo.controlsVisible = true;
                    hideControlsTimer.stop();
                }
            }
        }

        MouseArea {
            id: videoArea

            property real pressX: 0
            property real pressY: 0
            property bool suppressClick: false
            property real swipeThreshold: units.gu(6)

            anchors.fill: parent
            onPressed: {
                pressX = mouse.x;
                pressY = mouse.y;
                suppressClick = false;
            }
            onReleased: {
                var deltaX = mouse.x - pressX;
                var deltaY = mouse.y - pressY;
                if (activeVideo.userInteracting)
                    return ;

                if (Math.abs(deltaX) < swipeThreshold || Math.abs(deltaX) <= Math.abs(deltaY))
                    return ;

                suppressClick = true;
                if (videoViewer.navigationEnabled && videoViewer.swipeNavigationEnabled) {
                    if (deltaX > 0)
                        videoViewer.goPrevious();
                    else
                        videoViewer.goNext();
                }
            }
            onClicked: {
                if (suppressClick) {
                    suppressClick = false;
                    return ;
                }
                activeVideo.controlsVisible = !activeVideo.controlsVisible;
                if (activeVideo.controlsVisible && activeVideo.isPlaying && videoViewer.autoHideControls)
                    hideControlsTimer.restart();
                else
                    hideControlsTimer.stop();
                videoViewer.clicked();
            }
        }

        ActivityIndicator {
            anchors.centerIn: parent
            visible: running
            running: videoPlayer.source !== "" && (videoPlayer.status === MediaPlayer.Loading || videoPlayer.status === MediaPlayer.Buffering)
        }

        Label {
            anchors.centerIn: parent
            text: i18n.tr("Failed to load video")
            color: "lightgrey"
            visible: videoPlayer.status === MediaPlayer.InvalidMedia && videoPlayer.source !== ""
        }

        Item {
            anchors.centerIn: parent
            width: units.gu(8)
            height: width
            visible: videoPlayer.source !== "" && activeVideo.controlsVisible && videoPlayer.status !== MediaPlayer.InvalidMedia

            Rectangle {
                anchors.fill: parent
                radius: width / 2
                color: "#80000000"
            }

            Icon {
                anchors.centerIn: parent
                name: activeVideo.isPlaying ? "media-playback-pause" : "media-playback-start"
                width: units.gu(4)
                height: width
                color: "white"
            }

            MouseArea {
                anchors.fill: parent
                onClicked: activeVideo.togglePlayback()
            }

        }

        Rectangle {
            id: controlsBar

            visible: activeVideo.controlsVisible && videoPlayer.source !== ""
            height: units.gu(7)
            color: "#AA000000"

            anchors {
                left: parent.left
                right: parent.right
                bottom: parent.bottom
            }

            RowLayout {
                spacing: units.gu(1)

                anchors {
                    fill: parent
                    leftMargin: units.gu(1.5)
                    rightMargin: units.gu(1.5)
                }

                Icon {
                    name: activeVideo.isPlaying ? "media-playback-pause" : "media-playback-start"
                    width: units.gu(3)
                    height: units.gu(3)
                    color: "white"
                    Layout.alignment: Qt.AlignVCenter

                    MouseArea {
                        anchors.fill: parent
                        onClicked: activeVideo.togglePlayback()
                    }

                }

                Label {
                    text: videoViewer.formatTime(activeVideo.position)
                    fontSize: "x-small"
                    color: "white"
                    Layout.alignment: Qt.AlignVCenter
                }

                Item {
                    id: progressWrapper

                    readonly property real progress: activeVideo.duration > 0 ? Math.max(0, Math.min(1, activeVideo.position / activeVideo.duration)) : 0

                    Layout.fillWidth: true
                    Layout.alignment: Qt.AlignVCenter
                    height: units.gu(2.5)

                    Rectangle {
                        id: progressTrack

                        height: units.gu(0.4)
                        radius: height / 2
                        color: "#C0C0C0"

                        anchors {
                            left: parent.left
                            right: parent.right
                            verticalCenter: parent.verticalCenter
                        }

                    }

                    Rectangle {
                        width: progressTrack.width * progressWrapper.progress
                        height: progressTrack.height
                        radius: height / 2
                        color: LomiriColors.green

                        anchors {
                            left: progressTrack.left
                            verticalCenter: progressTrack.verticalCenter
                        }

                    }

                    Rectangle {
                        width: units.gu(1.2)
                        height: width
                        radius: width / 2
                        color: LomiriColors.green
                        x: progressTrack.x + progressTrack.width * progressWrapper.progress - width / 2
                        anchors.verticalCenter: progressTrack.verticalCenter
                    }

                    MouseArea {
                        id: progressArea

                        function boundedRatio(mouseX) {
                            return Math.max(0, Math.min(1, mouseX / width));
                        }

                        function updateSeek(mouseX) {
                            if (videoPlayer.duration <= 0)
                                return ;

                            activeVideo.scrubPosition = boundedRatio(mouseX) * videoPlayer.duration;
                        }

                        anchors.fill: parent
                        anchors.topMargin: -units.gu(1)
                        anchors.bottomMargin: -units.gu(1)
                        preventStealing: true
                        onPressed: {
                            if (videoPlayer.duration <= 0)
                                return ;

                            activeVideo.resumeAfterSeek = activeVideo.isPlaying;
                            if (activeVideo.resumeAfterSeek)
                                activeVideo.pauseVideo();

                            updateSeek(mouse.x);
                        }
                        onPositionChanged: {
                            if (pressed)
                                updateSeek(mouse.x);

                        }
                        onReleased: {
                            updateSeek(mouse.x);
                            activeVideo.seekTo(activeVideo.scrubPosition);
                            if (activeVideo.resumeAfterSeek)
                                activeVideo.playVideo();

                            activeVideo.resumeAfterSeek = false;
                        }
                        onCanceled: {
                            if (activeVideo.resumeAfterSeek)
                                activeVideo.playVideo();

                            activeVideo.resumeAfterSeek = false;
                        }
                    }

                }

                Label {
                    text: videoViewer.formatTime(activeVideo.duration)
                    fontSize: "x-small"
                    color: "white"
                    Layout.alignment: Qt.AlignVCenter
                }

            }

        }

    }

    Item {
        anchors.centerIn: parent
        visible: !videoViewer.hasCurrentItem

        Column {
            spacing: units.gu(1)
            anchors.centerIn: parent

            Icon {
                anchors.horizontalCenter: parent.horizontalCenter
                name: "stock_video"
                width: units.gu(4)
                height: width
                color: "white"
            }

            Label {
                text: i18n.tr("No video to display")
                color: "white"
            }

        }

    }

    MouseArea {
        id: previousArea

        width: units.gu(8)
        height: units.gu(12)
        enabled: videoViewer.showNavigationButtons && videoViewer.canGoPrevious && !activeVideo.userInteracting
        visible: videoViewer.showNavigationButtons && videoViewer.canGoPrevious && videoViewer.hasCurrentItem
        hoverEnabled: true
        onClicked: videoViewer.goPrevious()

        anchors {
            left: parent.left
            leftMargin: units.gu(1)
            verticalCenter: parent.verticalCenter
        }

        Rectangle {
            anchors.fill: parent
            color: theme.palette.normal.foreground
            opacity: previousArea.pressed ? 0.3 : 0

            Behavior on opacity {
                NumberAnimation {
                    duration: 100
                }

            }

        }

        Icon {
            width: units.gu(4)
            height: width
            name: "go-previous"
            color: "white"
            opacity: previousArea.enabled ? (previousArea.containsMouse || previousArea.pressed ? 0.9 : 0.5) : 0.2

            anchors {
                left: parent.left
                leftMargin: units.gu(1)
                verticalCenter: parent.verticalCenter
            }

            Behavior on opacity {
                NumberAnimation {
                    duration: 100
                }

            }

        }

    }

    MouseArea {
        id: nextArea

        width: units.gu(8)
        height: units.gu(12)
        enabled: videoViewer.showNavigationButtons && videoViewer.canGoNext && !activeVideo.userInteracting
        visible: videoViewer.showNavigationButtons && videoViewer.canGoNext && videoViewer.hasCurrentItem
        hoverEnabled: true
        onClicked: videoViewer.goNext()

        anchors {
            right: parent.right
            rightMargin: units.gu(1)
            verticalCenter: parent.verticalCenter
        }

        Rectangle {
            anchors.fill: parent
            color: theme.palette.normal.foreground
            opacity: nextArea.pressed ? 0.3 : 0

            Behavior on opacity {
                NumberAnimation {
                    duration: 100
                }

            }

        }

        Icon {
            width: units.gu(4)
            height: width
            name: "go-next"
            color: "white"
            opacity: nextArea.enabled ? (nextArea.containsMouse || nextArea.pressed ? 0.9 : 0.5) : 0.2

            anchors {
                right: parent.right
                rightMargin: units.gu(1)
                verticalCenter: parent.verticalCenter
            }

            Behavior on opacity {
                NumberAnimation {
                    duration: 100
                }

            }

        }

    }

}
