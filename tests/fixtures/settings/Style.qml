pragma Singleton
import QtQuick 2.15
QtObject {
  function space(value) { return value }
  readonly property int normalBorderWidth: 1
  readonly property var font: ({family:"sans-serif",heading:18,body:14})
}
