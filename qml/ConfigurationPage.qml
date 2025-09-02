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

import QtQuick 2.7
import Lomiri.Components 1.3
import io.thp.pyotherside 1.4
import "lib"

Page {
    id: configurationPage

    property int cacheDays: 7
    property bool crashLogsEnabled: false

    header: AppHeader {
        pageTitle: i18n.tr("Configuration")
        showBackButton: true
        showSettingsButton: false

        onBackClicked: pageStack.pop()
    }

    Component.onCompleted: {
        loadConfiguration()
    }

    function loadConfiguration() {
        python.call('immich_client.get_cache_days', [], function(days) {
            if (days !== null && days !== undefined) {
                configurationPage.cacheDays = days;
            }
        });
        python.call('immich_client.get_crash_logs', [], function(enabled) {
            if (enabled !== null && enabled !== undefined) {
                configurationPage.crashLogsEnabled = enabled;
            }
        });
    }

    function setCacheDays(days) {
        python.call('immich_client.set_cache_days', [days], function() {});
    }

    function setCrashLogs(enabled) {
        python.call('immich_client.set_crash_logs', [enabled], function() {});
    }

    function logout() {
        python.call('immich_client.logout', [], function() {
            pageStack.clear();
            pageStack.push(Qt.resolvedUrl("Main.qml"));
        });
    }

    function clearAllCache() {
        loadingToast.message = i18n.tr("Clearing cache...");
        loadingToast.showing = true;

        python.call('immich_client.delete_cache', [], function() {
            loadingToast.showing = false;
            pageStack.clear();
            pageStack.push(Qt.resolvedUrl("GalleryPage.qml"));
        });
    }

    Flickable {
        anchors {
            top: header.bottom
            left: parent.left
            right: parent.right
            bottom: parent.bottom
        }
        contentHeight: contentColumn.height

        Column {
            id: contentColumn
            width: parent.width
            spacing: units.gu(0)

            ConfigurationGroup {
                title: i18n.tr("Immich")

                NumberOption {
                    title: i18n.tr("Cache days")
                    subtitle: i18n.tr("Number of days to cache images")
                    value: configurationPage.cacheDays
                    minimumValue: 1
                    maximumValue: 120
                    onValueUpdated: function(newValue) {
                        configurationPage.cacheDays = newValue;
                        configurationPage.setCacheDays(newValue);
                    }
                }

                Item {
                    width: parent.width
                    height: units.gu(2)
                }

                ActionButton {
                    text: i18n.tr("Clear All Cache")
                    iconName: "delete"
                    backgroundColor: theme.palette.normal.activity
                    anchors.horizontalCenter: parent.horizontalCenter
                    onClicked: {
                        configurationPage.clearAllCache();
                    }
                }

                Item {
                    width: parent.width
                    height: units.gu(2)
                }

                ActionButton {
                    text: i18n.tr("Logout")
                    iconName: "system-log-out"
                    backgroundColor: theme.palette.normal.negative
                    anchors.horizontalCenter: parent.horizontalCenter
                    onClicked: {
                        configurationPage.logout();
                    }
                }
            }

            ConfigurationGroup {
                title: i18n.tr("Misc")

                ToggleOption {
                    title: i18n.tr("Send crash logs")
                    subtitle: i18n.tr("Send anonymous crash reports")
                    checked: configurationPage.crashLogsEnabled
                    onToggled: function(checked) {
                        configurationPage.crashLogsEnabled = checked;
                        configurationPage.setCrashLogs(checked);
                    }
                }
            }
        }
    }

    LoadToast {
        id: loadingToast
        showSpinner: true
    }

    Python {
        id: python

        Component.onCompleted: {
            addImportPath(Qt.resolvedUrl('../src/'));

            importModule('immich_client', function() {});
        }

        onError: {
        }
    }
}
