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
    id: galleryPage

    header: AppHeader {
        id: header
        pageTitle: i18n.tr('PicPocket')
        iconName: "stock_image"
        showSettingsButton: true
        onSettingsClicked: {
            pageStack.push(Qt.resolvedUrl("ConfigurationPage.qml"))
        }
    }

    property var galleryData: ({
        month: "",
        days: []
    })

    Python {
        id: python

        Component.onCompleted: {
            addImportPath(Qt.resolvedUrl('../src/'));

            loadingToast.showing = true;
            loadingToast.message = i18n.tr("Loading photos...");

            importModule('immich_client', function() {
                python.call('immich_client.timeline', [], function(result) {
                    galleryPage.galleryData = result;
                    loadingToast.showing = false;
                });
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
            bottom: parent.bottom
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

    AbstractButton {
        id: scrollToTopButton
        anchors {
            right: parent.right
            rightMargin: units.gu(2)
            bottom: parent.bottom
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
}
