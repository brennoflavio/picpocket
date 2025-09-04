/*
 * Copyright (C) 2025  Brenno Flávio de Almeida
 *
 * This program is free software: you can redistribute it and/or modify
 * it under the terms of the GNU General Public License as published by
 * the Free Software Foundation; version 3.
 *
 * picpocket is distributed in the hope that it will be useful,
 * but WITHOUT ANY WARRANTY; without even the implied warranty of
 * MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
 * GNU General Public License for more details.
 *
 * You should have received a copy of the GNU General Public License
 * along with this program.  If not, see <http://www.gnu.org/licenses/>.
 */
import QtQuick 2.7
import Lomiri.Components 1.3
import QtQuick.Layouts 1.3
import Lomiri.Content 1.3
import io.thp.pyotherside 1.4
import "lib"

Page {
    id: galleryPage

    header: AppHeader {
        id: header
        pageTitle: i18n.tr('PicPocket')
        iconName: picturePicker.visible ? "" : "stock_image"
        showBackButton: picturePicker.visible
        showSettingsButton: !picturePicker.visible
        onBackClicked: {
            picturePicker.visible = false;
        }
        onSettingsClicked: {
            pageStack.push(Qt.resolvedUrl("ConfigurationPage.qml"));
        }
    }

    property var galleryData: ({
            "month": "",
            "days": [],
            "previous": "",
            "next": ""
        })

    property var memoriesData: []

    function loadTimeline(hint) {
        loadingToast.showing = true;
        loadingToast.message = i18n.tr("Loading photos...");
        var args = hint ? [hint] : [""];

        // Load memories
        python.call('immich_client.memories', [], function (memoriesResult) {
                if (memoriesResult && memoriesResult.memories) {
                    // Convert thumbnail_url to thumbnailUrl for QML
                    galleryPage.memoriesData = memoriesResult.memories.map(function (memory) {
                            return {
                                "title": memory.title,
                                "thumbnailUrl": memory.thumbnail_url || "",
                                "id": memory.first_image_id || ""
                            };
                        });
                }
            });

        // Load timeline
        python.call('immich_client.timeline', args, function (result) {
                galleryPage.galleryData = result;
                loadingToast.showing = false;
            });
    }

    Python {
        id: python

        Component.onCompleted: {
            addImportPath(Qt.resolvedUrl('../src/'));
            importModule('immich_client', function () {
                    loadTimeline("");
                });
        }

        onError: {
            loadingToast.showing = false;
        }
    }

    Flickable {
        id: flickable
        anchors {
            top: header.bottom
            left: parent.left
            right: parent.right
            bottom: actionBar.top
        }
        contentHeight: memoriesColumn.height
        clip: true

        PullToRefresh {
            id: pullToRefresh
            parent: flickable
            target: flickable
            refreshing: loadingToast.showing
            onRefresh: {
                python.call('immich_client.clear_cache', [], function () {
                        loadTimeline("");
                    });
            }
        }

        Column {
            id: memoriesColumn
            width: parent.width

            Memories {
                id: memories
                width: parent.width
                visible: !picturePicker.visible
                memoriesData: galleryPage.memoriesData

                onMemoryClicked: {
                    pageStack.push(Qt.resolvedUrl("PhotoDetail.qml"), {
                            "previewType": "memory",
                            "filePath": memoryData.thumbnailUrl || "",
                            "photoId": memoryData.id || ""
                        });
                }
            }

            Gallery {
                id: gallery
                width: parent.width
                month: galleryPage.galleryData.month
                days: galleryPage.galleryData.days

                onItemClicked: {
                    pageStack.push(Qt.resolvedUrl("PhotoDetail.qml"), {
                            "previewType": "timeline",
                            "filePath": imageData.filePath,
                            "photoId": imageData.id || ""
                        });
                }
            }
        }
    }

    Rectangle {
        id: actionBar
        anchors {
            left: parent.left
            right: parent.right
            bottom: parent.bottom
        }
        height: units.gu(8)
        color: theme.palette.normal.background

        Rectangle {
            anchors {
                left: parent.left
                right: parent.right
                top: parent.top
            }
            height: units.dp(1)
            color: theme.palette.normal.base
        }

        Item {
            anchors.fill: parent

            AbstractButton {
                id: previousButton
                anchors {
                    left: parent.left
                    leftMargin: units.gu(1)
                    top: parent.top
                    bottom: parent.bottom
                }
                width: units.gu(6)
                visible: galleryPage.galleryData.previous !== undefined && galleryPage.galleryData.previous !== ""
                enabled: galleryPage.galleryData.previous !== "" && !loadingToast.showing

                Icon {
                    anchors.centerIn: parent
                    width: units.gu(3)
                    height: width
                    name: "go-previous"
                    color: previousButton.enabled ? theme.palette.normal.foregroundText : theme.palette.disabled.foregroundText
                }

                onClicked: {
                    if (galleryPage.galleryData.previous) {
                        loadTimeline(galleryPage.galleryData.previous);
                        flickable.contentY = 0;
                    }
                }
            }

            Row {
                anchors.centerIn: parent
                spacing: units.gu(4)
                height: parent.height

                AbstractButton {
                    id: albumsButton
                    width: units.gu(6)
                    height: parent.height
                    enabled: !loadingToast.showing

                    Column {
                        anchors.centerIn: parent
                        spacing: units.gu(0.5)

                        Icon {
                            width: units.gu(3)
                            height: width
                            anchors.horizontalCenter: parent.horizontalCenter
                            name: "view-grid-symbolic"
                            color: albumsButton.enabled ? theme.palette.normal.foregroundText : theme.palette.disabled.foregroundText
                        }

                        Label {
                            fontSize: "small"
                            anchors.horizontalCenter: parent.horizontalCenter
                            text: i18n.tr("Albums")
                        }
                    }

                    onClicked: {
                        pageStack.push(Qt.resolvedUrl("AlbumsPage.qml"));
                    }
                }

                AbstractButton {
                    id: uploadButton
                    width: units.gu(6)
                    height: parent.height
                    enabled: !loadingToast.showing

                    Column {
                        anchors.centerIn: parent
                        spacing: units.gu(0.5)

                        Icon {
                            width: units.gu(3)
                            height: width
                            anchors.horizontalCenter: parent.horizontalCenter
                            name: "keyboard-caps-disabled"
                            color: uploadButton.enabled ? theme.palette.normal.foregroundText : theme.palette.disabled.foregroundText
                        }

                        Label {
                            fontSize: "small"
                            anchors.horizontalCenter: parent.horizontalCenter
                            text: i18n.tr("Upload")
                        }
                    }

                    onClicked: {
                        picturePicker.visible = true;
                    }
                }
            }

            AbstractButton {
                id: nextButton
                anchors {
                    right: parent.right
                    rightMargin: units.gu(1)
                    top: parent.top
                    bottom: parent.bottom
                }
                width: units.gu(6)
                visible: galleryPage.galleryData.next !== undefined && galleryPage.galleryData.next !== ""
                enabled: galleryPage.galleryData.next !== "" && !loadingToast.showing

                Icon {
                    anchors.centerIn: parent
                    width: units.gu(3)
                    height: width
                    name: "go-next"
                    color: nextButton.enabled ? theme.palette.normal.foregroundText : theme.palette.disabled.foregroundText
                }

                onClicked: {
                    if (galleryPage.galleryData.next) {
                        loadTimeline(galleryPage.galleryData.next);
                        flickable.contentY = 0;
                    }
                }
            }
        }
    }

    AbstractButton {
        id: scrollToTopButton
        anchors {
            right: parent.right
            rightMargin: units.gu(2)
            bottom: actionBar.top
            bottomMargin: units.gu(2)
        }
        width: units.gu(6)
        height: units.gu(6)
        visible: flickable.contentY > units.gu(10)
        opacity: visible ? 1.0 : 0.0

        Behavior on opacity  {
            NumberAnimation {
                duration: 200
            }
        }

        onClicked: {
            flickable.contentY = 0;
        }

        Rectangle {
            anchors.fill: parent
            radius: width / 2
            color: theme.palette.normal.foreground
            opacity: 0.9

            Icon {
                anchors.centerIn: parent
                width: units.gu(3)
                height: units.gu(3)
                name: "up"
                color: theme.palette.normal.foregroundText
            }
        }
    }

    LoadToast {
        id: loadingToast
        showSpinner: true
    }

    ContentStore {
        id: contentStore
        scope: ContentScope.App
    }

    ContentPeerPicker {
        id: picturePicker
        visible: false
        contentType: ContentType.Pictures
        handler: ContentHandler.Source

        property int uploadIndex: 0
        property int totalFiles: 0
        property var filesToUpload: []

        function uploadNextFile() {
            if (uploadIndex < filesToUpload.length) {
                var filePath = filesToUpload[uploadIndex];
                loadingToast.message = i18n.tr("Uploading %1 of %2...").arg(uploadIndex + 1).arg(totalFiles);
                python.call('immich_client.upload_immich_photo', [filePath], function (result) {
                        uploadIndex++;
                        if (uploadIndex < filesToUpload.length) {
                            uploadNextFile();
                        } else {
                            loadingToast.showing = false;
                            loadTimeline("");
                            uploadIndex = 0;
                            totalFiles = 0;
                            filesToUpload = [];
                        }
                    });
            }
        }

        onPeerSelected: {
            var transfer = peer.request(contentStore);
            transfer.selectionType = ContentTransfer.Multiple;
            transfer.stateChanged.connect(function () {
                    if (transfer.state === ContentTransfer.Charged) {
                        if (transfer.items.length > 0) {
                            filesToUpload = [];
                            for (var i = 0; i < transfer.items.length; i++) {
                                var fileUrl = transfer.items[i].url.toString();
                                var filePath = fileUrl.replace("file://", "");
                                filesToUpload.push(filePath);
                            }
                            totalFiles = filesToUpload.length;
                            uploadIndex = 0;
                            if (totalFiles === 1) {
                                loadingToast.message = i18n.tr("Uploading photo...");
                            } else {
                                loadingToast.message = i18n.tr("Uploading %1 of %2...").arg(1).arg(totalFiles);
                            }
                            loadingToast.showing = true;
                            uploadNextFile();
                        }
                        picturePicker.visible = false;
                    }
                });
        }

        onCancelPressed: {
            picturePicker.visible = false;
        }
    }
}
