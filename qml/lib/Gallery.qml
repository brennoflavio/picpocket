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

    /*! Whether the gallery is in selection mode */
    property bool selectionMode: false

    /*! List of selected image IDs or indices */
    property var selectedImages: []

    /*!
     * Emitted when an image is clicked/tapped.
     * @param imageData The complete image object from the sections array
     */
    signal imageClicked(var imageData)

    /*!
     * Emitted when selection mode is exited
     */
    signal selectionModeExited

    /*!
     * Emitted when the selection changes or selection mode is entered/exited
     * @param selectedImages Array of selected image objects
     */
    signal selectionChanged(var selectedImages)

    function exitSelectionMode() {
        selectionMode = false;
        selectedImages = [];
        selectionModeExited();
        selectionChanged([]);
    }

    function toggleImageSelection(imageData, index) {
        var identifier = imageData.id ? imageData.id : index;
        var idx = selectedImages.indexOf(identifier);
        var newSelection = selectedImages.slice();
        if (idx === -1) {
            newSelection.push(identifier);
        } else {
            newSelection.splice(idx, 1);
        }
        selectedImages = newSelection;
        var selectedObjects = [];
        for (var i = 0; i < images.length; i++) {
            var id = images[i].id ? images[i].id : i;
            if (selectedImages.indexOf(id) !== -1) {
                selectedObjects.push(images[i]);
            }
        }
        selectionChanged(selectedObjects);
    }

    function isImageSelected(imageData, index) {
        var identifier = imageData.id ? imageData.id : index;
        return selectedImages.indexOf(identifier) !== -1;
    }

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

                Rectangle {
                    id: selectionIndicator
                    visible: root.selectionMode
                    anchors {
                        top: parent.top
                        left: parent.left
                        topMargin: units.gu(1)
                        leftMargin: units.gu(1)
                    }
                    width: units.gu(3)
                    height: units.gu(3)
                    radius: width / 2
                    color: root.isImageSelected(modelData, index) ? theme.palette.normal.positive : Qt.rgba(1, 1, 1, 0.8)
                    border.width: units.gu(0.2)
                    border.color: root.isImageSelected(modelData, index) ? theme.palette.normal.positive : Qt.rgba(0.3, 0.3, 0.3, 0.8)

                    Icon {
                        anchors.centerIn: parent
                        name: "tick"
                        width: units.gu(2)
                        height: units.gu(2)
                        color: "white"
                        visible: root.isImageSelected(modelData, index)
                    }
                }

                MouseArea {
                    anchors.fill: parent

                    onClicked: {
                        if (root.selectionMode) {
                            root.toggleImageSelection(modelData, index);
                        } else {
                            root.imageClicked(modelData);
                        }
                    }

                    onPressAndHold: {
                        if (!root.selectionMode) {
                            root.selectionMode = true;
                            root.toggleImageSelection(modelData, index);
                        }
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

    Item {
        id: cancelSelectionButton
        anchors {
            left: parent.left
            bottom: parent.bottom
            leftMargin: units.gu(2)
            bottomMargin: units.gu(2)
        }
        width: units.gu(6)
        height: units.gu(6)
        visible: root.selectionMode
        z: 10

        opacity: visible ? 0.9 : 0

        Behavior on opacity  {
            NumberAnimation {
                duration: 200
            }
        }

        Rectangle {
            id: cancelButtonBackground
            anchors.fill: parent
            radius: width / 2
            color: "#5D5D5D"

            Icon {
                anchors.centerIn: parent
                name: "close"
                width: units.gu(3)
                height: units.gu(3)
                color: "white"
            }

            MouseArea {
                anchors.fill: parent
                onClicked: {
                    root.exitSelectionMode();
                }
                onPressed: {
                    cancelButtonBackground.opacity = 0.7;
                }
                onReleased: {
                    cancelButtonBackground.opacity = 1;
                }
            }

            Behavior on opacity  {
                NumberAnimation {
                    duration: 100
                }
            }
        }
    }
}
