import QtQuick 2.12
import Lomiri.Components 1.3
import "../ut_components" as UTComponents

/*!
 * \brief Gallery - A grid-based image gallery component
 *
 * Gallery displays images in a responsive grid layout with smooth scrolling,
 * lazy image loading, and interactive features like image selection and scroll-to-top.
 *
 * Features:
 * - Automatic grid layout (3 columns by default)
 * - Responsive cell sizing based on available width
 * - Asynchronous image loading with loading indicators
 * - Smooth scrolling with scroll-to-top button
 * - Image click handling for navigation or preview
 *
 * Example usage:
 * \qml
 * Gallery {
 *     title: "My Photos"
 *     images: [
 *         { filePath: "image1.jpg", id: "1", metadata: {...} },
 *         { filePath: "image2.jpg", id: "2", metadata: {...} },
 *         { filePath: "image3.jpg", id: "3", metadata: {...} }
 *     ]
 *     onImageClicked: {
 *         console.log("Selected image:", imageData.filePath)
 *         // Navigate to full screen view
 *     }
 * }
 * \endqml
 */
Item {
    id: root

    /*!
     * Array of image objects to display in the gallery.
     * Each image object should contain at minimum a 'filePath' property.
     * Image objects can contain any additional properties that will be passed through imageClicked.
     */
    property var images: []

    /*! Size in pixels for each image cell in the grid. Auto-calculated based on width to fit 3 columns */
    property int cellSize: calculateCellSize()

    /*! Spacing between images in grid units */
    property int spacing: units.gu(0.25)

    /*! Current scroll position of the gallery (can be used to save/restore scroll state) */
    property real scrollPosition: 0

    /*! Whether the gallery can be scrolled/flicked by user interaction */
    property alias interactive: gridView.interactive

    /*! Optional main title displayed at the top of the gallery */
    property string title: ""

    /*! Default title to use when no image title is available */
    property string defaultTitle: title

    /*! Stores the last visible index to avoid unnecessary updates */
    property int lastVisibleIndex: -1

    /*!
     * Emitted when an image is clicked/tapped.
     * @param imageData The complete image object from the sections array
     */
    signal imageClicked(var imageData)

    function calculateCellSize() {
        if (width <= 0)
            return units.gu(15);
        var availableWidth = width - (spacing * 2);
        return Math.max(units.gu(5), Math.floor((availableWidth - spacing * 2) / 3));
    }

    onWidthChanged: {
        cellSize = calculateCellSize();
    }

    property int itemsPerRow: Math.floor(width / (cellSize + spacing))

    GridView {
        id: gridView
        anchors.fill: parent
        anchors.topMargin: root.title ? headerItem.height : 0

        model: root.images

        cellWidth: root.cellSize + root.spacing
        cellHeight: root.cellSize + root.spacing

        cacheBuffer: height * 2

        maximumFlickVelocity: units.gu(500)
        flickDeceleration: units.gu(300)

        boundsBehavior: Flickable.StopAtBounds
        clip: true

        onContentYChanged: {
            root.scrollPosition = contentY;
            scrollToTopButton.visible = contentY > height;
            if (root.images.length > 0) {
                var firstVisibleIndex = gridView.indexAt(root.spacing, contentY + root.spacing);
                if (firstVisibleIndex !== -1 && firstVisibleIndex !== root.lastVisibleIndex) {
                    root.lastVisibleIndex = firstVisibleIndex;
                    if (root.images[firstVisibleIndex] && root.images[firstVisibleIndex].title) {
                        root.title = root.images[firstVisibleIndex].title;
                    } else {
                        root.title = root.defaultTitle;
                    }
                }
            }
        }

        delegate: Item {
            width: gridView.cellWidth
            height: gridView.cellHeight

            Rectangle {
                id: imageContainer
                anchors.centerIn: parent
                width: root.cellSize
                height: root.cellSize
                color: theme.palette.normal.base
                clip: true

                Image {
                    id: thumbnail
                    anchors.fill: parent

                    source: modelData.filePath ? modelData.filePath : ""

                    sourceSize.width: root.cellSize
                    sourceSize.height: root.cellSize

                    fillMode: Image.PreserveAspectCrop
                    asynchronous: true
                    cache: true
                    smooth: true
                }

                Rectangle {
                    anchors.fill: parent
                    color: theme.palette.normal.base
                    visible: thumbnail.status !== Image.Ready && thumbnail.source !== ""

                    ActivityIndicator {
                        anchors.centerIn: parent
                        running: parent.visible
                        visible: running
                    }
                }

                Rectangle {
                    id: durationBadge
                    visible: modelData.duration !== undefined && modelData.duration !== null
                    anchors {
                        top: parent.top
                        right: parent.right
                        topMargin: units.gu(0.5)
                        rightMargin: units.gu(0.5)
                    }
                    height: units.gu(2.5)
                    width: durationLabel.width + units.gu(1.5)
                    radius: units.gu(0.5)
                    color: Qt.rgba(0, 0, 0, 0.7)

                    Label {
                        id: durationLabel
                        anchors.centerIn: parent
                        text: modelData.duration ? modelData.duration : ""
                        fontSize: "small"
                        color: "white"
                    }
                }

                MouseArea {
                    anchors.fill: parent

                    onClicked: {
                        root.imageClicked(modelData);
                    }
                }
            }
        }

        Timer {
            id: loadTimer
            interval: 100
            repeat: false
            onTriggered: {
                gridView.positionViewAtBeginning();
            }
        }

        onModelChanged: {
            loadTimer.restart();
            root.lastVisibleIndex = -1;
            root.title = root.defaultTitle;
        }
    }

    Item {
        id: headerItem
        anchors {
            top: parent.top
            left: parent.left
            right: parent.right
        }
        height: root.title ? units.gu(6) : 0
        visible: root.title !== ""
        z: 1

        Rectangle {
            anchors.fill: parent
            color: theme.palette.normal.background

            Label {
                anchors {
                    left: parent.left
                    leftMargin: units.gu(2)
                    verticalCenter: parent.verticalCenter
                }
                text: root.title
                fontSize: "x-large"
                color: theme.palette.normal.backgroundText
            }
        }
    }

    Item {
        id: scrollToTopButton
        anchors {
            right: parent.right
            bottom: parent.bottom
            rightMargin: units.gu(2)
            bottomMargin: units.gu(2)
        }
        width: units.gu(6)
        height: units.gu(6)
        visible: false
        z: 10

        opacity: visible ? 0.9 : 0

        Behavior on opacity  {
            NumberAnimation {
                duration: 200
            }
        }

        Rectangle {
            id: buttonBackground
            anchors.fill: parent
            radius: width / 2
            color: "#5D5D5D"

            Icon {
                anchors.centerIn: parent
                name: "up"
                width: units.gu(3)
                height: units.gu(3)
                color: "white"
            }

            MouseArea {
                anchors.fill: parent
                onClicked: {
                    scrollAnimation.running = true;
                }
                onPressed: {
                    buttonBackground.opacity = 0.7;
                }
                onReleased: {
                    buttonBackground.opacity = 1;
                }
            }

            Behavior on opacity  {
                NumberAnimation {
                    duration: 100
                }
            }
        }
    }

    NumberAnimation {
        id: scrollAnimation
        target: gridView
        property: "contentY"
        to: 0
        duration: 300
        easing.type: Easing.OutCubic
    }
}
