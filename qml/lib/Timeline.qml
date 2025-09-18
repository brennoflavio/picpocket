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

Item {
    id: timeline

    // Timeline data properties
    property string month: ""
    property var days: []

    // Loading state
    property bool isLoading: false

    // Enable/disable pull to refresh
    property bool enablePullToRefresh: true

    // Signals
    signal itemClicked(var imageData)
    signal refresh

    // Content properties
    property alias contentY: flickable.contentY
    property alias contentHeight: gallery.height
    property alias flickable: flickable

    Flickable {
        id: flickable
        anchors.fill: parent
        contentHeight: gallery.height
        clip: true

        PullToRefresh {
            id: pullToRefresh
            parent: flickable
            target: flickable
            refreshing: timeline.isLoading
            visible: timeline.enablePullToRefresh
            enabled: timeline.enablePullToRefresh
            onRefresh: {
                timeline.refresh();
            }
        }

        Gallery {
            id: gallery
            width: parent.width
            month: timeline.month
            days: timeline.days

            onItemClicked: {
                timeline.itemClicked(imageData);
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

    function scrollToTop() {
        flickable.contentY = 0;
    }
}
