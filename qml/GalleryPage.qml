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
import Lomiri.Components.Popups 1.3
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
            "title": "",
            "images": [],
            "previous": "",
            "next": ""
        })

    property var memoriesData: []
    property var selectedImages: []

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

    Memories {
        id: memories
        anchors {
            top: header.bottom
            left: parent.left
            right: parent.right
        }
        height: memoriesData.length > 0 ? units.gu(15) : 0
        memoriesData: galleryPage.memoriesData
        visible: memoriesData.length > 0

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
        anchors {
            top: memories.visible ? memories.bottom : header.bottom
            left: parent.left
            right: parent.right
            bottom: bottomBar.top
        }
        defaultTitle: galleryPage.galleryData.title
        images: galleryPage.galleryData.images

        onImageClicked: {
            pageStack.push(Qt.resolvedUrl("PhotoDetail.qml"), {
                    "previewType": "timeline",
                    "filePath": imageData.filePath,
                    "photoId": imageData.id || ""
                });
        }

        onSelectionModeExited: {
            galleryPage.selectedImages = [];
        }

        onSelectionChanged: function (images) {
            galleryPage.selectedImages = images;
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
                    gallery.scrollPosition = 0;
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
                    gallery.scrollPosition = 0;
                }
            }
        }

        IconButton {
            iconName: "view-grid-symbolic"
            text: i18n.tr("Albums")
            enabled: !loadingToast.showing
            opacity: enabled ? 1.0 : 0.5
            visible: !gallery.selectionMode
            onClicked: {
                pageStack.push(Qt.resolvedUrl("AlbumsPage.qml"));
            }
        }

        IconButton {
            iconName: "view-list-symbolic"
            text: i18n.tr("Library")
            enabled: !loadingToast.showing
            opacity: enabled ? 1.0 : 0.5
            visible: !gallery.selectionMode
            onClicked: {
                pageStack.push(Qt.resolvedUrl("LibraryPage.qml"));
            }
        }

        IconButton {
            iconName: "keyboard-caps-disabled"
            text: i18n.tr("Upload")
            enabled: !loadingToast.showing
            opacity: enabled ? 1.0 : 0.5
            visible: !gallery.selectionMode
            onClicked: {
                pageStack.push(uploadPickerPage);
            }
        }

        IconButton {
            iconName: "view-refresh"
            text: i18n.tr("Refresh")
            enabled: !loadingToast.showing
            opacity: enabled ? 1.0 : 0.5
            visible: !gallery.selectionMode
            onClicked: {
                python.call('immich_client.clear_cache', [], function () {
                        loadTimeline("");
                    });
            }
        }

        IconButton {
            iconName: "image-x-generic-symbolic"
            text: i18n.tr("Add to Album")
            enabled: galleryPage.selectedImages.length > 0 && !loadingToast.showing
            opacity: enabled ? 1.0 : 0.5
            visible: gallery.selectionMode
            onClicked: {
                var imageIds = [];
                for (var i = 0; i < galleryPage.selectedImages.length; i++) {
                    if (galleryPage.selectedImages[i].id) {
                        imageIds.push(galleryPage.selectedImages[i].id);
                    }
                }
                pageStack.push(Qt.resolvedUrl("AlbumSelectorPage.qml"), {
                        "selectedAssetIds": imageIds
                    });
            }
        }

        IconButton {
            iconName: "save"
            text: i18n.tr("Archive")
            enabled: galleryPage.selectedImages.length > 0 && !loadingToast.showing
            opacity: enabled ? 1.0 : 0.5
            visible: gallery.selectionMode
            onClicked: {
                loadingToast.showing = true;
                loadingToast.message = i18n.tr("Archiving photos...");
                var imageIds = [];
                for (var i = 0; i < galleryPage.selectedImages.length; i++) {
                    if (galleryPage.selectedImages[i].id) {
                        imageIds.push(galleryPage.selectedImages[i].id);
                    }
                }
                python.call('immich_client.archive', imageIds, function (result) {
                        gallery.exitSelectionMode();
                        python.call('immich_client.clear_cache', [], function () {
                                loadTimeline("");
                            });
                    });
            }
        }

        IconButton {
            iconName: "delete"
            text: i18n.tr("Trash")
            enabled: galleryPage.selectedImages.length > 0 && !loadingToast.showing
            opacity: enabled ? 1.0 : 0.5
            visible: gallery.selectionMode
            onClicked: {
                loadingToast.showing = true;
                loadingToast.message = i18n.tr("Trashing photos...");
                var imageIds = [];
                for (var i = 0; i < galleryPage.selectedImages.length; i++) {
                    if (galleryPage.selectedImages[i].id) {
                        imageIds.push(galleryPage.selectedImages[i].id);
                    }
                }
                python.call('immich_client.delete', imageIds, function (result) {
                        gallery.exitSelectionMode();
                        python.call('immich_client.clear_cache', [], function () {
                                loadTimeline("");
                            });
                    });
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

            property var filesToUpload: []

            function uploadFiles() {
                uploadLoadingToast.showing = true;
                uploadLoadingToast.message = i18n.tr("Uploading photos...");
                python.call('immich_client.upload_immich_photo', [filesToUpload], function (result) {
                        uploadLoadingToast.showing = false;
                        var dialogTitle = result.success ? i18n.tr("Upload Successful") : i18n.tr("Upload Failed");
                        var dialogMessage = result.message || i18n.tr("Upload completed");
                        PopupUtils.open(uploadResultDialog, uploadPageInstance, {
                                "title": dialogTitle,
                                "text": dialogMessage
                            });
                        if (result.success) {
                            python.call('immich_client.clear_cache', [], function () {
                                    loadTimeline("");
                                });
                        }
                        filesToUpload = [];
                    });
            }

            Component {
                id: uploadResultDialog
                Dialog {
                    id: dialogue
                    property alias title: dialogueTitle.text
                    property alias text: dialogueText.text

                    Label {
                        id: dialogueTitle
                        fontSize: "large"
                        font.bold: true
                    }

                    Label {
                        id: dialogueText
                        wrapMode: Text.WordWrap
                    }

                    Button {
                        text: i18n.tr("OK")
                        onClicked: {
                            PopupUtils.close(dialogue);
                            pageStack.pop();
                        }
                    }
                }
            }

            LoadToast {
                id: uploadLoadingToast
                showing: false
                message: ""
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
                                    uploadPageInstance.uploadFiles();
                                }
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
