import QtQuick 2.15
import QtTest 1.3
import ".."
TestCase {
  name: "ContinuousScroll"
  when: windowShown
  ContinuousScroll { id: scroll; distance: 200 }
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
