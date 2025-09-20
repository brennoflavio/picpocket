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
            visible: locationDetailPage.locationPhotosData.previous !== undefined && locationDetailPage.locationPhotosData.previous !== ""
            enabled: locationDetailPage.locationPhotosData.previous !== "" && !loadingToast.showing
            opacity: enabled ? 1.0 : 0.5
            onClicked: {
                if (locationDetailPage.locationPhotosData.previous) {
                    loadLocationDetail(locationDetailPage.locationPhotosData.previous);
                    gallery.scrollPosition = 0;
                }
            }
        }

        rightButton: IconButton {
            iconName: "go-next"
            visible: locationDetailPage.locationPhotosData.next !== undefined && locationDetailPage.locationPhotosData.next !== ""
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
