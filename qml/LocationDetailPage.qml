import QtQuick 2.7
import Lomiri.Components 1.3
import QtQuick.Layouts 1.3
import io.thp.pyotherside 1.4
import "lib"
import "ut_components"

Page {
    id: locationDetailPage

    property string locationId: ""
    property string locationName: ""
    property var selectedImages: []

    header: AppHeader {
        id: header
        pageTitle: locationName || i18n.tr("Location")
        isRootPage: false
        showSettingsButton: true
        onSettingsClicked: {
            pageStack.push(Qt.resolvedUrl("ConfigurationPage.qml"));
        }
    }

    property var locationPhotosData: ({
            "title": "",
            "images": [],
            "previous": "",
            "next": ""
        })

    function loadLocationDetail(bucket) {
        loadingToast.showing = true;
        loadingToast.message = i18n.tr("Loading location photos...");
        var args = [];
        if (bucket && bucket !== "") {
            args = [locationId, bucket];
        } else {
            args = [locationId];
        }
        python.call('immich_client.location_detail', args, function (result) {
                if (result) {
                    locationDetailPage.locationPhotosData = result;
                } else {
                    locationDetailPage.locationPhotosData = {
                        "title": "",
                        "images": [],
                        "previous": "",
                        "next": ""
                    };
                }
                loadingToast.showing = false;
            });
    }

    Python {
        id: python

        Component.onCompleted: {
            addImportPath(Qt.resolvedUrl('../src/'));
            importModule('immich_client', function () {
                    loadLocationDetail("");
                });
        }

        onError: {
            loadingToast.showing = false;
            loadingToast.message = i18n.tr("Error loading location photos");
        }
    }

    Gallery {
        id: gallery
        anchors {
            top: header.bottom
            left: parent.left
            right: parent.right
            bottom: bottomBar.top
        }
        defaultTitle: locationDetailPage.locationPhotosData.title
        images: locationDetailPage.locationPhotosData.images

        onImageClicked: {
            pageStack.push(Qt.resolvedUrl("PhotoDetail.qml"), {
                    "previewType": "location",
                    "locationId": locationDetailPage.locationId,
                    "filePath": imageData.filePath,
                    "photoId": imageData.id || ""
                });
        }

        onSelectionModeExited: {
            locationDetailPage.selectedImages = [];
        }

        onSelectionChanged: function (images) {
            locationDetailPage.selectedImages = images;
        }
    }

    BottomBar {
        id: bottomBar
        anchors {
            left: parent.left
            right: parent.right
            bottom: parent.bottom
        }

        leftButton: IconButton {
            iconName: "go-previous"
            visible: locationDetailPage.locationPhotosData.previous !== undefined && locationDetailPage.locationPhotosData.previous !== "" && !gallery.selectionMode
            enabled: locationDetailPage.locationPhotosData.previous !== "" && !loadingToast.showing
            opacity: enabled ? 1.0 : 0.5
            onClicked: {
                if (locationDetailPage.locationPhotosData.previous) {
                    loadLocationDetail(locationDetailPage.locationPhotosData.previous);
                    gallery.scrollPosition = 0;
                }
            }
        }

        IconButton {
            iconName: "save"
            text: i18n.tr("Archive")
            enabled: locationDetailPage.selectedImages.length > 0 && !loadingToast.showing
            opacity: enabled ? 1.0 : 0.5
            visible: gallery.selectionMode
            onClicked: {
                loadingToast.showing = true;
                loadingToast.message = i18n.tr("Archiving photos...");
                var imageIds = [];
                for (var i = 0; i < locationDetailPage.selectedImages.length; i++) {
                    if (locationDetailPage.selectedImages[i].id) {
                        imageIds.push(locationDetailPage.selectedImages[i].id);
                    }
                }
                python.call('immich_client.archive', imageIds, function (result) {
                        gallery.exitSelectionMode();
                        python.call('immich_client.clear_cache', [], function () {
                                loadLocationDetail("");
                            });
                    });
            }
        }

        IconButton {
            iconName: "delete"
            text: i18n.tr("Trash")
            enabled: locationDetailPage.selectedImages.length > 0 && !loadingToast.showing
            opacity: enabled ? 1.0 : 0.5
            visible: gallery.selectionMode
            onClicked: {
                loadingToast.showing = true;
                loadingToast.message = i18n.tr("Trashing photos...");
                var imageIds = [];
                for (var i = 0; i < locationDetailPage.selectedImages.length; i++) {
                    if (locationDetailPage.selectedImages[i].id) {
                        imageIds.push(locationDetailPage.selectedImages[i].id);
                    }
                }
                python.call('immich_client.delete', imageIds, function (result) {
                        gallery.exitSelectionMode();
                        python.call('immich_client.clear_cache', [], function () {
                                loadLocationDetail("");
                            });
                    });
            }
        }

        rightButton: IconButton {
            iconName: "go-next"
            visible: locationDetailPage.locationPhotosData.next !== undefined && locationDetailPage.locationPhotosData.next !== "" && !gallery.selectionMode
            enabled: locationDetailPage.locationPhotosData.next !== "" && !loadingToast.showing
            opacity: enabled ? 1.0 : 0.5
            onClicked: {
                if (locationDetailPage.locationPhotosData.next) {
                    loadLocationDetail(locationDetailPage.locationPhotosData.next);
                    gallery.scrollPosition = 0;
                }
            }
        }
    }

    LoadToast {
        id: loadingToast
        showing: false
        message: ""
    }
}
