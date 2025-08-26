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

ListView {
    id: cardList

    property var cards: []

    signal cardClicked(var cardId, string cardName)

    width: parent.width
    spacing: units.gu(2)
    clip: true

    model: cards

    delegate: Card {
        id: card
        anchors.horizontalCenter: parent.horizontalCenter
        name: modelData.name

        onClicked: {
            cardList.cardClicked(modelData.id, modelData.name);
        }
    }

    Label {
        visible: cards.length === 0
        anchors.centerIn: parent
        text: i18n.tr("No data")
        fontSize: "large"
        color: theme.palette.normal.backgroundSecondaryText
    }
}
