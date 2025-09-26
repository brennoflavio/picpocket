import QtQuick 2.7
import Lomiri.Components 1.3
import QtQuick.Layouts 1.3
import io.thp.pyotherside 1.4
import "lib"
import "ut_components"

Page {
    id: personDetailPage

    property string personId: ""
    property string personName: ""
    property var selectedImages: []

    header: AppHeader {
        id: header
        pageTitle: personName || i18n.tr("Person")
        isRootPage: false
        showSettingsButton: true
        onSettingsClicked: {
            pageStack.push(Qt.resolvedUrl("ConfigurationPage.qml"));
        }
    }

    property var personPhotosData: ({
            "title": "",
            "images": [],
            "previous": "",
            "next": ""
        })

    function loadPersonTimeline(hint) {
        loadingToast.showing = true;
        loadingToast.message = i18n.tr("Loading person photos...");
        var args = [];
        if (hint && hint !== "") {
            args = [personId, hint];
        } else {
            args = [personId];
        }
        python.call('immich_client.person_timeline', args, function (result) {
                if (result) {
                    personDetailPage.personPhotosData = result;
                } else {
                    personDetailPage.personPhotosData = {
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
                    loadPersonTimeline("");
                });
        }

        onError: {
            loadingToast.showing = false;
            loadingToast.message = i18n.tr("Error loading person photos");
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
        defaultTitle: personDetailPage.personPhotosData.title
        images: personDetailPage.personPhotosData.images

        onImageClicked: {
            pageStack.push(Qt.resolvedUrl("PhotoDetail.qml"), {
                    "previewType": "person",
                    "personId": personDetailPage.personId,
                    "filePath": imageData.filePath,
                    "photoId": imageData.id || ""
                });
        }

        onSelectionModeExited: {
            personDetailPage.selectedImages = [];
        }

        onSelectionChanged: function (images) {
            personDetailPage.selectedImages = images;
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
            visible: !gallery.selectionMode && personDetailPage.personPhotosData.previous !== undefined && personDetailPage.personPhotosData.previous !== ""
            enabled: personDetailPage.personPhotosData.previous !== "" && !loadingToast.showing
            opacity: enabled ? 1.0 : 0.5
            onClicked: {
                if (personDetailPage.personPhotosData.previous) {
                    loadPersonTimeline(personDetailPage.personPhotosData.previous);
                    gallery.scrollPosition = 0;
                }
            }
        }

        rightButton: IconButton {
            iconName: "go-next"
            visible: !gallery.selectionMode && personDetailPage.personPhotosData.next !== undefined && personDetailPage.personPhotosData.next !== ""
            enabled: personDetailPage.personPhotosData.next !== "" && !loadingToast.showing
            opacity: enabled ? 1.0 : 0.5
            onClicked: {
                if (personDetailPage.personPhotosData.next) {
                    loadPersonTimeline(personDetailPage.personPhotosData.next);
                    gallery.scrollPosition = 0;
                }
            }
        }

        IconButton {
            iconName: "image-x-generic-symbolic"
            text: i18n.tr("Add to Album")
            enabled: personDetailPage.selectedImages.length > 0 && !loadingToast.showing
            opacity: enabled ? 1.0 : 0.5
            visible: gallery.selectionMode
            onClicked: {
                var imageIds = [];
                for (var i = 0; i < personDetailPage.selectedImages.length; i++) {
                    if (personDetailPage.selectedImages[i].id) {
                        imageIds.push(personDetailPage.selectedImages[i].id);
                    }
                }
                pageStack.push(Qt.resolvedUrl("AlbumSelectorPage.qml"), {
                        "selectedAssetIds": imageIds
                    });
            }
        }

        IconButton {
            iconName: "save"
            text: i18n.tr("Archive")
            enabled: personDetailPage.selectedImages.length > 0 && !loadingToast.showing
            opacity: enabled ? 1.0 : 0.5
            visible: gallery.selectionMode
            onClicked: {
                loadingToast.showing = true;
                loadingToast.message = i18n.tr("Archiving photos...");
                var imageIds = [];
                for (var i = 0; i < personDetailPage.selectedImages.length; i++) {
                    if (personDetailPage.selectedImages[i].id) {
                        imageIds.push(personDetailPage.selectedImages[i].id);
                    }
                }
                python.call('immich_client.archive', imageIds, function (result) {
                        gallery.exitSelectionMode();
                        python.call('immich_client.clear_cache', [], function () {
                                loadPersonTimeline("");
                            });
                    });
            }
        }

        IconButton {
            iconName: "delete"
            text: i18n.tr("Trash")
            enabled: personDetailPage.selectedImages.length > 0 && !loadingToast.showing
            opacity: enabled ? 1.0 : 0.5
            visible: gallery.selectionMode
            onClicked: {
                loadingToast.showing = true;
                loadingToast.message = i18n.tr("Trashing photos...");
                var imageIds = [];
                for (var i = 0; i < personDetailPage.selectedImages.length; i++) {
                    if (personDetailPage.selectedImages[i].id) {
                        imageIds.push(personDetailPage.selectedImages[i].id);
                    }
                }
                python.call('immich_client.delete', imageIds, function (result) {
                        gallery.exitSelectionMode();
                        python.call('immich_client.clear_cache', [], function () {
                                loadPersonTimeline("");
                            });
                    });
            }
        }
    }

    LoadToast {
        id: loadingToast
        showing: false
        message: ""
    }
}
