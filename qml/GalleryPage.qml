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
import io.thp.pyotherside 1.4
import "lib"

Page {
    id: galleryPage

    header: AppHeader {
        id: header
        pageTitle: i18n.tr('PicPocket')
        iconName: picturePicker.visible ? "" : "stock_image"
        showBackButton: picturePicker.visible
        showSettingsButton: !picturePicker.visible
        onBackClicked: {
            picturePicker.visible = false
        }
        onSettingsClicked: {
            pageStack.push(Qt.resolvedUrl("ConfigurationPage.qml"))
        }
    }

    property var galleryData: ({
        month: "",
        days: [],
        previous: "",
        next: ""
    })

    function loadTimeline(hint) {
        loadingToast.showing = true;
        loadingToast.message = i18n.tr("Loading photos...");

        var args = hint ? [hint] : [""];
        python.call('immich_client.timeline', args, function(result) {
            galleryPage.galleryData = result;
            loadingToast.showing = false;
        });
    }

    Python {
        id: python

        Component.onCompleted: {
            addImportPath(Qt.resolvedUrl('../src/'));

            importModule('immich_client', function() {
                loadTimeline("");
            });
        }

        onError: {
            loadingToast.showing = false;
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

        Gallery {
            id: gallery
            width: parent.width
            month: galleryPage.galleryData.month
            days: galleryPage.galleryData.days

            onItemClicked: {
                pageStack.push(Qt.resolvedUrl("PhotoDetail.qml"), {
                    filePath: imageData.filePath,
                    photoId: imageData.id || "",
                })
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

        RowLayout {
            anchors {
                fill: parent
                margins: units.gu(1)
            }
            spacing: 0

            AbstractButton {
                id: previousButton
                Layout.preferredWidth: units.gu(6)
                Layout.fillHeight: true
                enabled: galleryPage.galleryData.previous !== "" && !loadingToast.showing

                Icon {
                    anchors.centerIn: parent
                    width: units.gu(3)
                    height: width
                    name: "go-previous"
                    color: previousButton.enabled ? theme.palette.normal.foregroundText : theme.palette.disabled.foregroundText
                }

                onClicked: {
                    if (galleryPage.galleryData.previous) {
                        loadTimeline(galleryPage.galleryData.previous)
                        flickable.contentY = 0
                    }
                }
            }

            Item {
                Layout.fillWidth: true
            }

            AbstractButton {
                id: uploadButton
                Layout.preferredWidth: units.gu(6)
                Layout.fillHeight: true
                enabled: !loadingToast.showing

                Column {
                    anchors.centerIn: parent
                    spacing: units.gu(0.5)

                    Icon {
                        width: units.gu(3)
                        height: width
                        anchors.horizontalCenter: parent.horizontalCenter
                        name: "keyboard-caps-disabled"
                        color: uploadButton.enabled ? theme.palette.normal.foregroundText : theme.palette.disabled.foregroundText
                    }

                    Label {
                        fontSize: "small"
                        anchors.horizontalCenter: parent.horizontalCenter
                        text: i18n.tr("Upload")
                    }
                }

                onClicked: {
                    picturePicker.visible = true
                }
            }

            Item {
                Layout.fillWidth: true
            }

            AbstractButton {
                id: nextButton
                Layout.preferredWidth: units.gu(6)
                Layout.fillHeight: true
                enabled: galleryPage.galleryData.next !== "" && !loadingToast.showing

                Icon {
                    anchors.centerIn: parent
                    width: units.gu(3)
                    height: width
                    name: "go-next"
                    color: nextButton.enabled ? theme.palette.normal.foregroundText : theme.palette.disabled.foregroundText
                }

                onClicked: {
                    if (galleryPage.galleryData.next) {
                        loadTimeline(galleryPage.galleryData.next)
                        flickable.contentY = 0
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

        Behavior on opacity {
            NumberAnimation {
                duration: 200
            }
        }

        onClicked: {
            flickable.contentY = 0
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

    ContentStore {
        id: contentStore
        scope: ContentScope.App
    }

    ContentPeerPicker {
        id: picturePicker
        visible: false
        contentType: ContentType.Pictures
        handler: ContentHandler.Source

        onPeerSelected: {
            var transfer = peer.request(contentStore)
            transfer.selectionType = ContentTransfer.Single

            transfer.stateChanged.connect(function() {
                if (transfer.state === ContentTransfer.Charged) {
                    if (transfer.items.length > 0) {
                        var fileUrl = transfer.items[0].url.toString()
                        var filePath = fileUrl.replace("file://", "")

                        loadingToast.message = i18n.tr("Uploading photo...")
                        loadingToast.showing = true

                        python.call('immich_client.upload_photo', [filePath], function(result) {
                            loadingToast.showing = false
                            console.log(result)
                            if (result) {
                                loadTimeline("")
                            }
                        })
                    }
                    picturePicker.visible = false
                }
            })
        }

        onCancelPressed: {
            picturePicker.visible = false
        }
    }
}
