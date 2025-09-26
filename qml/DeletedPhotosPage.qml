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
import io.thp.pyotherside 1.4
import "lib"
import "ut_components"

Page {
    id: deletedPhotosPage

    header: AppHeader {
        id: header
        pageTitle: i18n.tr('Deleted Photos')
        isRootPage: false
        appIconName: "delete"
        showSettingsButton: false
    }

    property var galleryData: ({
            "title": "",
            "images": [],
            "previous": "",
            "next": ""
        })

    property var selectedImages: []

    function loadTimeline(hint) {
        loadingToast.showing = true;
        loadingToast.message = i18n.tr("Loading deleted photos...");
        var args = hint ? [hint] : [""];
        python.call('immich_client.deleted_timeline', args, function (result) {
                deletedPhotosPage.galleryData = result;
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

    Gallery {
        id: gallery
        anchors {
            top: header.bottom
            left: parent.left
            right: parent.right
            bottom: bottomBar.top
        }
        defaultTitle: deletedPhotosPage.galleryData.title
        images: deletedPhotosPage.galleryData.images

        onImageClicked: {
            pageStack.push(Qt.resolvedUrl("PhotoDetail.qml"), {
                    "previewType": "deleted",
                    "filePath": imageData.filePath,
                    "photoId": imageData.id || ""
                });
        }

        onSelectionModeExited: {
            deletedPhotosPage.selectedImages = [];
        }

        onSelectionChanged: function (images) {
            deletedPhotosPage.selectedImages = images;
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
            visible: deletedPhotosPage.galleryData.previous !== undefined && deletedPhotosPage.galleryData.previous !== ""
            enabled: deletedPhotosPage.galleryData.previous !== "" && !loadingToast.showing
            opacity: enabled ? 1.0 : 0.5
            onClicked: {
                if (deletedPhotosPage.galleryData.previous) {
                    loadTimeline(deletedPhotosPage.galleryData.previous);
                    gallery.scrollPosition = 0;
                }
            }
        }

        rightButton: IconButton {
            iconName: "go-next"
            visible: deletedPhotosPage.galleryData.next !== undefined && deletedPhotosPage.galleryData.next !== ""
            enabled: deletedPhotosPage.galleryData.next !== "" && !loadingToast.showing
            opacity: enabled ? 1.0 : 0.5
            onClicked: {
                if (deletedPhotosPage.galleryData.next) {
                    loadTimeline(deletedPhotosPage.galleryData.next);
                    gallery.scrollPosition = 0;
                }
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
            iconName: "view-restore"
            text: i18n.tr("Restore")
            enabled: deletedPhotosPage.selectedImages.length > 0 && !loadingToast.showing
            opacity: enabled ? 1.0 : 0.5
            visible: gallery.selectionMode
            onClicked: {
                loadingToast.showing = true;
                loadingToast.message = i18n.tr("Restoring photos...");
                var imageIds = [];
                for (var i = 0; i < deletedPhotosPage.selectedImages.length; i++) {
                    if (deletedPhotosPage.selectedImages[i].id) {
                        imageIds.push(deletedPhotosPage.selectedImages[i].id);
                    }
                }
                python.call('immich_client.undelete', imageIds, function (result) {
                        gallery.exitSelectionMode();
                        python.call('immich_client.clear_cache', [], function () {
                                loadTimeline("");
                            });
                    });
            }
        }

        IconButton {
            iconName: "toolkit_cross"
            text: i18n.tr("Delete")
            enabled: deletedPhotosPage.selectedImages.length > 0 && !loadingToast.showing
            opacity: enabled ? 1.0 : 0.5
            visible: gallery.selectionMode
            onClicked: {
                loadingToast.showing = true;
                loadingToast.message = i18n.tr("Permanently deleting photos...");
                var imageIds = [];
                for (var i = 0; i < deletedPhotosPage.selectedImages.length; i++) {
                    if (deletedPhotosPage.selectedImages[i].id) {
                        imageIds.push(deletedPhotosPage.selectedImages[i].id);
                    }
                }
                python.call('immich_client.permanently_delete', imageIds, function (result) {
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
}
