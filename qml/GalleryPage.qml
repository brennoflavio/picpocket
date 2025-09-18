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
import "ut_components"

Page {
    id: galleryPage

    header: AppHeader {
        id: header
        pageTitle: i18n.tr('PicPocket')
        isRootPage: true
        appIconName: "stock_image"
        showSettingsButton: true
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
            bottom: bottomBar.top
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

    BottomBar {
        id: bottomBar
        anchors {
            left: parent.left
            right: parent.right
            bottom: parent.bottom
        }

        leftButton: IconButton {
            iconName: "go-previous"
            visible: galleryPage.galleryData.previous !== undefined && galleryPage.galleryData.previous !== ""
            enabled: galleryPage.galleryData.previous !== "" && !loadingToast.showing
            opacity: enabled ? 1.0 : 0.5
            onClicked: {
                if (galleryPage.galleryData.previous) {
                    loadTimeline(galleryPage.galleryData.previous);
                    flickable.contentY = 0;
                }
            }
        }

        rightButton: IconButton {
            iconName: "go-next"
            visible: galleryPage.galleryData.next !== undefined && galleryPage.galleryData.next !== ""
            enabled: galleryPage.galleryData.next !== "" && !loadingToast.showing
            opacity: enabled ? 1.0 : 0.5
            onClicked: {
                if (galleryPage.galleryData.next) {
                    loadTimeline(galleryPage.galleryData.next);
                    flickable.contentY = 0;
                }
            }
        }

        IconButton {
            iconName: "view-grid-symbolic"
            text: i18n.tr("Albums")
            enabled: !loadingToast.showing
            opacity: enabled ? 1.0 : 0.5
            onClicked: {
                pageStack.push(Qt.resolvedUrl("AlbumsPage.qml"));
            }
        }

        IconButton {
            iconName: "view-list-symbolic"
            text: i18n.tr("Library")
            enabled: !loadingToast.showing
            opacity: enabled ? 1.0 : 0.5
            onClicked: {
                pageStack.push(Qt.resolvedUrl("LibraryPage.qml"));
            }
        }

        IconButton {
            iconName: "keyboard-caps-disabled"
            text: i18n.tr("Upload")
            enabled: !loadingToast.showing
            opacity: enabled ? 1.0 : 0.5
            onClicked: {
                pageStack.push(uploadPickerPage);
            }
        }
    }

    AbstractButton {
        id: scrollToTopButton
        anchors {
            right: parent.right
            rightMargin: units.gu(2)
            bottom: bottomBar.top
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
        showing: false
        message: ""
    }

    ContentStore {
        id: contentStore
        scope: ContentScope.App
    }

    Component {
        id: uploadPickerPage

        Page {
            id: uploadPageInstance
            property var activeTransfer

            header: PageHeader {
                id: uploadHeader
                title: i18n.tr("Select Photos to Upload")
                leadingActionBar.actions: [
                    Action {
                        iconName: "back"
                        onTriggered: {
                            if (uploadPageInstance.activeTransfer) {
                                uploadPageInstance.activeTransfer.state = ContentTransfer.Aborted;
                            }
                            pageStack.pop();
                        }
                    }
                ]
            }

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
                                python.call('immich_client.clear_cache', [], function () {
                                        loadTimeline("");
                                    });
                                uploadIndex = 0;
                                totalFiles = 0;
                                filesToUpload = [];
                            }
                        });
                }
            }

            ContentPeerPicker {
                id: picturePicker
                anchors {
                    top: uploadHeader.bottom
                    left: parent.left
                    right: parent.right
                    bottom: parent.bottom
                }
                contentType: ContentType.Pictures
                handler: ContentHandler.Source

                onPeerSelected: {
                    uploadPageInstance.activeTransfer = peer.request(contentStore);
                    uploadPageInstance.activeTransfer.selectionType = ContentTransfer.Multiple;
                    uploadPageInstance.activeTransfer.stateChanged.connect(function () {
                            if (uploadPageInstance.activeTransfer.state === ContentTransfer.Charged) {
                                if (uploadPageInstance.activeTransfer.items.length > 0) {
                                    uploadPageInstance.filesToUpload = [];
                                    for (var i = 0; i < uploadPageInstance.activeTransfer.items.length; i++) {
                                        var fileUrl = uploadPageInstance.activeTransfer.items[i].url.toString();
                                        var filePath = fileUrl.replace("file://", "");
                                        uploadPageInstance.filesToUpload.push(filePath);
                                    }
                                    uploadPageInstance.totalFiles = uploadPageInstance.filesToUpload.length;
                                    uploadPageInstance.uploadIndex = 0;
                                    if (uploadPageInstance.totalFiles === 1) {
                                        loadingToast.message = i18n.tr("Uploading photo...");
                                    } else {
                                        loadingToast.message = i18n.tr("Uploading %1 of %2...").arg(1).arg(uploadPageInstance.totalFiles);
                                    }
                                    loadingToast.showing = true;
                                    uploadPageInstance.uploadNextFile();
                                }
                                pageStack.pop();
                            }
                        });
                }

                onCancelPressed: {
                    if (uploadPageInstance.activeTransfer) {
                        uploadPageInstance.activeTransfer.state = ContentTransfer.Aborted;
                    }
                    pageStack.pop();
                }
            }
        }
    }
}
