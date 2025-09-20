import QtQuick 2.7
import Lomiri.Components 1.3
import io.thp.pyotherside 1.4
import "lib"
import "ut_components"

Page {
    id: locationsPage

    header: AppHeader {
        title: i18n.tr("Locations")
        showSettingsButton: true
        isRootPage: false
        onSettingsClicked: {
            pageStack.push(Qt.resolvedUrl("ConfigurationPage.qml"));
        }
    }

    property var locationsData: []

    Python {
        id: python

        Component.onCompleted: {
            addImportPath(Qt.resolvedUrl('../src/'));
            importModule('immich_client', function () {
                    loadLocations();
                });
        }

        onError: {
            loadingToast.showing = false;
        }
    }

    function loadLocations() {
        loadingToast.showing = true;
        loadingToast.message = i18n.tr("Loading locations...");
        python.call('immich_client.locations', [], function (result) {
                if (result) {
                    locationsData = result.locations.map(function (location) {
                            return {
                                "id": location.id,
                                "title": location.title,
                                "subtitle": location.subtitle,
                                "thumbnailSource": location.thumbnail_path
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

        items: locationsData
        emptyMessage: i18n.tr("No locations found")
        showSearchBar: locationsData.length > 5

        onItemClicked: {
            pageStack.push(Qt.resolvedUrl("LocationDetailPage.qml"), {
                    "locationId": item.id,
                    "locationName": item.title
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
            iconName: "view-refresh"
            text: i18n.tr("Refresh")
            enabled: !loadingToast.showing
            onClicked: {
                python.call('immich_client.clear_cache', [], function () {
                        loadLocations();
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
