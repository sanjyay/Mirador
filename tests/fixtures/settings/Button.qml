import QtQuick 2.15
// Headless paint fixture only; dialog behavior comes from SettingsPanel.qml.
Rectangle {
  id: root
  property string text: ""
  property bool leftAlign: false
  property bool hasCursor: false
  signal clicked()
  implicitWidth: label.implicitWidth + 24
  implicitHeight: 36
  color: hasCursor ? "#404080" : "#303030"
  Text { id: label; anchors.centerIn: parent; text: root.text; textFormat: Text.PlainText }
  MouseArea { anchors.fill: parent; onClicked: root.clicked() }
}
