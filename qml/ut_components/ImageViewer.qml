import Lomiri.Components 1.3
import QtQuick 2.12

/*!
 * \brief ImageViewer - A reusable image viewer with app-driven adjacent-item navigation
 *
 * ImageViewer provides the opinionated image viewing experience used across Ubuntu Touch apps:
 * pinch-to-zoom, panning while zoomed, double tap to zoom in/out, horizontal navigation intent,
 * and optional previous/next overlay buttons.
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
 * Accepted image input formats:
 * - string: direct image source/path
 * - object with `source`
 * - object with `filePath`
 * - object with `imagePath`
 * - object with `url`
 * - object with `path`
 *
 * Absolute filesystem paths are normalized to `file://` automatically.
 *
 * Example usage:
 * \qml
 * ImageViewer {
 *     anchors.fill: parent
 *     currentItem: currentPhoto
 *     previousItem: previousPhoto
 *     nextItem: nextPhoto
 *
 *     onRequestPrevious: page.loadPrevious(photo)
 *     onRequestNext: page.loadNext(photo)
 *     onPreviousTriggered: page.showPrevious(photo)
 *     onNextTriggered: page.showNext(photo)
 * }
 * \endqml
 *
 * Properties:
 * - currentItem (var): Active image to render.
 * - previousItem / nextItem (var): Adjacent image state using the `undefined` / `null` / available convention.
 * - maximumZoom (real): Maximum zoom multiplier (default: 10).
 * - navigationEnabled (bool): Enables any back/forward navigation logic (default: true).
 * - swipeNavigationEnabled (bool): Enables horizontal swipe navigation intent (default: true).
 * - showNavigationButtons (bool): Shows previous/next overlay buttons (default: true).
 * - canGoPrevious / canGoNext (bool, read-only): Whether navigation is currently available in each direction.
 * - zoomed (bool, read-only): Whether the current image is zoomed beyond the base fit.
 * - zoomFactor (real, read-only): Current zoom multiplier of the active image.
 *
 * Signals:
 * - clicked(): Emitted on single tap/click.
 * - requestPrevious(var currentItem): Ask the app to resolve `previousItem` for the current image.
 * - requestNext(var currentItem): Ask the app to resolve `nextItem` for the current image.
 * - previousTriggered(var currentItem): Emitted when the user intends to navigate backward.
 * - nextTriggered(var currentItem): Emitted when the user intends to navigate forward.
 *
 * Methods:
 * - goPrevious(): Emit backward navigation intent when available.
 * - goNext(): Emit forward navigation intent when available.
 * - resetZoom(): Reset the active image to its fitted zoom level.
 */
