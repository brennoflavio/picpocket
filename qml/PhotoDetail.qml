import Lomiri.Components 1.3
import Lomiri.Components.Popups 1.3
import Lomiri.Content 1.3
import QtMultimedia 5.12
/*
 * Copyright (C) 2025  Brenno Flávio de Almeida
 *
 * This program is free software: you can redistribute it and/or modify
 * it under the terms of the GNU General Public License as published by
 * the Free Software Foundation; version 3.
 *
 * calpal is distributed in the hope that it will be useful,
 * but WITHOUT ANY WARRANTY; without even the implied warranty of
 * MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
 * GNU General Public License for more details.
 *
 * You should have received a copy of the GNU General Public License
 * along with this program.  If not, see <http://www.gnu.org/licenses/>.
 */
import QtQuick 2.12
import QtQuick.Layouts 1.12
import UserMetrics 0.1
import io.thp.pyotherside 1.4
import "ut_components"

Page {
    id: photoDetailPage

    property string filePath: ""
    property string photoId: ""
    property string photoName: ""
    property string fileType: "IMAGE"
    property bool isLoading: true
    property string previousId: ""
    property string nextId: ""
    property bool isFavorite: false
    property bool isArchived: false
    property bool isDeleted: false
    property string previewType: "timeline"
    property string albumId: ""
    property string personId: ""
    property string locationId: ""
    property string searchQuery: ""
    property bool imageZoomed: photoDetailPage.fileType === "IMAGE" && mediaLoader.item && mediaLoader.item.zoomed

    function loadPhotoDetails() {
        photoDetailPage.isLoading = true;
        photosViewedMetric.increment(1);
        python.call('immich_client.preview', [photoId, previewType, albumId, personId, locationId, searchQuery], function(result) {
            if (result) {
                if (result.filePath)
                    photoDetailPage.filePath = result.filePath;

                if (result.name)
                    photoDetailPage.photoName = result.name;

                if (result.file_type)
                    photoDetailPage.fileType = result.file_type;

                photoDetailPage.previousId = result.previous || "";
                photoDetailPage.nextId = result.next || "";
                photoDetailPage.isFavorite = result.favorite || false;
                photoDetailPage.isArchived = result.archived || false;
                photoDetailPage.isDeleted = result.deleted || false;
            }
            photoDetailPage.isLoading = false;
        });
    }

    function resetImageZoom() {
        if (mediaLoader.item && mediaLoader.item.resetZoom)
            mediaLoader.item.resetZoom();

    }

    function navigateToPrevious() {
        if (photoDetailPage.previousId && photoDetailPage.previousId !== "") {
            resetImageZoom();
            photoDetailPage.photoId = photoDetailPage.previousId;
            loadPhotoDetails();
        }
    }

    function navigateToNext() {
        if (photoDetailPage.nextId && photoDetailPage.nextId !== "") {
            resetImageZoom();
            photoDetailPage.photoId = photoDetailPage.nextId;
            loadPhotoDetails();
        }
    }

    Metric {
        id: photosViewedMetric

        name: "immich_photos_viewed"
        format: "%1 " + i18n.tr("Immich photos viewed today")
        emptyFormat: i18n.tr("No Immich photos viewed today")
        domain: "picpocket.brennoflavio"
    }

    Python {
        id: python

        Component.onCompleted: {
            addImportPath(Qt.resolvedUrl('../src/'));
            importModule('immich_client', function() {
                if (photoId && photoId !== "")
                    loadPhotoDetails();

            });
        }
        onError: {
            photoDetailPage.isLoading = false;
        }
    }

    Item {
        anchors {
            top: pageHeader.bottom
            left: parent.left
            right: parent.right
            bottom: bottomBar.top
        }

        Loader {
            id: mediaLoader

            anchors.fill: parent
            sourceComponent: photoDetailPage.fileType === "VIDEO" ? videoComponent : imageComponent
        }

        MouseArea {
            id: swipeArea

            property real startX: 0
            property bool swiping: false

            anchors.fill: parent
            enabled: !photoDetailPage.imageZoomed
            z: -1
            onPressed: {
                startX = mouse.x;
                swiping = true;
            }
            onReleased: {
                if (swiping) {
                    var diff = mouse.x - startX;
                    if (Math.abs(diff) > units.gu(10)) {
                        if (diff > 0 && photoDetailPage.previousId !== "")
                            navigateToPrevious();
                        else if (diff < 0 && photoDetailPage.nextId !== "")
                            navigateToNext();
                    }
                }
                swiping = false;
            }
            onCanceled: {
                swiping = false;
            }
        }

        MouseArea {
            id: previousArea

            width: units.gu(8)
            height: units.gu(12)
            enabled: photoDetailPage.previousId !== "" && !photoDetailPage.imageZoomed
            onClicked: navigateToPrevious()

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
                opacity: previousArea.containsMouse || previousArea.pressed ? 0.9 : 0.5
                visible: previousArea.enabled

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
            enabled: photoDetailPage.nextId !== "" && !photoDetailPage.imageZoomed
            onClicked: navigateToNext()

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
                opacity: nextArea.containsMouse || nextArea.pressed ? 0.9 : 0.5
                visible: nextArea.enabled

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

        Component {
            id: imageComponent

            Item {
                id: imageViewer

                property real minZoom: 1
                property real maxZoom: 4
                property real zoomScale: 1
                property bool zoomed: zoomScale > 1.01
                property real imageAspectRatio: photoImage.implicitWidth > 0 && photoImage.implicitHeight > 0 ? photoImage.implicitWidth / photoImage.implicitHeight : 1
                property real fittedWidth: {
                    if (photoImage.status !== Image.Ready || photoImage.implicitWidth <= 0 || photoImage.implicitHeight <= 0)
                        return width;

                    return Math.min(width, height * imageAspectRatio);
                }
                property real fittedHeight: {
                    if (photoImage.status !== Image.Ready || photoImage.implicitWidth <= 0 || photoImage.implicitHeight <= 0)
                        return height;

                    return Math.min(height, width / imageAspectRatio);
                }

                function clamp(value, minValue, maxValue) {
                    return Math.max(minValue, Math.min(value, maxValue));
                }

                function ensureBounds() {
                    var maxX = Math.max(0, imageFlick.contentWidth - imageFlick.width);
                    var maxY = Math.max(0, imageFlick.contentHeight - imageFlick.height);
                    imageFlick.contentX = clamp(imageFlick.contentX, 0, maxX);
                    imageFlick.contentY = clamp(imageFlick.contentY, 0, maxY);
                }

                function panBy(deltaX, deltaY) {
                    var maxX = Math.max(0, imageFlick.contentWidth - imageFlick.width);
                    var maxY = Math.max(0, imageFlick.contentHeight - imageFlick.height);
                    imageFlick.contentX = clamp(imageFlick.contentX - deltaX, 0, maxX);
                    imageFlick.contentY = clamp(imageFlick.contentY - deltaY, 0, maxY);
                }

                function resetZoom() {
                    zoomScale = 1;
                    imageFlick.contentX = 0;
                    imageFlick.contentY = 0;
                }

                anchors.fill: parent
                onWidthChanged: {
                    if (zoomed)
                        ensureBounds();
                    else
                        resetZoom();
                }
                onHeightChanged: {
                    if (zoomed)
                        ensureBounds();
                    else
                        resetZoom();
                }

                Connections {
                    function onFilePathChanged() {
                        imageViewer.resetZoom();
                    }

                    target: photoDetailPage
                }

                Flickable {
                    id: imageFlick

                    anchors.fill: parent
                    clip: true
                    interactive: false
                    boundsBehavior: Flickable.StopAtBounds
                    contentWidth: Math.max(width, imageViewer.fittedWidth * imageViewer.zoomScale)
                    contentHeight: Math.max(height, imageViewer.fittedHeight * imageViewer.zoomScale)

                    Item {
                        id: zoomContent

                        x: width < imageFlick.width ? (imageFlick.width - width) / 2 : 0
                        y: height < imageFlick.height ? (imageFlick.height - height) / 2 : 0
                        width: imageViewer.fittedWidth * imageViewer.zoomScale
                        height: imageViewer.fittedHeight * imageViewer.zoomScale

                        Image {
                            id: photoImage

                            anchors.fill: parent
                            source: photoDetailPage.filePath ? "file://" + photoDetailPage.filePath : ""
                            fillMode: Image.PreserveAspectFit
                            cache: false
                            asynchronous: true
                            sourceSize.width: imageViewer.width > 0 ? imageViewer.width : 1920
                            sourceSize.height: imageViewer.height > 0 ? imageViewer.height : 1080
                        }

                    }

                }

                PinchArea {
                    id: pinchArea

                    property real startZoom: 1

                    anchors.fill: parent
                    enabled: photoImage.status === Image.Ready
                    onPinchStarted: {
                        startZoom = imageViewer.zoomScale;
                    }
                    onPinchUpdated: {
                        var previousContentWidth = imageFlick.contentWidth;
                        var previousContentHeight = imageFlick.contentHeight;
                        var centerRatioX = (imageFlick.contentX + pinch.center.x) / Math.max(1, previousContentWidth);
                        var centerRatioY = (imageFlick.contentY + pinch.center.y) / Math.max(1, previousContentHeight);
                        imageViewer.zoomScale = imageViewer.clamp(startZoom * pinch.scale, imageViewer.minZoom, imageViewer.maxZoom);
                        imageFlick.contentX = centerRatioX * imageFlick.contentWidth - pinch.center.x;
                        imageFlick.contentY = centerRatioY * imageFlick.contentHeight - pinch.center.y;
                        imageViewer.ensureBounds();
                    }
                    onPinchFinished: {
                        if (imageViewer.zoomed)
                            imageViewer.ensureBounds();
                        else
                            imageViewer.resetZoom();
                    }

                    MouseArea {
                        id: panArea

                        property real lastX: 0
                        property real lastY: 0

                        anchors.fill: parent
                        enabled: imageViewer.zoomed && !pinchArea.pinch.active
                        preventStealing: true
                        onPressed: {
                            lastX = mouse.x;
                            lastY = mouse.y;
                        }
                        onPositionChanged: {
                            if (!pressed)
                                return ;

                            imageViewer.panBy(mouse.x - lastX, mouse.y - lastY);
                            lastX = mouse.x;
                            lastY = mouse.y;
                        }
                    }

                }

                ActivityIndicator {
                    anchors.centerIn: parent
                    running: photoDetailPage.isLoading || photoImage.status === Image.Loading
                    visible: running
                }

                Label {
                    anchors.centerIn: parent
                    text: i18n.tr("Failed to load image")
                    visible: !photoDetailPage.isLoading && photoImage.status === Image.Error && photoDetailPage.filePath !== ""
                }

            }

        }

        Component {
            id: videoComponent

            Item {
                anchors.fill: parent

                Video {
                    id: videoPlayer

                    anchors.fill: parent
                    source: photoDetailPage.filePath ? "file://" + photoDetailPage.filePath : ""
                    fillMode: VideoOutput.PreserveAspectFit

                    MouseArea {
                        anchors.fill: parent
                        onClicked: {
                            if (videoPlayer.playbackState === MediaPlayer.PlayingState)
                                videoPlayer.pause();
                            else
                                videoPlayer.play();
                        }
                    }

                }

                Icon {
                    id: playPauseIcon

                    anchors.centerIn: parent
                    width: units.gu(8)
                    height: width
                    name: videoPlayer.playbackState === MediaPlayer.PlayingState ? "media-playback-pause" : "media-playback-start"
                    color: "white"
                    opacity: 0.8
                    visible: videoPlayer.playbackState !== MediaPlayer.PlayingState

                    MouseArea {
                        anchors.fill: parent
                        onClicked: videoPlayer.play()
                    }

                }

                ActivityIndicator {
                    anchors.centerIn: parent
                    running: photoDetailPage.isLoading
                    visible: running
                }

                Label {
                    anchors.centerIn: parent
                    text: i18n.tr("Failed to load video")
                    visible: !photoDetailPage.isLoading && videoPlayer.status === MediaPlayer.InvalidMedia && photoDetailPage.filePath !== ""
                }

                Row {
                    spacing: units.gu(2)
                    visible: videoPlayer.hasVideo

                    anchors {
                        bottom: parent.bottom
                        horizontalCenter: parent.horizontalCenter
                        margins: units.gu(2)
                    }

                    Icon {
                        width: units.gu(4)
                        height: width
                        name: videoPlayer.playbackState === MediaPlayer.PlayingState ? "media-playback-pause" : "media-playback-start"
                        color: "white"

                        MouseArea {
                            anchors.fill: parent
                            onClicked: {
                                if (videoPlayer.playbackState === MediaPlayer.PlayingState)
                                    videoPlayer.pause();
                                else
                                    videoPlayer.play();
                            }
                        }

                    }

                    Slider {
                        id: progressSlider

                        width: units.gu(20)
                        minimumValue: 0
                        maximumValue: videoPlayer.duration
                        value: videoPlayer.position
                        live: false
                        onValueChanged: {
                            if (pressed)
                                videoPlayer.seek(value);

                        }
                    }

                }

            }

        }

    }

    BottomBar {
        id: bottomBar

        anchors {
            left: parent.left
            right: parent.right
            bottom: parent.bottom
        }

        IconButton {
            id: shareButton

            iconName: "share"
            text: i18n.tr("Share")
            onClicked: {
                if (photoDetailPage.photoId && photoDetailPage.photoId !== "") {
                    shareButton.enabled = false;
                    python.call('immich_client.original', [photoDetailPage.photoId], function(result) {
                        shareButton.enabled = true;
                        if (result && result !== "")
                            pageStack.push(sharePage, {
                            "imageUrl": "file://" + result
                        });

                    });
                }
            }
        }

        IconButton {
            iconName: photoDetailPage.isFavorite ? "starred" : "non-starred"
            text: i18n.tr("Favorite")
            onClicked: {
                var newFavoriteState = !photoDetailPage.isFavorite;
                photoDetailPage.isFavorite = newFavoriteState;
                python.call('immich_client.favorite', [photoDetailPage.photoId, newFavoriteState], function(result) {
                });
            }
        }

        IconButton {
            iconName: photoDetailPage.isArchived ? "reset" : "save"
            text: photoDetailPage.isArchived ? i18n.tr("Unarchive") : i18n.tr("Archive")
            onClicked: {
                var methodName = photoDetailPage.isArchived ? 'immich_client.unarchive' : 'immich_client.archive';
                python.call(methodName, [photoDetailPage.photoId], function(result) {
                    python.call('immich_client.clear_cache', [], function() {
                        pageStack.clear();
                        pageStack.push(Qt.resolvedUrl("GalleryPage.qml"));
                    });
                });
            }
        }

        IconButton {
            iconName: "delete"
            text: i18n.tr("Trash")
            visible: !photoDetailPage.isDeleted
            onClicked: {
                python.call('immich_client.delete', [photoDetailPage.photoId], function(result) {
                    python.call('immich_client.clear_cache', [], function() {
                        pageStack.clear();
                        pageStack.push(Qt.resolvedUrl("GalleryPage.qml"));
                    });
                });
            }
        }

        IconButton {
            iconName: "view-restore"
            text: i18n.tr("Restore")
            visible: photoDetailPage.isDeleted
            onClicked: {
                python.call('immich_client.undelete', [photoDetailPage.photoId], function(result) {
                    python.call('immich_client.clear_cache', [], function() {
                        pageStack.clear();
                        pageStack.push(Qt.resolvedUrl("GalleryPage.qml"));
                    });
                });
            }
        }

        IconButton {
            iconName: "toolkit_cross"
            text: i18n.tr("Delete")
            visible: photoDetailPage.isDeleted
            onClicked: {
                python.call('immich_client.permanently_delete', [photoDetailPage.photoId], function(result) {
                    python.call('immich_client.clear_cache', [], function() {
                        pageStack.clear();
                        pageStack.push(Qt.resolvedUrl("GalleryPage.qml"));
                    });
                });
            }
        }

    }

    Component {
        id: sharePage

        Page {
            id: sharePageInstance

            property string imageUrl: ""
            property var activeTransfer

            ContentPeerPicker {
                id: peerPicker

                contentType: ContentType.Pictures
                handler: ContentHandler.Share
                onPeerSelected: {
                    sharePageInstance.activeTransfer = peer.request();
                    if (sharePageInstance.activeTransfer) {
                        sharePageInstance.activeTransfer.items = [contentItem];
                        sharePageInstance.activeTransfer.state = ContentTransfer.Charged;
                        pageStack.pop();
                    }
                }
                onCancelPressed: {
                    if (sharePageInstance.activeTransfer)
                        sharePageInstance.activeTransfer.state = ContentTransfer.Aborted;

                    pageStack.pop();
                }

                anchors {
                    top: shareHeader.bottom
                    left: parent.left
                    right: parent.right
                    bottom: parent.bottom
                }

            }

            ContentItem {
                id: contentItem

                url: sharePageInstance.imageUrl
                name: photoDetailPage.photoName
            }

            header: PageHeader {
                id: shareHeader

                title: i18n.tr("Share")
                leadingActionBar.actions: [
                    Action {
                        iconName: "back"
                        onTriggered: {
                            if (sharePageInstance.activeTransfer)
                                sharePageInstance.activeTransfer.state = ContentTransfer.Aborted;

                            pageStack.pop();
                        }
                    }
                ]
            }

        }

    }

    header: AppHeader {
        id: pageHeader

        pageTitle: photoDetailPage.photoName
        isRootPage: false
        showSettingsButton: false
    }

}
