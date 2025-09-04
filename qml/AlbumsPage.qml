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
                            return {
                                "id": album.id,
                                "name": album.name,
                                "thumbnailUrl": "file://" + album.file_path,
                                "itemCount": album.asset_count,
                                "description": album.shared ? "Shared" : ""
                            };
                        });
                }
                refreshing = false;
            });
    }

    header: AppHeader {
        id: header
        pageTitle: i18n.tr("Albums")
        showBackButton: true
        showSettingsButton: true
        onBackClicked: pageStack.pop()
        onSettingsClicked: {
            pageStack.push(Qt.resolvedUrl("ConfigurationPage.qml"));
        }
    }

    property bool refreshing: false
    property var albumsData: []

    LoadToast {
        id: loadToast
        message: i18n.tr("Loading albums...")
        showing: refreshing
    }

    Flickable {
        id: flickable
        anchors {
            top: header.bottom
            left: parent.left
            right: parent.right
            bottom: parent.bottom
        }
        contentHeight: mainColumn.height
        clip: true

        PullToRefresh {
            id: pullToRefresh
            parent: flickable
            target: flickable
            refreshing: albumsPage.refreshing
            onRefresh: {
                python.call('immich_client.clear_cache', [], function () {
                        loadAlbums();
                    });
            }
        }

        Column {
            id: mainColumn
            width: parent.width
            height: Math.max(flickable.height, childrenRect.height + units.gu(4))
            spacing: units.gu(2)
            topPadding: units.gu(2)
            bottomPadding: units.gu(2)

            Item {
                width: parent.width
                height: units.gu(5)

                Row {
                    anchors {
                        fill: parent
                        leftMargin: units.gu(2)
                        rightMargin: units.gu(2)
                    }
                    spacing: units.gu(1)

                    Icon {
                        anchors.verticalCenter: parent.verticalCenter
                        name: "find"
                        height: units.gu(2)
                        width: units.gu(2)
                        color: theme.palette.normal.backgroundSecondaryText
                    }

                    TextField {
                        id: searchField
                        width: parent.width - units.gu(5)
                        anchors.verticalCenter: parent.verticalCenter
                        placeholderText: i18n.tr("Search albums")
                    }
                }
            }

            Repeater {
                model: {
                    var filtered = albumsData;
                    if (searchField.text.length > 0) {
                        filtered = filtered.filter(function (album) {
                                return album.name.toLowerCase().indexOf(searchField.text.toLowerCase()) !== -1;
                            });
                    }
                    return filtered;
                }

                delegate: Card {
                    width: parent.width - units.gu(4)
                    anchors.horizontalCenter: parent.horizontalCenter
                    albumName: modelData.name || ""
                    thumbnailSource: modelData.thumbnailUrl || ""
                    itemCount: modelData.itemCount || 0
                    description: modelData.description || ""

                    onClicked: {
                        pageStack.push(Qt.resolvedUrl("AlbumDetailPage.qml"), {
                                "albumId": modelData.id,
                                "albumName": modelData.name
                            });
                    }
                }
            }

            Label {
                visible: albumsData.length === 0
                anchors.horizontalCenter: parent.horizontalCenter
                text: i18n.tr("No albums")
                fontSize: "large"
                color: theme.palette.normal.backgroundSecondaryText
            }
        }
    }
}
