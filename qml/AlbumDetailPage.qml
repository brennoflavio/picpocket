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
    id: albumDetailPage

    property string albumId: ""
    property string albumName: ""
    property var selectedImages: []

    header: AppHeader {
        id: header
        pageTitle: albumName || i18n.tr("Album")
        isRootPage: false
        showSettingsButton: true
        onSettingsClicked: {
            pageStack.push(Qt.resolvedUrl("ConfigurationPage.qml"));
        }
    }

    property var albumData: ({
            "title": "",
            "images": [],
            "previous": "",
            "next": ""
        })

    function loadAlbumTimeline(hint) {
        loadingToast.showing = true;
        loadingToast.message = i18n.tr("Loading album photos...");
        var args = [];
        if (hint && hint !== "") {
            args = [albumId, hint];
        } else {
            args = [albumId];
        }
        python.call('immich_client.album_detail', args, function (result) {
                if (result) {
                    albumDetailPage.albumData = result;
                } else {
                    albumDetailPage.albumData = {
                        "title": "",
                        "images": [],
                        "previous": "",
                        "next": ""
                    };
                }
                loadingToast.showing = false;
            });
    }

    Python {
        id: python

        Component.onCompleted: {
            addImportPath(Qt.resolvedUrl('../src/'));
            importModule('immich_client', function () {
                    loadAlbumTimeline("");
                });
        }

        onError: {
            loadingToast.showing = false;
            loadingToast.message = i18n.tr("Error loading album");
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
        defaultTitle: albumDetailPage.albumData.title
        images: albumDetailPage.albumData.images

        onImageClicked: {
            pageStack.push(Qt.resolvedUrl("PhotoDetail.qml"), {
                    "previewType": "album",
                    "albumId": albumDetailPage.albumId,
                    "filePath": imageData.filePath,
                    "photoId": imageData.id || ""
                });
        }

        onSelectionModeExited: {
            albumDetailPage.selectedImages = [];
        }

        onSelectionChanged: function (images) {
            albumDetailPage.selectedImages = images;
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
            iconName: "view-refresh"
            text: i18n.tr("Refresh")
            enabled: !loadingToast.showing
            visible: !gallery.selectionMode
            opacity: enabled ? 1.0 : 0.5
            onClicked: {
                python.call('immich_client.clear_cache', [], function () {
                        loadAlbumTimeline("");
                    });
            }
        }

        IconButton {
            iconName: "save"
            text: i18n.tr("Archive")
            enabled: albumDetailPage.selectedImages.length > 0 && !loadingToast.showing
            opacity: enabled ? 1.0 : 0.5
            visible: gallery.selectionMode
            onClicked: {
                loadingToast.showing = true;
                loadingToast.message = i18n.tr("Archiving photos...");
                var imageIds = [];
                for (var i = 0; i < albumDetailPage.selectedImages.length; i++) {
                    if (albumDetailPage.selectedImages[i].id) {
                        imageIds.push(albumDetailPage.selectedImages[i].id);
                    }
                }
                python.call('immich_client.archive', imageIds, function (result) {
                        gallery.exitSelectionMode();
                        python.call('immich_client.clear_cache', [], function () {
                                loadAlbumTimeline("");
                            });
                    });
            }
        }

        IconButton {
            iconName: "delete"
            text: i18n.tr("Trash")
            enabled: albumDetailPage.selectedImages.length > 0 && !loadingToast.showing
            opacity: enabled ? 1.0 : 0.5
            visible: gallery.selectionMode
            onClicked: {
                loadingToast.showing = true;
                loadingToast.message = i18n.tr("Trashing photos...");
                var imageIds = [];
                for (var i = 0; i < albumDetailPage.selectedImages.length; i++) {
                    if (albumDetailPage.selectedImages[i].id) {
                        imageIds.push(albumDetailPage.selectedImages[i].id);
                    }
                }
                python.call('immich_client.delete', imageIds, function (result) {
                        gallery.exitSelectionMode();
                        python.call('immich_client.clear_cache', [], function () {
                                loadAlbumTimeline("");
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
