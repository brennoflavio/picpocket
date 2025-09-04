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

Page {
    id: albumDetailPage

    property string albumId: ""
    property string albumName: ""

    header: AppHeader {
        id: header
        pageTitle: albumName || i18n.tr("Album")
        iconName: "back"
        showBackButton: true
        showSettingsButton: true
        onBackClicked: {
            pageStack.pop();
        }
        onSettingsClicked: {
            pageStack.push(Qt.resolvedUrl("ConfigurationPage.qml"));
        }
    }

    property var albumData: ({
            "month": "",
            "days": [],
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
                        "month": "",
                        "days": [],
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

    Flickable {
        id: flickable
        anchors {
            top: header.bottom
            left: parent.left
            right: parent.right
            bottom: actionBar.top
        }
        contentHeight: gallery.height
        clip: true

        PullToRefresh {
            id: pullToRefresh
            parent: flickable
            target: flickable
            refreshing: loadingToast.showing
            onRefresh: {
                python.call('immich_client.clear_cache', [], function () {
                        loadAlbumTimeline("");
                    });
            }
        }

        Gallery {
            id: gallery
            width: parent.width
            month: albumDetailPage.albumData.month
            days: albumDetailPage.albumData.days

            onItemClicked: {
                pageStack.push(Qt.resolvedUrl("PhotoDetail.qml"), {
                        "previewType": "album",
                        "albumId": albumDetailPage.albumId,
                        "filePath": imageData.filePath,
                        "photoId": imageData.id || ""
                    });
            }
        }
    }

    Rectangle {
        id: actionBar
        anchors {
            left: parent.left
            right: parent.right
            bottom: parent.bottom
        }
        height: units.gu(8)
        color: theme.palette.normal.background

        Rectangle {
            anchors {
                left: parent.left
                right: parent.right
                top: parent.top
            }
            height: units.dp(1)
            color: theme.palette.normal.base
        }

        Item {
            anchors.fill: parent

            AbstractButton {
                id: previousButton
                anchors {
                    left: parent.left
                    leftMargin: units.gu(1)
                    top: parent.top
                    bottom: parent.bottom
                }
                width: units.gu(6)
                visible: albumDetailPage.albumData.previous !== undefined && albumDetailPage.albumData.previous !== ""
                enabled: albumDetailPage.albumData.previous !== "" && !loadingToast.showing

                Icon {
                    anchors.centerIn: parent
                    width: units.gu(3)
                    height: width
                    name: "go-previous"
                    color: previousButton.enabled ? theme.palette.normal.foregroundText : theme.palette.disabled.foregroundText
                }

                onClicked: {
                    if (albumDetailPage.albumData.previous) {
                        loadAlbumTimeline(albumDetailPage.albumData.previous);
                        flickable.contentY = 0;
                    }
                }
            }

            AbstractButton {
                id: nextButton
                anchors {
                    right: parent.right
                    rightMargin: units.gu(1)
                    top: parent.top
                    bottom: parent.bottom
                }
                width: units.gu(6)
                visible: albumDetailPage.albumData.next !== undefined && albumDetailPage.albumData.next !== ""
                enabled: albumDetailPage.albumData.next !== "" && !loadingToast.showing

                Icon {
                    anchors.centerIn: parent
                    width: units.gu(3)
                    height: width
                    name: "go-next"
                    color: nextButton.enabled ? theme.palette.normal.foregroundText : theme.palette.disabled.foregroundText
                }

                onClicked: {
                    if (albumDetailPage.albumData.next) {
                        loadAlbumTimeline(albumDetailPage.albumData.next);
                        flickable.contentY = 0;
                    }
                }
            }
        }
    }

    AbstractButton {
        id: scrollToTopButton
        anchors {
            right: parent.right
            rightMargin: units.gu(2)
            bottom: actionBar.top
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
        showSpinner: true
    }
}
