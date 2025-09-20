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
    id: archivedPage

    header: AppHeader {
        id: header
        pageTitle: i18n.tr('Archived')
        isRootPage: false
        appIconName: "save"
        showSettingsButton: false
    }

    property var galleryData: ({
            "title": "",
            "images": [],
            "previous": "",
            "next": ""
        })

    function loadTimeline(hint) {
        loadingToast.showing = true;
        loadingToast.message = i18n.tr("Loading archived photos...");
        var args = hint ? [hint] : [""];
        python.call('immich_client.archived_timeline', args, function (result) {
                archivedPage.galleryData = result;
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
        defaultTitle: archivedPage.galleryData.title
        images: archivedPage.galleryData.images

        onImageClicked: {
            pageStack.push(Qt.resolvedUrl("PhotoDetail.qml"), {
                    "previewType": "archived",
                    "filePath": imageData.filePath,
                    "photoId": imageData.id || ""
                });
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
            visible: archivedPage.galleryData.previous !== undefined && archivedPage.galleryData.previous !== ""
            enabled: archivedPage.galleryData.previous !== "" && !loadingToast.showing
            opacity: enabled ? 1.0 : 0.5
            onClicked: {
                if (archivedPage.galleryData.previous) {
                    loadTimeline(archivedPage.galleryData.previous);
                    gallery.scrollPosition = 0;
                }
            }
        }

        rightButton: IconButton {
            iconName: "go-next"
            visible: archivedPage.galleryData.next !== undefined && archivedPage.galleryData.next !== ""
            enabled: archivedPage.galleryData.next !== "" && !loadingToast.showing
            opacity: enabled ? 1.0 : 0.5
            onClicked: {
                if (archivedPage.galleryData.next) {
                    loadTimeline(archivedPage.galleryData.next);
                    gallery.scrollPosition = 0;
                }
            }
        }

        IconButton {
            iconName: "view-refresh"
            text: i18n.tr("Refresh")
            enabled: !loadingToast.showing
            opacity: enabled ? 1.0 : 0.5
            onClicked: {
                python.call('immich_client.clear_cache', [], function () {
                        loadTimeline("");
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
