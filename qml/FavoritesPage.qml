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
    id: favoritesPage

    header: AppHeader {
        id: header
        pageTitle: i18n.tr('Favorites')
        isRootPage: false
        appIconName: "starred"
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
        loadingToast.message = i18n.tr("Loading favorites...");
        var args = hint ? [hint] : [""];
        python.call('immich_client.favorite_timeline', args, function (result) {
                favoritesPage.galleryData = result;
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
        defaultTitle: favoritesPage.galleryData.title
        images: favoritesPage.galleryData.images

        onImageClicked: {
            pageStack.push(Qt.resolvedUrl("PhotoDetail.qml"), {
                    "previewType": "favorite",
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
            visible: favoritesPage.galleryData.previous !== undefined && favoritesPage.galleryData.previous !== ""
            enabled: favoritesPage.galleryData.previous !== "" && !loadingToast.showing
            opacity: enabled ? 1.0 : 0.5
            onClicked: {
                if (favoritesPage.galleryData.previous) {
                    loadTimeline(favoritesPage.galleryData.previous);
                    gallery.scrollPosition = 0;
                }
            }
        }

        rightButton: IconButton {
            iconName: "go-next"
            visible: favoritesPage.galleryData.next !== undefined && favoritesPage.galleryData.next !== ""
            enabled: favoritesPage.galleryData.next !== "" && !loadingToast.showing
            opacity: enabled ? 1.0 : 0.5
            onClicked: {
                if (favoritesPage.galleryData.next) {
                    loadTimeline(favoritesPage.galleryData.next);
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
