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
            "month": "",
            "days": [],
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
                        "month": "",
                        "days": [],
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

    Flickable {
        id: flickable
        anchors {
            top: header.bottom
            left: parent.left
            right: parent.right
            bottom: bottomBar.top
        }
        contentHeight: gallery.height
        clip: true

        PullToRefresh {
            id: pullToRefresh
            parent: flickable
            target: flickable
            refreshing: loadingToast.showing
            onRefresh: {
                python.call('immich_client.clear_cache', [], function () {
                        loadPersonTimeline("");
                    });
            }
        }

        Gallery {
            id: gallery
            width: parent.width
            month: personDetailPage.personPhotosData.month
            days: personDetailPage.personPhotosData.days

            onItemClicked: {
                pageStack.push(Qt.resolvedUrl("PhotoDetail.qml"), {
                        "previewType": "person",
                        "personId": personDetailPage.personId,
                        "filePath": imageData.filePath,
                        "photoId": imageData.id || ""
                    });
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

        leftButton: IconButton {
            iconName: "go-previous"
            visible: personDetailPage.personPhotosData.previous !== undefined && personDetailPage.personPhotosData.previous !== ""
            enabled: personDetailPage.personPhotosData.previous !== "" && !loadingToast.showing
            opacity: enabled ? 1.0 : 0.5
            onClicked: {
                if (personDetailPage.personPhotosData.previous) {
                    loadPersonTimeline(personDetailPage.personPhotosData.previous);
                    flickable.contentY = 0;
                }
            }
        }

        rightButton: IconButton {
            iconName: "go-next"
            visible: personDetailPage.personPhotosData.next !== undefined && personDetailPage.personPhotosData.next !== ""
            enabled: personDetailPage.personPhotosData.next !== "" && !loadingToast.showing
            opacity: enabled ? 1.0 : 0.5
            onClicked: {
                if (personDetailPage.personPhotosData.next) {
                    loadPersonTimeline(personDetailPage.personPhotosData.next);
                    flickable.contentY = 0;
                }
            }
        }
    }

    AbstractButton {
        id: scrollToTopButton
        anchors {
            right: parent.right
            rightMargin: units.gu(2)
            bottom: bottomBar.top
            bottomMargin: units.gu(2)
        }
        width: units.gu(6)
        height: units.gu(6)
        visible: flickable.contentY > units.gu(10)
        opacity: visible ? 1.0 : 0.0

        Behavior on opacity  {
            NumberAnimation {
                duration: 200
            }
        }

        onClicked: {
            flickable.contentY = 0;
        }

        Rectangle {
            anchors.fill: parent
            radius: width / 2
            color: theme.palette.normal.foreground
            opacity: 0.9

            Icon {
                anchors.centerIn: parent
                width: units.gu(3)
                height: units.gu(3)
                name: "up"
                color: theme.palette.normal.foregroundText
            }
        }
    }

    LoadToast {
        id: loadingToast
        showing: false
        message: ""
    }
}
