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
    property string previousPageHint: ""
    property string nextPageHint: ""
    property string currentPageHint: ""

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

    function loadPeople(pageHint) {
        loadingToast.showing = true;
        loadingToast.message = i18n.tr("Loading people...");
        var args = pageHint ? [pageHint] : [];
        python.call('immich_client.people', args, function (result) {
                if (result) {
                    peopleData = result.people.map(function (person) {
                            return {
                                "id": person.id,
                                "title": person.name,
                                "subtitle": "",
                                "thumbnailSource": person.face_path
                            };
                        });
                    previousPageHint = result.previous || "";
                    nextPageHint = result.next || "";
                    currentPageHint = pageHint || "";
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
        enablePullToRefresh: true
        refreshing: loadingToast.showing

        onItemClicked: {
            pageStack.push(Qt.resolvedUrl("PersonDetailPage.qml"), {
                    "personId": item.id,
                    "personName": item.title
                });
        }

        onRefreshRequested: {
            python.call('immich_client.clear_cache', [], function () {
                    loadPeople(currentPageHint);
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
            visible: previousPageHint !== ""
            enabled: previousPageHint !== "" && !loadingToast.showing
            onClicked: {
                loadPeople(previousPageHint);
            }
        }

        rightButton: IconButton {
            iconName: "go-next"
            visible: nextPageHint !== ""
            enabled: nextPageHint !== "" && !loadingToast.showing
            onClicked: {
                loadPeople(nextPageHint);
            }
        }
    }

    LoadToast {
        id: loadingToast
        showing: false
        message: ""
    }
}
