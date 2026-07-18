// FilePicker.qml
//
// Custom-themed replacement for `zenity --file-selection`. Renders a
// FloatingWindow styled like the rest of aeonshell (Colors singleton,
// same corner radius / border conventions as SettingsWindow), with a
// thumbnail grid for images and simple folder navigation.

import QtQuick
import QtQuick.Layouts
import QtQuick.Controls
import Qt.labs.folderlistmodel
import Quickshell

FloatingWindow {
    id: picker

    property string pickerTitle: "Select File"
    property string initialDir: Quickshell.env("HOME")
    property var nameFilters: ["*.png", "*.jpg", "*.jpeg", "*.webp"]

    signal accepted(string path)
    signal rejected()

    property string currentDir: initialDir
    property string selectedPath: ""
    property string selectedName: ""

    function openAt(dir) {
        picker.currentDir = dir && dir.length > 0 ? dir : picker.initialDir;
        picker.selectedPath = "";
        picker.selectedName = "";
        picker.visible = true;
    }

    function goUp() {
        var clean = picker.currentDir.endsWith("/") ? picker.currentDir.slice(0, -1) : picker.currentDir;
        var idx = clean.lastIndexOf("/");
        picker.currentDir = idx > 0 ? clean.substring(0, idx) : "/";
        picker.selectedPath = "";
        picker.selectedName = "";
    }

    title: pickerTitle
    visible: false
    color: "transparent"
    implicitWidth: 640
    implicitHeight: 520

    onClosed: {
        picker.rejected();
        picker.visible = false;
    }

    FolderListModel {
        id: folderModel
        folder: "file://" + picker.currentDir
        nameFilters: picker.nameFilters
        showDirsFirst: true
        showDotAndDotDot: false
        sortField: FolderListModel.Type
    }

    Rectangle {
        id: winBg
        anchors.fill: parent
        radius: 16
        color: Qt.rgba(Colors.surface.r, Colors.surface.g, Colors.surface.b, 0.98)
        border.color: Qt.rgba(Colors.primary.r, Colors.primary.g, Colors.primary.b, 0.2)
        border.width: 1

        ColumnLayout {
            anchors.fill: parent
            anchors.margins: 18
            spacing: 12

            Item {
                Layout.fillWidth: true
                Layout.preferredHeight: 28

                MouseArea {
                    anchors.fill: parent
                    anchors.rightMargin: 34
                    cursorShape: Qt.SizeAllCursor
                    onPressed: mouse => picker.startSystemMove()
                }

                Text {
                    anchors.verticalCenter: parent.verticalCenter
                    text: picker.pickerTitle
                    color: Colors.surfaceText
                    font.pixelSize: 15
                    font.bold: true
                }

                Rectangle {
                    anchors.right: parent.right
                    anchors.verticalCenter: parent.verticalCenter
                    width: 28
                    height: 28
                    radius: 8
                    color: closeHover.hovered ? Qt.rgba(1, 0.3, 0.3, 0.15) : "transparent"
                    Behavior on color { ColorAnimation { duration: 120 } }

                    HoverHandler { id: closeHover }

                    Text {
                        anchors.centerIn: parent
                        text: "󰅖"
                        color: Colors.surfaceText
                        font.pixelSize: 13
                    }

                    TapHandler {
                        onTapped: {
                            picker.rejected();
                            picker.visible = false;
                        }
                    }
                }
            }

            RowLayout {
                Layout.fillWidth: true
                spacing: 10

                Rectangle {
                    width: 32
                    height: 32
                    radius: 10
                    color: upHover.hovered ? Qt.rgba(Colors.primary.r, Colors.primary.g, Colors.primary.b, 0.15) : Qt.rgba(Colors.surfaceText.r, Colors.surfaceText.g, Colors.surfaceText.b, 0.06)

                    HoverHandler { id: upHover }

                    Text {
                        anchors.centerIn: parent
                        text: "󰜷"
                        color: Colors.surfaceText
                        font.pixelSize: 14
                    }

                    TapHandler { onTapped: picker.goUp() }
                }

                Rectangle {
                    Layout.fillWidth: true
                    Layout.preferredHeight: 32
                    radius: 10
                    color: Qt.rgba(Colors.surfaceText.r, Colors.surfaceText.g, Colors.surfaceText.b, 0.05)

                    Text {
                        anchors.fill: parent
                        anchors.leftMargin: 12
                        anchors.rightMargin: 12
                        verticalAlignment: Text.AlignVCenter
                        text: picker.currentDir
                        color: Qt.rgba(Colors.surfaceText.r, Colors.surfaceText.g, Colors.surfaceText.b, 0.65)
                        font.pixelSize: 13
                        elide: Text.ElideMiddle
                    }
                }
            }

            GridView {
                id: grid
                Layout.fillWidth: true
                Layout.fillHeight: true
                clip: true
                cellWidth: 112
                cellHeight: 112
                model: folderModel

                ScrollBar.vertical: ScrollBar {}

                delegate: Item {
                    width: grid.cellWidth
                    height: grid.cellHeight

                    readonly property bool isDir: fileIsDir
                    readonly property bool isSelected: !isDir && picker.selectedPath === filePath

                    Rectangle {
                        anchors.fill: parent
                        anchors.margins: 6
                        radius: 12
                        color: isSelected ? Qt.rgba(Colors.primary.r, Colors.primary.g, Colors.primary.b, 0.22)
                               : itemHover.hovered ? Qt.rgba(Colors.primary.r, Colors.primary.g, Colors.primary.b, 0.1)
                               : "transparent"
                        border.color: isSelected ? Colors.primary : "transparent"
                        border.width: 1.5
                        Behavior on color { ColorAnimation { duration: 120 } }

                        HoverHandler { id: itemHover }

                        ColumnLayout {
                            anchors.fill: parent
                            anchors.margins: 8
                            spacing: 4

                            Item {
                                Layout.fillWidth: true
                                Layout.fillHeight: true

                                Image {
                                    anchors.fill: parent
                                    visible: !isDir && status === Image.Ready
                                    source: isDir ? "" : fileURL
                                    fillMode: Image.PreserveAspectCrop
                                    asynchronous: true
                                    smooth: true
                                    sourceSize.width: 128
                                    sourceSize.height: 96

                                    Rectangle {
                                        anchors.fill: parent
                                        radius: 8
                                        color: "transparent"
                                        border.color: Qt.rgba(1, 1, 1, 0.08)
                                        border.width: 1
                                    }
                                }

                                Text {
                                    anchors.centerIn: parent
                                    visible: isDir
                                    text: "󰉋"
                                    font.pixelSize: 32
                                    color: Colors.primary
                                }
                            }

                            Text {
                                Layout.fillWidth: true
                                text: fileName
                                color: Colors.surfaceText
                                font.pixelSize: 11
                                horizontalAlignment: Text.AlignHCenter
                                elide: Text.ElideMiddle
                                maximumLineCount: 1
                            }
                        }
                    }

                    TapHandler {
                        onTapped: (eventPoint, button) => {
                            if (!isDir) {
                                picker.selectedPath = filePath;
                                picker.selectedName = fileName;
                            }
                        }
                        onDoubleTapped: {
                            if (isDir) {
                                picker.currentDir = filePath;
                                picker.selectedPath = "";
                                picker.selectedName = "";
                            } else {
                                picker.accepted(filePath);
                                picker.visible = false;
                            }
                        }
                    }
                }
            }

            RowLayout {
                Layout.fillWidth: true
                spacing: 10

                Text {
                    Layout.fillWidth: true
                    text: picker.selectedName || "No file selected"
                    color: Qt.rgba(Colors.surfaceText.r, Colors.surfaceText.g, Colors.surfaceText.b, picker.selectedName ? 0.85 : 0.4)
                    font.pixelSize: 13
                    elide: Text.ElideMiddle
                }

                Rectangle {
                    width: 92
                    height: 34
                    radius: 10
                    color: cancelHover.hovered ? Qt.rgba(Colors.surfaceText.r, Colors.surfaceText.g, Colors.surfaceText.b, 0.12) : Qt.rgba(Colors.surfaceText.r, Colors.surfaceText.g, Colors.surfaceText.b, 0.07)

                    HoverHandler { id: cancelHover }

                    Text {
                        anchors.centerIn: parent
                        text: "Cancel"
                        color: Colors.surfaceText
                        font.pixelSize: 13
                    }

                    TapHandler {
                        onTapped: {
                            picker.rejected();
                            picker.visible = false;
                        }
                    }
                }

                Rectangle {
                    width: 92
                    height: 34
                    radius: 10
                    opacity: picker.selectedPath ? 1.0 : 0.4
                    color: Colors.primary

                    Text {
                        anchors.centerIn: parent
                        text: "Select"
                        color: Colors.background
                        font.pixelSize: 13
                        font.bold: true
                    }

                    TapHandler {
                        enabled: picker.selectedPath !== ""
                        onTapped: {
                            picker.accepted(picker.selectedPath);
                            picker.visible = false;
                        }
                    }
                }
            }
        }
    }
}