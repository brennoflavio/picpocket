import QtQuick 2.7
import Lomiri.Components 1.3
import io.thp.pyotherside 1.4
import "lib"
import "ut_components"

Page {
    id: peoplePage

    header: AppHeader {
        title: i18n.tr("People")
        showSettingsButton: true
        isRootPage: false
        onSettingsClicked: {
            pageStack.push(Qt.resolvedUrl("ConfigurationPage.qml"));
        }
    }

    property var peopleData: []

    Python {
        id: python

        Component.onCompleted: {
            addImportPath(Qt.resolvedUrl('../src/'));
            importModule('immich_client', function () {
                    loadPeople();
                });
        }

        onError: {
            loadingToast.showing = false;
        }
    }

    function loadPeople() {
        loadingToast.showing = true;
        loadingToast.message = i18n.tr("Loading people...");
        python.call('immich_client.people', [], function (result) {
                if (result) {
                    peopleData = result.people.map(function (person) {
                            return {
                                "id": person.id,
                                "title": person.name ? person.name : i18n.tr("No name"),
                                "subtitle": "",
                                "thumbnailSource": person.face_path
                            };
                        });
                }
                loadingToast.showing = false;
            });
    }

    CardList {
        id: cardList
        anchors {
            top: header.bottom
            left: parent.left
            right: parent.right
            bottom: bottomBar.top
            margins: units.gu(2)
        }

        items: peopleData
        emptyMessage: i18n.tr("No people found")
        showSearchBar: peopleData.length > 5

        onItemClicked: {
            pageStack.push(Qt.resolvedUrl("PersonDetailPage.qml"), {
                    "personId": item.id,
                    "personName": item.title
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

        IconButton {
            iconName: "reload"
            text: i18n.tr("Refresh")
            enabled: !loadingToast.showing
            onClicked: {
                python.call('immich_client.clear_cache', [], function () {
                        loadPeople();
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
