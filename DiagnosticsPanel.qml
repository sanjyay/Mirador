import QtQuick
import Quickshell.Io
import qs.Commons
import qs.Commons as Commons
import qs.Ui
FocusScope {
  id:root
  property var checks:[]
  signal dismissed()
  function refresh() {
    if (probe.running) return
    root.checks=[]
    probe.running=true
  }
  onVisibleChanged: {
    if (visible) { refresh();forceActiveFocus() }
    else probe.running=false
  }
  Keys.onPressed:function(event) {
    if (event.key===Qt.Key_Escape || event.key===Qt.Key_F3) root.dismissed()
    else if (event.key===Qt.Key_R) root.refresh()
    else if (event.key===Qt.Key_Down) scroll.contentY=Math.min(Math.max(0,scroll.contentHeight-scroll.height),scroll.contentY+Style.space(40))
    else if (event.key===Qt.Key_Up) scroll.contentY=Math.max(0,scroll.contentY-Style.space(40))
    else return
    event.accepted=true
  }
  Process {
    id:probe
    command:["python3",decodeURIComponent(Qt.resolvedUrl("bin/mirador-doctor").toString().replace(/^file:\/\//,"")),"--json"]
    stdout:StdioCollector {
      onStreamFinished: {
        try {
          var report=JSON.parse(text)
          root.checks=Array.isArray(report.checks) ? report.checks : []
        } catch(error) { root.checks=[{name:"Report",status:"error",detail:"Could not read the setup report. Run mirador --doctor from a terminal."}] }
      }
    }
    onExited:function(code,status) {
      if (root.visible && root.checks.length===0) root.checks=[{name:"Report",status:"error",detail:"The report could not start. Check that Python 3 is installed."}]
    }
  }
  Rectangle {anchors.fill:parent;color:Commons.Color.background;border.width:Style.normalBorderWidth;border.color:Commons.Color.accent;MouseArea{anchors.fill:parent}}
  Flickable {
    id:scroll
    anchors {fill:parent;margins:Style.space(20)}
    clip:true;contentWidth:width;contentHeight:content.implicitHeight
    boundsBehavior:Flickable.StopAtBounds
    Column {
      id:content;width:scroll.width;spacing:Style.space(16)
      Text {width:parent.width;text:"Mirador setup checks";textFormat:Text.PlainText;color:Commons.Color.foreground;font.family:Style.font.family;font.pixelSize:Style.font.heading}
      Text {width:parent.width;text:probe.running ? "Checking…" : "Read-only checks. Window titles and addresses are omitted.";textFormat:Text.PlainText;wrapMode:Text.WordWrap;color:Commons.Color.foreground;font.family:Style.font.family;font.pixelSize:Style.font.body}
      Repeater {
        model:root.checks
        Column {
          required property var modelData
          width:content.width;spacing:Style.space(4)
          Text {width:parent.width;text:String(modelData.status).toUpperCase()+" · "+modelData.name;textFormat:Text.PlainText;color:Commons.Color.accent;font.family:Style.font.family;font.pixelSize:Style.font.body}
          Text {width:parent.width;text:modelData.detail;textFormat:Text.PlainText;wrapMode:Text.WordWrap;color:Commons.Color.foreground;font.family:Style.font.family;font.pixelSize:Style.font.bodySmall}
        }
      }
      Row {spacing:Style.space(12);Button{text:"Refresh · R";onClicked:root.refresh()} Button{text:"Close · Esc";onClicked:root.dismissed()}}
    }
  }
}
