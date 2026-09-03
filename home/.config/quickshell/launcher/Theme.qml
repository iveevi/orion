pragma Singleton

import Quickshell
import QtQuick

Singleton {
    readonly property color background: "#141417"
    readonly property color surface: "#202024"
    readonly property color border: "#2b2b31"
    readonly property color highlight: "#2b2b31"
    readonly property color foreground: "#c8ccc6"
    readonly property color muted: "#5c5c62"
    readonly property color accent: "#7bb68d"
    readonly property color headerWash: Qt.rgba(1, 1, 1, 0.045)
    readonly property color rule: Qt.rgba(1, 1, 1, 0.10)

    readonly property real windowWidth: 600
    readonly property real windowHeight: 420
    readonly property real rowHeight: 44
    readonly property real iconSize: 32
    readonly property real headHeight: 40
    readonly property real padding: 14
    readonly property real spacing: 8
    readonly property real radius: 2.5
    readonly property int fontSize: 14
    
    readonly property string fontFamily: "CaskaydiaCove Nerd Font Mono"
}
