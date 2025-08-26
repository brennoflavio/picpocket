/*
 * Copyright (C) 2025  Brenno Flávio de Almeida
 *
 * This program is free software: you can redistribute it and/or modify
 * it under the terms of the GNU General Public License as published by
 * the Free Software Foundation; version 3.
 *
 * calpal is distributed in the hope that it will be useful,
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

Rectangle {
    id: card

    property string name: ""
    property alias backgroundColor: card.color
    property alias textColor: serverText.color

    signal clicked

    width: parent.width - units.gu(4)
    height: units.gu(10)
    color: "#c8e6c9"
    radius: units.gu(1)

    MouseArea {
        anchors.fill: parent
        onClicked: card.clicked()
    }

    RowLayout {
        anchors.fill: parent
        anchors.margins: units.gu(2)
        spacing: units.gu(2)

        Icon {
            id: userIcon
            name: "contact"
            width: units.gu(4)
            height: units.gu(4)
            color: "#2e7d32"
            Layout.alignment: Qt.AlignVCenter
        }

        Label {
            id: serverText
            text: card.name
            fontSize: "medium"
            color: "#1b5e20"
            Layout.fillWidth: true
            Layout.alignment: Qt.AlignVCenter
            elide: Text.ElideRight
        }
    }
}
