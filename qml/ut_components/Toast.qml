import Lomiri.Components 1.3
/*
 * Copyright (C) 2025  Brenno Flávio de Almeida
 *
 * This program is free software: you can redistribute it and/or modify
 * it under the terms of the GNU General Public License as published by
 * the Free Software Foundation; version 3.
 *
 * ut-components is distributed in the hope that it will be useful,
 * but WITHOUT ANY WARRANTY; without even the implied warranty of
 * MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
 * GNU General Public License for more details.
 *
 * You should have received a copy of the GNU General Public License
 * along with this program.  If not, see <http://www.gnu.org/licenses/>.
 */
import QtQuick 2.7

/*
 * Toast Component
 *
 * A brief notification popup that appears at the bottom of the screen
 * to provide quick feedback to the user. The toast automatically fades
 * in, displays for a specified duration, and then fades out.
 *
 * Example usage:
 *
 * Toast {
 *     id: myToast
 *     duration: 1000  // Show for 1 second
 *     bottomMargin: units.gu(10)  // Position higher from bottom
 * }
 *
 * // To show a toast:
 * myToast.show(i18n.tr("Action completed successfully"))
 *
 * // Alternative usage - directly setting message:
 * myToast.message = i18n.tr("File saved");
 * myToast.show();  // Call without parameter to use existing message
 */
Rectangle {
    id: toast

    // The text message to display in the toast
    property string message: ""
    // Duration in milliseconds to display the toast (excluding fade animations)
    property int duration: 800
    // Distance from the bottom of the parent component in grid units
    property real bottomMargin: units.gu(8)

    // Shows the toast with the specified text message
    // If no text is provided, shows the current message property
    function show(text) {
        if (text !== undefined)
            message = text;

        toastAnimation.restart();
    }

    width: toastLabel.width + units.gu(4)
    height: units.gu(5)
    radius: units.gu(2.5)
    color: Qt.rgba(0, 0, 0, 0.8)
    opacity: 0
    z: 1000

    anchors {
        bottom: parent.bottom
        bottomMargin: bottomMargin
        horizontalCenter: parent.horizontalCenter
    }

    Label {
        id: toastLabel

        anchors.centerIn: parent
        color: "white"
        fontSize: "small"
        text: toast.message
    }

    SequentialAnimation {
        id: toastAnimation

        PropertyAnimation {
            target: toast
            property: "opacity"
            to: 1
            duration: 200
        }

        PauseAnimation {
            duration: toast.duration
        }

        PropertyAnimation {
            target: toast
            property: "opacity"
            to: 0
            duration: 200
        }

    }

}
