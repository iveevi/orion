import Quickshell
import Quickshell.Io
import Quickshell.Wayland
import Quickshell.Widgets
import QtQuick
import QtQuick.Controls

ShellRoot {
    id: root

    property bool opened: false
    property var entries: []

    function refilter() {
        const needle = search.text.toLowerCase()
        results.clear()
        for (const entry of root.entries) {
            if (needle === "" || entry.name.toLowerCase().includes(needle))
                results.append(entry)
        }
        list.currentIndex = 0
    }

    function activate(index) {
        if (index < 0 || index >= results.count) return
        Quickshell.execDetached(["sh", "-c", results.get(index).exec])
        root.opened = false
    }

    ListModel { id: results }

    Process {
        running: true
        command: ["python3", Quickshell.shellDir + "/scan.py"]
        stdout: StdioCollector {
            onStreamFinished: {
                const parsed = []
                for (const line of text.trim().split("\n")) {
                    const parts = line.split("\t")
                    if (parts.length === 3) parsed.push({ name: parts[0], exec: parts[1], icon: parts[2] })
                }
                root.entries = parsed
                root.refilter()
            }
        }
    }

    IpcHandler {
        target: "launcher"
        function toggle(): void {
            root.opened = !root.opened
            if (root.opened) {
                search.text = ""
                root.refilter()
                search.forceActiveFocus()
            }
        }
    }

    PanelWindow {
        visible: root.opened
        color: "transparent"
        anchors { top: true; left: true; right: true; bottom: true }
        WlrLayershell.layer: WlrLayer.Overlay
        WlrLayershell.keyboardFocus: WlrKeyboardFocus.Exclusive

        Rectangle {
            anchors.centerIn: parent
            width: Theme.windowWidth
            height: Theme.windowHeight
            radius: Theme.radius
            color: Theme.background
            border.color: Theme.border

            Rectangle {
                id: header
                anchors.left: parent.left
                anchors.right: parent.right
                anchors.top: parent.top
                height: Theme.headHeight
                color: Theme.headerWash

                TextField {
                    id: search
                    anchors.fill: parent
                    leftPadding: Theme.padding
                    rightPadding: Theme.padding
                    verticalAlignment: TextInput.AlignVCenter
                    placeholderText: "Search"
                    color: Theme.foreground
                    placeholderTextColor: Theme.muted
                    font.family: Theme.fontFamily
                    font.pixelSize: Theme.fontSize
                    background: null
                    onTextChanged: root.refilter()
                    onAccepted: root.activate(list.currentIndex)
                    Keys.onEscapePressed: root.opened = false
                    Keys.onDownPressed: list.incrementCurrentIndex()
                    Keys.onUpPressed: list.decrementCurrentIndex()
                }

                Rectangle {
                    anchors.left: parent.left
                    anchors.right: parent.right
                    anchors.bottom: parent.bottom
                    height: 1
                    color: Theme.rule
                }
            }

            ListView {
                id: list
                anchors.left: parent.left
                anchors.right: parent.right
                anchors.top: header.bottom
                anchors.bottom: parent.bottom
                anchors.bottomMargin: Theme.spacing
                topMargin: Theme.spacing
                clip: true
                model: results
                delegate: Rectangle {
                    id: row
                    width: list.width
                    height: Theme.rowHeight
                    radius: Theme.radius
                    color: ListView.isCurrentItem ? Theme.highlight : "transparent"

                    IconImage {
                        id: icon
                        anchors.left: parent.left
                        anchors.leftMargin: Theme.padding
                        anchors.verticalCenter: parent.verticalCenter
                        implicitSize: Theme.iconSize
                        source: model.icon ? "file://" + model.icon : ""
                    }

                    Text {
                        anchors.left: icon.right
                        anchors.leftMargin: Theme.spacing
                        anchors.right: parent.right
                        anchors.rightMargin: Theme.spacing
                        anchors.verticalCenter: parent.verticalCenter
                        elide: Text.ElideRight
                        text: model.name
                        color: row.ListView.isCurrentItem ? Theme.accent : Theme.foreground
                        font.family: Theme.fontFamily
                        font.pixelSize: Theme.fontSize
                    }

                    MouseArea {
                        anchors.fill: parent
                        onClicked: root.activate(index)
                    }
                }
            }
        }
    }
}
