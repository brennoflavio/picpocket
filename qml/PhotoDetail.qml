import Lomiri.Components 1.3
import Lomiri.Components.Popups 1.3
import Lomiri.Content 1.3
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
import QtQuick 2.12
import QtQuick.Layouts 1.12
import UserMetrics 0.1
import io.thp.pyotherside 1.4
import "ut_components"

Page {
    id: photoDetailPage

    property string filePath: ""
    property string photoId: ""
    property string photoName: ""
    property string fileType: "IMAGE"
    property bool isLoading: true
    property string previousId: ""
    property string nextId: ""
    property bool isFavorite: false
    property bool isArchived: false
    property bool isDeleted: false
    property string previewType: "timeline"
    property string albumId: ""
    property string personId: ""
    property string locationId: ""
    property string searchQuery: ""
    property var currentMediaItem: photoDetailPage.filePath !== "" ? ({
        "filePath": photoDetailPage.filePath,
        "id": photoDetailPage.photoId,
        "fileType": photoDetailPage.fileType,
        "name": photoDetailPage.photoName
    }) : null
    readonly property var previousMediaItem: photoDetailPage.isLoading ? undefined : (photoDetailPage.previousId !== "" ? ({
        "id": photoDetailPage.previousId
    }) : null)
    readonly property var nextMediaItem: photoDetailPage.isLoading ? undefined : (photoDetailPage.nextId !== "" ? ({
        "id": photoDetailPage.nextId
    }) : null)

    function setCurrentMedia(path, mediaType, mediaName) {
        photoDetailPage.filePath = path || "";
        photoDetailPage.fileType = mediaType || "IMAGE";
        photoDetailPage.photoName = mediaName || "";
        photoDetailPage.currentMediaItem = photoDetailPage.filePath !== "" ? ({
            "filePath": photoDetailPage.filePath,
            "id": photoDetailPage.photoId,
            "fileType": photoDetailPage.fileType,
            "name": photoDetailPage.photoName
        }) : null;
    }

    function loadPhotoDetails() {
        photoDetailPage.isLoading = true;
        photosViewedMetric.increment(1);
        python.call('immich_client.preview', [photoId, previewType, albumId, personId, locationId, searchQuery], function(result) {
            if (result) {
                photoDetailPage.setCurrentMedia(result.filePath || photoDetailPage.filePath, result.file_type || photoDetailPage.fileType, result.name || photoDetailPage.photoName);
                photoDetailPage.previousId = result.previous || "";
                photoDetailPage.nextId = result.next || "";
                photoDetailPage.isFavorite = result.favorite || false;
                photoDetailPage.isArchived = result.archived || false;
                photoDetailPage.isDeleted = result.deleted || false;
            }
            photoDetailPage.isLoading = false;
        });
    }

    function resetImageZoom() {
        if (mediaLoader.item && mediaLoader.item.resetZoom)
            mediaLoader.item.resetZoom();

    }

    function navigateToPrevious() {
        if (photoDetailPage.previousId && photoDetailPage.previousId !== "") {
            resetImageZoom();
            photoDetailPage.photoId = photoDetailPage.previousId;
            loadPhotoDetails();
        }
    }

    function navigateToNext() {
        if (photoDetailPage.nextId && photoDetailPage.nextId !== "") {
            resetImageZoom();
            photoDetailPage.photoId = photoDetailPage.nextId;
            loadPhotoDetails();
        }
    }

    Metric {
        id: photosViewedMetric

        name: "immich_photos_viewed"
        format: "%1 " + i18n.tr("Immich photos viewed today")
        emptyFormat: i18n.tr("No Immich photos viewed today")
        domain: "picpocket.brennoflavio"
    }

    Python {
        id: python

        Component.onCompleted: {
            addImportPath(Qt.resolvedUrl('../src/'));
            photoDetailPage.setCurrentMedia(photoDetailPage.filePath, photoDetailPage.fileType, photoDetailPage.photoName);
            importModule('immich_client', function() {
                if (photoId && photoId !== "")
                    loadPhotoDetails();

            });
        }
        onError: {
            photoDetailPage.isLoading = false;
        }
    }

    Item {
        anchors {
            top: pageHeader.bottom
            left: parent.left
            right: parent.right
            bottom: bottomBar.top
        }

        Loader {
            id: mediaLoader

            anchors.fill: parent
            sourceComponent: photoDetailPage.currentMediaItem && photoDetailPage.currentMediaItem.fileType === "VIDEO" ? videoComponent : imageComponent
        }

        ActivityIndicator {
            anchors.centerIn: parent
            running: photoDetailPage.isLoading
            visible: running
            z: 1
        }

        Component {
            id: imageComponent

            ImageViewer {
                anchors.fill: parent
                currentItem: photoDetailPage.currentMediaItem
                previousItem: photoDetailPage.previousMediaItem
                nextItem: photoDetailPage.nextMediaItem
                maximumZoom: 4
                onPreviousTriggered: photoDetailPage.navigateToPrevious()
                onNextTriggered: photoDetailPage.navigateToNext()
            }

        }

        Component {
            id: videoComponent

            VideoViewer {
                anchors.fill: parent
                currentItem: photoDetailPage.currentMediaItem
                previousItem: photoDetailPage.previousMediaItem
                nextItem: photoDetailPage.nextMediaItem
                onPreviousTriggered: photoDetailPage.navigateToPrevious()
                onNextTriggered: photoDetailPage.navigateToNext()
            }

        }

    }

    BottomBar {
        id: bottomBar

        anchors {
            left: parent.left
            right: parent.right
            bottom: parent.bottom
        }

        IconButton {
            id: shareButton

            iconName: "share"
            text: i18n.tr("Share")
            onClicked: {
                if (photoDetailPage.photoId && photoDetailPage.photoId !== "") {
                    shareButton.enabled = false;
                    python.call('immich_client.original', [photoDetailPage.photoId], function(result) {
                        shareButton.enabled = true;
                        if (result && result !== "")
                            pageStack.push(sharePage, {
                            "imageUrl": "file://" + result
                        });

                    });
                }
            }
        }

        IconButton {
            iconName: photoDetailPage.isFavorite ? "starred" : "non-starred"
            text: i18n.tr("Favorite")
            onClicked: {
                var newFavoriteState = !photoDetailPage.isFavorite;
                photoDetailPage.isFavorite = newFavoriteState;
                python.call('immich_client.favorite', [photoDetailPage.photoId, newFavoriteState], function(result) {
                });
            }
        }

        IconButton {
            iconName: photoDetailPage.isArchived ? "reset" : "save"
            text: photoDetailPage.isArchived ? i18n.tr("Unarchive") : i18n.tr("Archive")
            onClicked: {
                var methodName = photoDetailPage.isArchived ? 'immich_client.unarchive' : 'immich_client.archive';
                python.call(methodName, [photoDetailPage.photoId], function(result) {
                    python.call('immich_client.clear_cache', [], function() {
                        pageStack.clear();
                        pageStack.push(Qt.resolvedUrl("GalleryPage.qml"));
                    });
                });
            }
        }

        IconButton {
            iconName: "delete"
            text: i18n.tr("Trash")
            visible: !photoDetailPage.isDeleted
            onClicked: {
                python.call('immich_client.delete', [photoDetailPage.photoId], function(result) {
                    python.call('immich_client.clear_cache', [], function() {
                        pageStack.clear();
                        pageStack.push(Qt.resolvedUrl("GalleryPage.qml"));
                    });
                });
            }
        }

        IconButton {
            iconName: "view-restore"
            text: i18n.tr("Restore")
            visible: photoDetailPage.isDeleted
            onClicked: {
                python.call('immich_client.undelete', [photoDetailPage.photoId], function(result) {
                    python.call('immich_client.clear_cache', [], function() {
                        pageStack.clear();
                        pageStack.push(Qt.resolvedUrl("GalleryPage.qml"));
                    });
                });
            }
        }

        IconButton {
            iconName: "toolkit_cross"
            text: i18n.tr("Delete")
            visible: photoDetailPage.isDeleted
            onClicked: {
                python.call('immich_client.permanently_delete', [photoDetailPage.photoId], function(result) {
                    python.call('immich_client.clear_cache', [], function() {
                        pageStack.clear();
                        pageStack.push(Qt.resolvedUrl("GalleryPage.qml"));
                    });
                });
            }
        }

    }

    Component {
        id: sharePage

        Page {
            id: sharePageInstance

            property string imageUrl: ""
            property var activeTransfer

            ContentPeerPicker {
                id: peerPicker

                contentType: ContentType.Pictures
                handler: ContentHandler.Share
                onPeerSelected: {
                    sharePageInstance.activeTransfer = peer.request();
                    if (sharePageInstance.activeTransfer) {
                        sharePageInstance.activeTransfer.items = [contentItem];
                        sharePageInstance.activeTransfer.state = ContentTransfer.Charged;
                        pageStack.pop();
                    }
                }
                onCancelPressed: {
                    if (sharePageInstance.activeTransfer)
                        sharePageInstance.activeTransfer.state = ContentTransfer.Aborted;

                    pageStack.pop();
                }

                anchors {
                    top: shareHeader.bottom
                    left: parent.left
                    right: parent.right
                    bottom: parent.bottom
                }

            }

            ContentItem {
                id: contentItem

                url: sharePageInstance.imageUrl
                name: photoDetailPage.photoName
            }

            header: PageHeader {
                id: shareHeader

                title: i18n.tr("Share")
                leadingActionBar.actions: [
                    Action {
                        iconName: "back"
                        onTriggered: {
                            if (sharePageInstance.activeTransfer)
                                sharePageInstance.activeTransfer.state = ContentTransfer.Aborted;

                            pageStack.pop();
                        }
                    }
                ]
            }

        }

    }

    header: AppHeader {
        id: pageHeader

        pageTitle: photoDetailPage.photoName
        isRootPage: false
        showSettingsButton: false
    }

}
