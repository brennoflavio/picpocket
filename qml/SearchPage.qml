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
    id: searchPage

    header: AppHeader {
        id: header
        pageTitle: i18n.tr('Search')
        isRootPage: false
        appIconName: "find"
        showSettingsButton: false
    }

    property var galleryData: ({
            "title": "",
            "images": [],
            "previous": "",
            "next": ""
        })

    property string currentQuery: ""

    function performSearch(query, hint) {
        if (query === "") {
            return;
        }
        loadingToast.showing = true;
        loadingToast.message = i18n.tr("Searching...");
        currentQuery = query;
        var args = hint ? [query, hint] : [query, ""];
        python.call('immich_client.search', args, function (result) {
                searchPage.galleryData = result;
                loadingToast.showing = false;
            });
    }

    Python {
        id: python

        Component.onCompleted: {
            addImportPath(Qt.resolvedUrl('../src/'));
            importModule('immich_client', function () {});
        }

        onError: {
            loadingToast.showing = false;
        }
    }

    Rectangle {
        id: searchBar
        anchors {
            top: header.bottom
            left: parent.left
            right: parent.right
        }
        height: units.gu(6)
        color: theme.palette.normal.background

        RowLayout {
            anchors {
                fill: parent
                margins: units.gu(1)
            }
            spacing: units.gu(1)

            TextField {
                id: searchInput
                Layout.fillWidth: true
                placeholderText: i18n.tr("Enter search query...")
                onAccepted: {
                    performSearch(searchInput.text, "");
                }
            }

            Button {
                id: searchButton
                text: i18n.tr("Search")
                color: theme.palette.normal.positive
                enabled: searchInput.text.length > 0 && !loadingToast.showing
                onClicked: {
                    performSearch(searchInput.text, "");
                }
            }
        }
    }

    Gallery {
        id: gallery
        anchors {
            top: searchBar.bottom
            left: parent.left
            right: parent.right
            bottom: bottomBar.top
        }
        defaultTitle: searchPage.galleryData.title || (currentQuery ? i18n.tr("Results for: %1").arg(currentQuery) : "")
        images: searchPage.galleryData.images

        onImageClicked: {
            pageStack.push(Qt.resolvedUrl("PhotoDetail.qml"), {
                    "previewType": "search",
                    "filePath": imageData.filePath,
                    "photoId": imageData.id || "",
                    "searchQuery": currentQuery
                });
        }
    }

    Label {
        anchors.centerIn: gallery
        visible: searchPage.galleryData.images.length === 0 && currentQuery !== "" && !loadingToast.showing
        text: i18n.tr("No results found")
        fontSize: "large"
        color: theme.palette.normal.backgroundText
    }

    Label {
        anchors.centerIn: gallery
        visible: searchPage.galleryData.images.length === 0 && currentQuery === "" && !loadingToast.showing
        text: i18n.tr("Enter a search query to begin")
        fontSize: "large"
        color: theme.palette.normal.backgroundText
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
            visible: searchPage.galleryData.previous !== undefined && searchPage.galleryData.previous !== ""
            enabled: searchPage.galleryData.previous !== "" && !loadingToast.showing
            opacity: enabled ? 1.0 : 0.5
            onClicked: {
                if (searchPage.galleryData.previous) {
                    performSearch(currentQuery, searchPage.galleryData.previous);
                    gallery.scrollPosition = 0;
                }
            }
        }

        rightButton: IconButton {
            iconName: "go-next"
            visible: searchPage.galleryData.next !== undefined && searchPage.galleryData.next !== ""
            enabled: searchPage.galleryData.next !== "" && !loadingToast.showing
            opacity: enabled ? 1.0 : 0.5
            onClicked: {
                if (searchPage.galleryData.next) {
                    performSearch(currentQuery, searchPage.galleryData.next);
                    gallery.scrollPosition = 0;
                }
            }
        }

        IconButton {
            iconName: "edit-clear"
            text: i18n.tr("Clear")
            enabled: currentQuery !== "" && !loadingToast.showing
            opacity: enabled ? 1.0 : 0.5
            onClicked: {
                searchInput.text = "";
                currentQuery = "";
                searchPage.galleryData = {
                    "title": "",
                    "images": [],
                    "previous": "",
                    "next": ""
                };
            }
        }
    }

    LoadToast {
        id: loadingToast
        showing: false
        message: ""
    }
}
