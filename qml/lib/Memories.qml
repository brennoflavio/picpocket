import QtQuick 2.7
import Lomiri.Components 1.3
import QtQuick.Layouts 1.3
import QtGraphicalEffects 1.0

Item {
    id: root
    height: units.gu(14)

    property var memoriesData: []

    signal memoryClicked(var memoryData)

    ListView {
        id: memoriesList
        anchors {
            fill: parent
            leftMargin: units.gu(1)
            rightMargin: units.gu(1)
            topMargin: units.gu(1)
            bottomMargin: units.gu(1)
        }
        orientation: ListView.Horizontal
        spacing: units.gu(2)
        clip: true

        model: memoriesData

        delegate: AbstractButton {
            id: memoryItem
            width: units.gu(10)
            height: units.gu(12)

            onClicked: {
                root.memoryClicked(modelData);
            }

            Column {
                anchors.fill: parent
                spacing: units.gu(0.5)

                Item {
                    width: units.gu(9)
                    height: units.gu(9)
                    anchors.horizontalCenter: parent.horizontalCenter

                    Rectangle {
                        id: borderCircle
                        anchors.fill: parent
                        radius: width / 2
                        color: "transparent"
                        border.width: units.dp(2)
                        border.color: theme.palette.normal.base
                    }

                    Item {
                        id: imageContainer
                        anchors.centerIn: parent
                        width: parent.width - units.dp(6)
                        height: width

                        Rectangle {
                            id: imageBackground
                            anchors.fill: parent
                            radius: width / 2
                            color: theme.palette.normal.base
                            visible: !memoryImage.source
                        }

                        Image {
                            id: memoryImage
                            anchors.fill: parent
                            source: modelData.thumbnailUrl || ""
                            fillMode: Image.PreserveAspectCrop
                            visible: false
                        }

                        Rectangle {
                            id: mask
                            anchors.fill: parent
                            radius: width / 2
                            visible: false
                        }

                        OpacityMask {
                            anchors.fill: parent
                            source: memoryImage
                            maskSource: mask
                            visible: memoryImage.source != ""
                        }

                        Icon {
                            anchors.centerIn: parent
                            width: units.gu(4)
                            height: width
                            name: "stock_image"
                            color: theme.palette.normal.backgroundSecondaryText
                            visible: !memoryImage.source
                        }
                    }
                }

                Label {
                    width: parent.width
                    horizontalAlignment: Text.AlignHCenter
                    text: modelData.title
                    fontSize: "x-small"
                    elide: Text.ElideRight
                }
            }
        }
    }
}
