import QtQuick 2.15
import QtTest 1.3
TestCase {
  id: testCase
  name: "ContinuousScroll"
  when: windowShown
  property var scroll: null
  function initTestCase() {
    var request=new XMLHttpRequest()
    request.open("GET",Qt.resolvedUrl("../ContinuousScroll.qml"),false)
    request.send()
    verify(request.status===0 || request.status===200)
    scroll=Qt.createQmlObject(request.responseText,testCase,"ContinuousScrollFixture")
    scroll.distance=200
  }
  function cleanupTestCase() { if (scroll) scroll.destroy() }
  SignalSpy { id: spy; target: scroll; signalName: "finished" }
  function init() { scroll.cancel(); spy.clear() }
  function test_progressAndReverse() {
    verify(scroll.feed(50,0)); compare(scroll.progress,0.25)
    verify(scroll.feed(-30,0)); compare(scroll.progress,0.1)
    scroll.finish(); compare(spy.signalArguments[0][0],0); compare(scroll.progress,0)
  }
  function test_commitOnceAndClamp() {
    scroll.feed(10000,0); compare(scroll.progress,1)
    tryCompare(spy,"count",1,500); compare(spy.signalArguments[0][0],1)
    wait(180); compare(spy.count,1)
  }
  function test_negativeAndRejectedInput() {
    verify(!scroll.feed(NaN,0)); verify(!scroll.feed(2,10)); compare(scroll.progress,0)
    scroll.feed(-100,0); scroll.finish(); compare(spy.signalArguments[0][0],-1)
  }
  function test_cancel() {
    scroll.feed(100,0);scroll.cancel();wait(180);compare(spy.count,0);compare(scroll.progress,0)
  }
}