Item {
    id: imageViewer

    //! Active image to render.
    property var currentItem: null
    //! Previous adjacent image state: undefined = unknown/loading, null = unavailable, item = available.
    property var previousItem: undefined
    //! Next adjacent image state: undefined = unknown/loading, null = unavailable, item = available.
    property var nextItem: undefined
    //! Maximum zoom multiplier applied by pinch or double tap.
    property real maximumZoom: 10
    //! Enables previous/next navigation behavior.
    property bool navigationEnabled: true
    //! Enables horizontal swipe navigation between adjacent items.
    property bool swipeNavigationEnabled: true
    //! Shows previous/next overlay buttons.
    property bool showNavigationButtons: true
    readonly property bool hasCurrentItem: currentItem !== undefined && currentItem !== null
    readonly property bool canGoPrevious: navigationEnabled && previousItem !== undefined && previousItem !== null
    readonly property bool canGoNext: navigationEnabled && nextItem !== undefined && nextItem !== null
    //! Whether the current image is zoomed beyond its fitted size.
    readonly property bool zoomed: currentImageItem.fullyUnzoomed === undefined ? false : !currentImageItem.fullyUnzoomed
    //! Current zoom multiplier for the active image.
    readonly property real zoomFactor: currentImageItem.currentZoom === undefined ? 1 : currentImageItem.currentZoom
    readonly property string currentSource: sourceFor(currentItem)
    property bool componentCompleted: false

    //! Emitted on single tap/click.
    signal clicked()
    //! Ask the app to resolve the previous adjacent item for the current image.
    signal requestPrevious(var currentItem)
    //! Ask the app to resolve the next adjacent item for the current image.
    signal requestNext(var currentItem)
    //! Emitted when the user intends to navigate to the previous item.
    signal previousTriggered(var currentItem)
    //! Emitted when the user intends to navigate to the next item.
    signal nextTriggered(var currentItem)

    function normalizeSource(source) {
        if (!source)
            return "";

        var sourceString = source.toString();
        if (sourceString.indexOf("://") !== -1 || sourceString.indexOf("qrc:/") === 0 || sourceString.indexOf("image://") === 0 || sourceString.indexOf("data:") === 0)
            return sourceString;

        if (sourceString.charAt(0) === "/")
            return "file://" + sourceString;

        return sourceString;
    }

    function sourceFor(imageData) {
        if (imageData === undefined || imageData === null)
            return "";

        if (typeof imageData === "string")
            return normalizeSource(imageData);

        if (imageData.source !== undefined)
            return normalizeSource(imageData.source);

        if (imageData.filePath !== undefined)
            return normalizeSource(imageData.filePath);

        if (imageData.imagePath !== undefined)
            return normalizeSource(imageData.imagePath);

        if (imageData.url !== undefined)
            return normalizeSource(imageData.url);

        if (imageData.path !== undefined)
            return normalizeSource(imageData.path);

        return "";
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
        if (!canGoPrevious || zoomed)
            return false;

        previousTriggered(currentItem);
        return true;
    }

    function goNext() {
        if (!canGoNext || zoomed)
            return false;

        nextTriggered(currentItem);
        return true;
    }

    function resetZoom() {
        currentImageItem.reset();
    }

    onCurrentItemChanged: {
        resetZoom();
        scheduleAdjacentRequests();
    }
    Component.onCompleted: {
        componentCompleted = true;
        scheduleAdjacentRequests();
    }

    Timer {
        id: adjacentRequestTimer

        interval: 0
        repeat: false
        onTriggered: imageViewer.requestAdjacentItems()
    }

    Rectangle {
        anchors.fill: parent
        color: "black"
    }

    Item {
        id: currentImageItem

        readonly property bool fullyUnzoomed: zoomableImage.fullyUnzoomed
        readonly property real currentZoom: zoomableImage.currentZoom

        function reset() {
            zoomableImage.reset();
        }

        anchors.fill: parent
        visible: imageViewer.hasCurrentItem
        clip: true

        Item {
            id: zoomableImage

            readonly property alias image: imageRenderer
            readonly property bool pinchInProgress: zoomPinchArea.pinch.active
            readonly property real currentZoom: Math.max(flickable.contentWidth / flickable.width, flickable.contentHeight / flickable.height)
            readonly property bool fullyUnzoomed: currentZoom <= 1.01
            readonly property bool userInteracting: pinchInProgress || !fullyUnzoomed
            readonly property bool imageReady: imageRenderer.status === Image.Ready
            property real baseImageWidth: 0
            property real baseImageHeight: 0

            function zoomIn(contentWidth, contentHeight, centerPoint, animated) {
                var newZoom = Math.max(contentWidth / flickable.width, contentHeight / flickable.height);
                var boundedZoom = Math.min(newZoom, imageViewer.maximumZoom);
                var newPaintedWidth = baseImageWidth * boundedZoom;
                var newPaintedHeight = baseImageHeight * boundedZoom;
                var newWidth = Math.max(flickable.width, newPaintedWidth);
                var newHeight = Math.max(flickable.height, newPaintedHeight);
                if (animated)
                    flickable.animatedResizeContent(newWidth, newHeight, centerPoint);
                else
                    flickable.resizeContent(newWidth, newHeight, centerPoint);
            }

            function zoomOut(animated) {
                var centerPoint = Qt.point(flickable.width / 2, flickable.height / 2);
                if (animated)
                    flickable.animatedResizeContent(flickable.width, flickable.height, centerPoint);
                else
                    flickable.resizeContent(flickable.width, flickable.height, centerPoint);
            }

            function reset() {
                zoomOut(false);
            }

            anchors.fill: parent

            ActivityIndicator {
                anchors.centerIn: parent
                visible: running
                running: imageRenderer.source !== "" && imageRenderer.status !== Image.Ready && imageRenderer.status !== Image.Error
            }

            Flickable {
                id: flickable

                function animatedResizeContent(newWidth, newHeight, centerPoint) {
                    var zoom = Math.max(1, zoomableImage.currentZoom);
                    var ratioX = contentWidth > 0 ? centerPoint.x / contentWidth : 0;
                    var ratioY = contentHeight > 0 ? centerPoint.y / contentHeight : 0;
                    contentXAnimation.to = newWidth * ratioX - centerPoint.x / zoom;
                    contentYAnimation.to = newHeight * ratioY - centerPoint.y / zoom;
                    contentWidthAnimation.to = newWidth;
                    contentHeightAnimation.to = newHeight;
                    resizeContentAnimation.restart();
                }

                anchors.fill: parent
                contentWidth: width
                contentHeight: height
                interactive: !zoomableImage.pinchInProgress && !zoomableImage.fullyUnzoomed
                boundsBehavior: Flickable.StopAtBounds
                boundsMovement: Flickable.StopAtBounds

                ParallelAnimation {
                    id: resizeContentAnimation

                    LomiriNumberAnimation {
                        id: contentWidthAnimation

                        target: flickable
                        property: "contentWidth"
                        duration: LomiriAnimation.FastDuration
                    }

                    LomiriNumberAnimation {
                        id: contentHeightAnimation

                        target: flickable
                        property: "contentHeight"
                        duration: LomiriAnimation.FastDuration
                    }

                    LomiriNumberAnimation {
                        id: contentXAnimation

                        target: flickable
                        property: "contentX"
                        duration: LomiriAnimation.FastDuration
                    }

                    LomiriNumberAnimation {
                        id: contentYAnimation

                        target: flickable
                        property: "contentY"
                        duration: LomiriAnimation.FastDuration
                    }

                }

                PinchArea {
                    id: zoomPinchArea

                    property real initialWidth: flickable.width
                    property real initialHeight: flickable.height

                    enabled: zoomableImage.imageReady
                    width: Math.max(flickable.contentWidth, flickable.width)
                    height: Math.max(flickable.contentHeight, flickable.height)
                    onPinchStarted: {
                        initialWidth = flickable.contentWidth;
                        initialHeight = flickable.contentHeight;
                    }
                    onPinchUpdated: {
                        var newWidth = initialWidth * pinch.scale;
                        var newHeight = initialHeight * pinch.scale;
                        if (newWidth > flickable.width || newHeight > flickable.height) {
                            flickable.contentX += pinch.previousCenter.x - pinch.center.x;
                            flickable.contentY += pinch.previousCenter.y - pinch.center.y;
                            zoomableImage.zoomIn(newWidth, newHeight, pinch.center, false);
                        } else {
                            zoomableImage.zoomOut(false);
                        }
                    }
                    onPinchFinished: flickable.returnToBounds()

                    Item {
                        width: flickable.contentWidth
                        height: flickable.contentHeight

                        Image {
                            id: imageRenderer

                            anchors.fill: parent
                            source: imageViewer.currentSource
                            fillMode: Image.PreserveAspectFit
                            autoTransform: true
                            asynchronous: true
                            cache: false
                            smooth: true
                            opacity: status === Image.Ready ? 1 : 0
                            onPaintedWidthChanged: {
                                if (status === Image.Ready && zoomableImage.fullyUnzoomed)
                                    zoomableImage.baseImageWidth = paintedWidth;

                            }
                            onPaintedHeightChanged: {
                                if (status === Image.Ready && zoomableImage.fullyUnzoomed)
                                    zoomableImage.baseImageHeight = paintedHeight;

                            }
                            onStatusChanged: {
                                if (status !== Image.Ready) {
                                    zoomableImage.baseImageWidth = 0;
                                    zoomableImage.baseImageHeight = 0;
                                }
                            }

                            Behavior on opacity {
                                LomiriNumberAnimation {
                                    duration: LomiriAnimation.FastDuration
                                }

                            }

                        }

                        Label {
                            anchors.centerIn: parent
                            text: i18n.tr("Failed to load image")
                            color: "lightgrey"
                            visible: imageRenderer.status === Image.Error && imageRenderer.source !== ""
                        }

                        MouseArea {
                            id: imageMouseArea

                            property real pressX: 0
                            property real pressY: 0
                            property bool suppressClick: false
                            property real swipeThreshold: units.gu(6)

                            anchors.fill: parent
                            hoverEnabled: true
                            cursorShape: !zoomableImage.fullyUnzoomed && (containsPress || flickable.dragging) ? Qt.ClosedHandCursor : Qt.ArrowCursor
                            onPressed: {
                                pressX = mouse.x;
                                pressY = mouse.y;
                                suppressClick = false;
                            }
                            onReleased: {
                                var deltaX = mouse.x - pressX;
                                var deltaY = mouse.y - pressY;
                                if (!zoomableImage.imageReady || !zoomableImage.fullyUnzoomed || zoomableImage.pinchInProgress)
                                    return ;

                                if (Math.abs(deltaX) < swipeThreshold || Math.abs(deltaX) <= Math.abs(deltaY))
                                    return ;

                                suppressClick = true;
                                clickTimer.stop();
                                if (imageViewer.navigationEnabled && imageViewer.swipeNavigationEnabled) {
                                    if (deltaX > 0)
                                        imageViewer.goPrevious();
                                    else
                                        imageViewer.goNext();
                                }
                            }
                            onDoubleClicked: {
                                clickTimer.stop();
                                suppressClick = false;
                                if (zoomableImage.imageReady && zoomableImage.fullyUnzoomed) {
                                    var centerPoint = imageMouseArea.mapToItem(flickable, flickable.contentX + imageMouseArea.mouseX, flickable.contentY + imageMouseArea.mouseY);
                                    var newWidth = flickable.width * imageViewer.maximumZoom;
                                    var newHeight = flickable.height * imageViewer.maximumZoom;
                                    zoomableImage.zoomIn(newWidth, newHeight, centerPoint, true);
                                } else {
                                    zoomableImage.zoomOut(true);
                                }
                            }
                            onClicked: {
                                if (suppressClick) {
                                    suppressClick = false;
                                    return ;
                                }
                                clickTimer.restart();
                            }

                            Timer {
                                id: clickTimer

                                interval: 250
                                onTriggered: imageViewer.clicked()
                            }

                        }

                    }

                }

            }

        }

    }

    Item {
        anchors.centerIn: parent
        visible: !imageViewer.hasCurrentItem

        Column {
            spacing: units.gu(1)
            anchors.centerIn: parent

            Icon {
                anchors.horizontalCenter: parent.horizontalCenter
                name: "image-x-generic-symbolic"
                width: units.gu(4)
                height: width
                color: "white"
            }

            Label {
                text: i18n.tr("No image to display")
                color: "white"
            }

        }

    }

    MouseArea {
        id: previousArea

        width: units.gu(8)
        height: units.gu(12)
        enabled: imageViewer.showNavigationButtons && imageViewer.canGoPrevious && !imageViewer.zoomed
        visible: imageViewer.showNavigationButtons && imageViewer.canGoPrevious && imageViewer.hasCurrentItem
        hoverEnabled: true
        onClicked: imageViewer.goPrevious()

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
        enabled: imageViewer.showNavigationButtons && imageViewer.canGoNext && !imageViewer.zoomed
        visible: imageViewer.showNavigationButtons && imageViewer.canGoNext && imageViewer.hasCurrentItem
        hoverEnabled: true
        onClicked: imageViewer.goNext()

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
