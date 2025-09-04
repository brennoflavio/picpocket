/*
 * Copyright (C) 2025  Brenno Flávio de Almeida
 *
 * This program is free software: you can redistribute it and/or modify
 * it under the terms of the GNU General Public License as published by
 * the Free Software Foundation; version 3.
 *
 * picpocket is distributed in the hope that it will be useful,
 * but WITHOUT ANY WARRANTY; without even the implied warranty of
 * MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
 * GNU General Public License for more details.
 *
 * You should have received a copy of the GNU General Public License
 * along with this program.  If not, see <http://www.gnu.org/licenses/>.
 */

import QtQuick 2.7
import Lomiri.Components 1.3
//import QtQuick.Controls 2.2
import QtQuick.Layouts 1.3
import Qt.labs.settings 1.0
import io.thp.pyotherside 1.4
import "lib"
import Lomiri.PushNotifications 0.1

MainView {
    id: root
    objectName: 'mainView'
    applicationName: 'picpocket.brennoflavio'
    automaticOrientation: true

    width: units.gu(45)
    height: units.gu(75)

    PushClient {
            id: pushClient
            appId: "picpocket.brennoflavio_picpocket"
            onTokenChanged: {
                python.call('immich_client.persist_token', [pushClient.token])
            }
    }

    PageStack {
        id: pageStack
        anchors.fill: parent

        Component.onCompleted: {
            pageStack.push(loginPage)
        }
    }

    Component {
        id: galleryPage
        GalleryPage {}
    }

    Component {
        id: photoDetailPage
        PhotoDetail {}
    }

    Component {
        id: loginPage
        Page {
            anchors.fill: parent

            header: AppHeader {
                id: header
                pageTitle: i18n.tr('PicPocket')
                iconName: "stock_image"
            }

        Flickable {
            anchors {
                top: header.bottom
                left: parent.left
                right: parent.right
                bottom: parent.bottom
            }
            contentHeight: loginContent.height + units.gu(4)

            Item {
                id: loginContent
                anchors {
                    left: parent.left
                    right: parent.right
                    top: parent.top
                    topMargin: units.gu(4)
                }
                height: childrenRect.height

                ColumnLayout {
                    anchors {
                        left: parent.left
                        right: parent.right
                        margins: units.gu(2)
                    }
                    spacing: units.gu(2)

                    Label {
                        text: i18n.tr("Sign in to Immich")
                        fontSize: "x-large"
                        font.weight: Font.Medium
                        Layout.alignment: Qt.AlignHCenter
                        Layout.bottomMargin: units.gu(2)
                    }

                    InputField {
                        id: serverUrlField
                        title: i18n.tr("Server URL")
                        placeholder: i18n.tr("https://your-server.com")
                        validationRegex: "^https?://[^\\s]+$"
                        errorMessage: i18n.tr("Please enter a valid URL")
                        Layout.fillWidth: true
                    }

                    InputField {
                        id: emailField
                        title: i18n.tr("Email")
                        placeholder: i18n.tr("user@example.com")
                        inputMethodHints: Qt.ImhEmailCharactersOnly
                        validationRegex: "^[^\\s@]+@[^\\s@]+\\.[^\\s@]+$"
                        errorMessage: i18n.tr("Please enter a valid email")
                        Layout.fillWidth: true
                    }

                    InputField {
                        id: passwordField
                        title: i18n.tr("Password")
                        placeholder: i18n.tr("Enter your password")
                        echoMode: TextInput.Password
                        Layout.fillWidth: true
                    }

                    ActionButton {
                        id: loginButton
                        text: i18n.tr("Sign In")
                        iconName: "go-next"
                        Layout.alignment: Qt.AlignHCenter
                        Layout.topMargin: units.gu(2)
                        Layout.preferredWidth: units.gu(30)
                        Layout.preferredHeight: units.gu(6)

                        onClicked: {
                            if (serverUrlField.validate() && emailField.validate() && passwordField.text.length > 0) {
                                errorLabel.visible = false
                                python.call('immich_client.login', [
                                    serverUrlField.text,
                                    emailField.text,
                                    passwordField.text
                                ], function(result) {
                                    if (result.success) {
                                        pageStack.clear()
                                        pageStack.push(galleryPage)
                                    } else {
                                        errorLabel.text = result.message
                                        errorLabel.visible = true
                                    }
                                });
                            } else {
                                serverUrlField.validate();
                                emailField.validate();
                                if (passwordField.text.length === 0) {
                                    passwordField.showError = true;
                                }
                            }
                        }
                    }

                    Label {
                        id: errorLabel
                        visible: false
                        color: theme.palette.normal.negative
                        Layout.alignment: Qt.AlignHCenter
                        Layout.fillWidth: true
                        horizontalAlignment: Text.AlignHCenter
                        wrapMode: Text.WordWrap
                    }
                }
            }
        }
    }
    }

    Python {
        id: python

        Component.onCompleted: {
            addImportPath(Qt.resolvedUrl('../src/'));

            importModule('immich_client', function() {
                python.call('immich_client.should_login', [], function(shouldLogin) {
                    if (shouldLogin === false) {
                        pageStack.clear()
                        pageStack.push(galleryPage)
                    }
                });
            });
        }

        onError: {
        }
    }
}
