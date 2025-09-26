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
import Lomiri.Components.Popups 1.3
import QtQuick.Layouts 1.3
import io.thp.pyotherside 1.4
import "lib"
import "ut_components"

Page {
    id: albumSelectorPage

    property var selectedAssetIds: []

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
                                "thumbnailSource": album.file_path ? "file://" + album.file_path : "",
                                "subtitle": subtitle,
                                "icon": album.file_path ? "" : "image-x-generic-symbolic"
                            };
                        });
                }
                refreshing = false;
            });
    }

    header: AppHeader {
        id: header
        pageTitle: i18n.tr("Select Album")
        isRootPage: false
        showSettingsButton: false
    }

    property bool refreshing: false
    property bool addingToAlbum: false
    property var albumsData: []

    Python {
        id: python

        Component.onCompleted: {
            addImportPath(Qt.resolvedUrl('../src/'));
            importModule('immich_client', function () {});
        }

        onError: {
            refreshing = false;
            addingToAlbum = false;
        }
    }

    LoadToast {
        id: loadToast
        message: addingToAlbum ? i18n.tr("Adding photos to album...") : i18n.tr("Loading albums...")
        showing: refreshing || addingToAlbum
    }

    CardList {
        id: cardList
        anchors {
            top: header.bottom
            left: parent.left
            right: parent.right
            bottom: parent.bottom
            topMargin: units.gu(2)
            leftMargin: units.gu(2)
            rightMargin: units.gu(2)
            bottomMargin: units.gu(2)
        }
        items: albumsData
        showSearchBar: true
        searchPlaceholder: i18n.tr("Search albums")
        emptyMessage: i18n.tr("No albums")

        onItemClicked: {
            addingToAlbum = true;
            python.call('immich_client.add_assets_to_album', [item.id, selectedAssetIds], function (result) {
                    python.call('immich_client.clear_cache', [], function () {
                            addingToAlbum = false;
                            pageStack.pop();
                        });
                });
        }
    }
}
