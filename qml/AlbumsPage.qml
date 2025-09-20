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
import "lib"
import "ut_components"

Page {
    id: albumsPage

    Component.onCompleted: {
        loadAlbums();
    }

    function loadAlbums() {
        refreshing = true;
        python.call('immich_client.albums', [], function (result) {
                if (result && result.albums) {
                    albumsData = result.albums.map(function (album) {
                            var subtitle = album.asset_count + " " + (album.asset_count === 1 ? i18n.tr("item") : i18n.tr("items"));
                            if (album.shared) {
                                subtitle += " • " + i18n.tr("Shared");
                            }
                            return {
                                "id": album.id,
                                "title": album.name,
                                "thumbnailSource": "file://" + album.file_path,
                                "subtitle": subtitle
                            };
                        });
                }
                refreshing = false;
            });
    }

    header: AppHeader {
        id: header
        pageTitle: i18n.tr("Albums")
        isRootPage: false
        showSettingsButton: true
        onSettingsClicked: {
            pageStack.push(Qt.resolvedUrl("ConfigurationPage.qml"));
        }
    }

    property bool refreshing: false
    property bool clearingCache: false
    property var albumsData: []

    LoadToast {
        id: loadToast
        message: clearingCache ? i18n.tr("Refreshing albums...") : i18n.tr("Loading albums...")
        showing: refreshing || clearingCache
    }

    CardList {
        id: cardList
        anchors {
            top: header.bottom
            left: parent.left
            right: parent.right
            bottom: bottomBar.top
            topMargin: units.gu(2)
            leftMargin: units.gu(2)
            rightMargin: units.gu(2)
            bottomMargin: units.gu(1)
        }
        items: albumsData
        showSearchBar: true
        searchPlaceholder: i18n.tr("Search albums")
        emptyMessage: i18n.tr("No albums")

        onItemClicked: {
            pageStack.push(Qt.resolvedUrl("AlbumDetailPage.qml"), {
                    "albumId": item.id,
                    "albumName": item.title
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

        IconButton {
            iconName: "view-refresh"
            text: i18n.tr("Refresh")
            onClicked: {
                clearingCache = true;
                python.call('immich_client.clear_cache', [], function () {
                        clearingCache = false;
                        loadAlbums();
                    });
            }
        }
    }
}
