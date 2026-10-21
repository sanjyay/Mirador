import QtQuick
import QtQuick.Effects
import Quickshell
import qs.Commons
import qs.Commons as Commons

Item {
  id: root
  property real dimming: 0.5
  property bool blurWallpaper: false
  readonly property string wallpaperPath: (Quickshell.env("XDG_STATE_HOME") || Quickshell.env("HOME") + "/.local/state") + "/omarchy/current/background"
  // A wallpaper effect avoids changing the compositor's global blur settings.
  Loader {
    anchors.fill: parent
    active: root.visible && root.blurWallpaper
    sourceComponent: Item {
      Image {
        id: wallpaper
        anchors.fill: parent
        source: "file://" + root.wallpaperPath
        fillMode: Image.PreserveAspectCrop
        visible: false
        asynchronous: true
      }
      MultiEffect {
        anchors.fill: parent
        source: wallpaper
        blurEnabled: true
        blurMax: 32
        blur: 0.65
        visible: wallpaper.status === Image.Ready
      }
    }
  }
  Rectangle {
    anchors.fill: parent
    color: Commons.Color.background
    opacity: root.dimming
  }
}
