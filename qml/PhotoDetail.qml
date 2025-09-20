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
import Lomiri.Components 1.3
import Lomiri.Components.Popups 1.3
import QtQuick.Layouts 1.12
import Lomiri.Content 1.3
import QtMultimedia 5.12
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
    property string previewType: "timeline"
    property string albumId: ""
    property string personId: ""
    property string locationId: ""

    header: AppHeader {
        id: pageHeader
        pageTitle: photoDetailPage.photoName
        isRootPage: false
        showSettingsButton: false
    }

    Python {
        id: python

        Component.onCompleted: {
            addImportPath(Qt.resolvedUrl('../src/'));
            importModule('immich_client', function () {
                    if (photoId && photoId !== "") {
                        loadPhotoDetails();
                    }
                });
        }

        onError: {
            photoDetailPage.isLoading = false;
        }
    }

    function loadPhotoDetails() {
        photoDetailPage.isLoading = true;
        python.call('immich_client.preview', [photoId, previewType, albumId, personId, locationId], function (result) {
                if (result) {
                    if (result.filePath) {
                        photoDetailPage.filePath = result.filePath;
                    }
                    if (result.name) {
                        photoDetailPage.photoName = result.name;
                    }
                    if (result.file_type) {
                        photoDetailPage.fileType = result.file_type;
                    }
                    photoDetailPage.previousId = result.previous || "";
                    photoDetailPage.nextId = result.next || "";
                    photoDetailPage.isFavorite = result.favorite || false;
                }
                photoDetailPage.isLoading = false;
            });
    }

    function navigateToPrevious() {
        if (photoDetailPage.previousId && photoDetailPage.previousId !== "") {
            photoDetailPage.photoId = photoDetailPage.previousId;
            loadPhotoDetails();
        }
    }

    function navigateToNext() {
        if (photoDetailPage.nextId && photoDetailPage.nextId !== "") {
            photoDetailPage.photoId = photoDetailPage.nextId;
            loadPhotoDetails();
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
            anchors.fill: parent
            property real startX: 0
            property bool swiping: false
            z: -1

            onPressed: {
                startX = mouse.x;
                swiping = true;
            }

            onReleased: {
                if (swiping) {
                    var diff = mouse.x - startX;
                    if (Math.abs(diff) > units.gu(10)) {
                        if (diff > 0 && photoDetailPage.previousId !== "") {
                            navigateToPrevious();
                        } else if (diff < 0 && photoDetailPage.nextId !== "") {
                            navigateToNext();
                        }
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
            anchors {
                left: parent.left
                top: parent.top
                bottom: parent.bottom
            }
            width: units.gu(8)
            enabled: photoDetailPage.previousId !== ""
            onClicked: navigateToPrevious()

            Rectangle {
                anchors.fill: parent
                color: theme.palette.normal.foreground
                opacity: previousArea.pressed ? 0.3 : 0
                Behavior on opacity  {
                    NumberAnimation {
                        duration: 100
                    }
                }
            }

            Icon {
                anchors {
                    left: parent.left
                    leftMargin: units.gu(1)
                    verticalCenter: parent.verticalCenter
                }
                width: units.gu(4)
                height: width
                name: "go-previous"
                color: "white"
                opacity: previousArea.containsMouse || previousArea.pressed ? 0.9 : 0.5
                visible: photoDetailPage.previousId !== ""
                Behavior on opacity  {
                    NumberAnimation {
                        duration: 100
                    }
                }
            }
        }

        MouseArea {
            id: nextArea
            anchors {
                right: parent.right
                top: parent.top
                bottom: parent.bottom
            }
            width: units.gu(8)
            enabled: photoDetailPage.nextId !== ""
            onClicked: navigateToNext()

            Rectangle {
                anchors.fill: parent
                color: theme.palette.normal.foreground
                opacity: nextArea.pressed ? 0.3 : 0
                Behavior on opacity  {
                    NumberAnimation {
                        duration: 100
                    }
                }
            }

            Icon {
                anchors {
                    right: parent.right
                    rightMargin: units.gu(1)
                    verticalCenter: parent.verticalCenter
                }
                width: units.gu(4)
                height: width
                name: "go-next"
                color: "white"
                opacity: nextArea.containsMouse || nextArea.pressed ? 0.9 : 0.5
                visible: photoDetailPage.nextId !== ""
                Behavior on opacity  {
                    NumberAnimation {
                        duration: 100
                    }
                }
            }
        }

        Component {
            id: imageComponent

            Image {
                id: photoImage
                anchors.fill: parent
                source: photoDetailPage.filePath ? "file://" + photoDetailPage.filePath : ""
                fillMode: Image.PreserveAspectFit
                cache: false
                asynchronous: true
                sourceSize.width: parent.width > 0 ? parent.width : 1920
                sourceSize.height: parent.height > 0 ? parent.height : 1080

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
                            if (videoPlayer.playbackState === MediaPlayer.PlayingState) {
                                videoPlayer.pause();
                            } else {
                                videoPlayer.play();
                            }
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
                    anchors {
                        bottom: parent.bottom
                        horizontalCenter: parent.horizontalCenter
                        margins: units.gu(2)
                    }
                    spacing: units.gu(2)
                    visible: videoPlayer.hasVideo

                    Icon {
                        width: units.gu(4)
                        height: width
                        name: videoPlayer.playbackState === MediaPlayer.PlayingState ? "media-playback-pause" : "media-playback-start"
                        color: "white"

                        MouseArea {
                            anchors.fill: parent
                            onClicked: {
                                if (videoPlayer.playbackState === MediaPlayer.PlayingState) {
                                    videoPlayer.pause();
                                } else {
                                    videoPlayer.play();
                                }
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
                            if (pressed) {
                                videoPlayer.seek(value);
                            }
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
                    python.call('immich_client.original', [photoDetailPage.photoId], function (result) {
                            shareButton.enabled = true;
                            if (result && result !== "") {
                                pageStack.push(sharePage, {
                                        "imageUrl": "file://" + result
                                    });
                            }
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
                python.call('immich_client.favorite', [photoDetailPage.photoId, newFavoriteState], function (result) {});
            }
        }

        IconButton {
            iconName: "save"
            text: i18n.tr("Archive")
            onClicked: {
                python.call('immich_client.archive', [photoDetailPage.photoId], function (result) {
                        pageStack.clear();
                        pageStack.push(Qt.resolvedUrl("GalleryPage.qml"));
                    });
            }
        }

        IconButton {
            iconName: "delete"
            text: i18n.tr("Delete")
            onClicked: {
                python.call('immich_client.delete', [photoDetailPage.photoId], function (result) {
                        pageStack.clear();
                        pageStack.push(Qt.resolvedUrl("GalleryPage.qml"));
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

            header: PageHeader {
                id: shareHeader
                title: i18n.tr("Share")
                leadingActionBar.actions: [
                    Action {
                        iconName: "back"
                        onTriggered: {
                            if (sharePageInstance.activeTransfer) {
                                sharePageInstance.activeTransfer.state = ContentTransfer.Aborted;
                            }
                            pageStack.pop();
                        }
                    }
                ]
            }

            ContentPeerPicker {
                id: peerPicker
                anchors {
                    top: shareHeader.bottom
                    left: parent.left
                    right: parent.right
                    bottom: parent.bottom
                }
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
                    if (sharePageInstance.activeTransfer) {
                        sharePageInstance.activeTransfer.state = ContentTransfer.Aborted;
                    }
                    pageStack.pop();
                }
            }

            ContentItem {
                id: contentItem
                url: sharePageInstance.imageUrl
                name: photoDetailPage.photoName
            }
        }
    }
}
