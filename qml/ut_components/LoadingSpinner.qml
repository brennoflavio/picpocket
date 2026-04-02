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

/*!
 * \brief LoadingSpinner - A rotating spinner indicator for Ubuntu Touch applications
 *
 * LoadingSpinner displays a rotating spinner image to indicate loading state.
 * It replaces the built-in ActivityIndicator which has a broken asset path.
 *
 * Example usage:
 * \qml
 * LoadingSpinner {
 *     running: true
 * }
 * \endqml
 */
Image {
    id: spinner

    property bool running: false

    width: units.gu(5)
    height: units.gu(5)
    smooth: true
    visible: running
    fillMode: Image.PreserveAspectFit
    horizontalAlignment: Image.AlignHCenter
    verticalAlignment: Image.AlignVCenter
    source: visible ? Qt.resolvedUrl("artwork/spinner.png") : ""
    asynchronous: true

    RotationAnimator on rotation {
        running: spinner.running
        from: 0
        to: 360
        loops: Animation.Infinite
        duration: LomiriAnimation.SleepyDuration
    }

}
