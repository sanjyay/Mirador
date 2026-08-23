import QtQuick 2.15
import QtTest 1.3

TestCase {
  name: "WindowPreviewSecurity"
  property var hostileTitles: [
    "<b>Injected</b>",
    "<i>Title</i>",
    "<a href=\"https://example.invalid\">click</a>",
    "<img src=\"https://example.invalid/x.png\">"
  ]

  Text {
    id: defaultText
  }

  Text {
    id: securedText
    textFormat: Text.PlainText
  }

  function initTestCase() {
    compare(defaultText.textFormat, Text.AutoText)
  }

  function windowPreviewSource() {
    var request = new XMLHttpRequest()
    request.open("GET", Qt.resolvedUrl("../WindowPreview.qml"), false)
    request.send()
    verify(request.status === 0 || request.status === 200)
    return request.responseText
  }

  function test_windowTitleSinkExplicitlyUsesPlainText() {
    var source = windowPreviewSource()
    verify(/text\s*:\s*root\.title\s*\n\s*textFormat\s*:\s*Text\.PlainText/.test(source))
  }

  function test_hostileTitlesRemainPlainText() {
    compare(securedText.textFormat, Text.PlainText)

    for (var i = 0; i < hostileTitles.length; i++) {
      securedText.text = hostileTitles[i]
      compare(securedText.text, hostileTitles[i])
    }
  }
}
