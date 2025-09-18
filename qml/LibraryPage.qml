import QtQuick 2.7
import Lomiri.Components 1.3
import "ut_components"

Page {
    id: libraryPage

    header: AppHeader {
        title: i18n.tr("Library")
        showSettingsButton: true
        isRootPage: false
        onSettingsClicked: {
            pageStack.push(Qt.resolvedUrl("ConfigurationPage.qml"));
        }
    }

    CardList {
        anchors {
            top: header.bottom
            left: parent.left
            right: parent.right
            bottom: parent.bottom
        }

        items: [{
                "title": i18n.tr("People"),
                "subtitle": i18n.tr("Browse photos by people"),
                "icon": "contact"
            }
            // {
            //     title: i18n.tr("Places"),
            //     subtitle: i18n.tr("Browse photos by location"),
            //     icon: "location"
            // },
            // {
            //     title: i18n.tr("Favorites"),
            //     subtitle: i18n.tr("Your favorite photos"),
            //     icon: "starred"
            // },
            // {
            //     title: i18n.tr("Archived"),
            //     subtitle: i18n.tr("Hidden from main view"),
            //     icon: "stock_store"
            // },
            // {
            //     title: i18n.tr("Trash"),
            //     subtitle: i18n.tr("Recently deleted items"),
            //     icon: "delete"
            // }
            ,]

        emptyMessage: i18n.tr("No library options available")

        onItemClicked: {
            switch (item.title) {
            case i18n.tr("People"):
                pageStack.push(Qt.resolvedUrl("PeoplePage.qml"));
                break;
            case i18n.tr("Places"):
                break;
            case i18n.tr("Favorites"):
                break;
            case i18n.tr("Archived"):
                break;
            case i18n.tr("Trash"):
                break;
            }
        }
    }
}
