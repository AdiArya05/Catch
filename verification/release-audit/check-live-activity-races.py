"""Compile the production manager against controllable ActivityKit doubles."""
from pathlib import Path
import subprocess, tempfile
root=Path(__file__).resolve().parents[2]
source=(root/'Catch/Services/LiveActivityManager.swift').read_text().replace('import ActivityKit','').replace('Activity<CatchStopActivityAttributes>','FakeActivity').replace('Activity.request','FakeActivity.request')
stubs='''
import Foundation
struct ActivityAuthorizationInfo { var areActivitiesEnabled = true }
struct CatchStopActivityAttributes {
 let stopCode: String; let stopName: String; let stopShortName: String; let walkMinutes: Int?; let roadName: String?
 struct ServiceTiming { let serviceNo: String; let arrivals: [Int?]; let busTypes: [String?]; let features: [String?]; let arrivalDate: Date?; let load: String? }
 struct ContentState { let services: [ServiceTiming]; let updatedAt: Date; let progressStartedAt: Date? }
}
struct ActivityContent { let state: CatchStopActivityAttributes.ContentState; let staleDate: Date? }
struct BusInfo { var arrivalMinutes: Int? = 4; var arrivalDate: Date? = Date().addingTimeInterval(240); var BusType: String?; var Feature: String?; var Load: String? }
struct BusService { let ServiceNo: String; var NextBus = BusInfo(); var NextBus2 = BusInfo(); var NextBus3 = BusInfo() }
enum Dismissal { case immediate }
@MainActor final class FakeActivity {
 static var activities: [FakeActivity] = []
 static var requests = 0
 static var waits: [CheckedContinuation<Void, Never>] = []
 let attributes: CatchStopActivityAttributes
 var content: ActivityContent
 init(_ attributes: CatchStopActivityAttributes, _ content: ActivityContent) { self.attributes = attributes; self.content = content }
 static func request(attributes: CatchStopActivityAttributes, content: ActivityContent, pushType: String?) throws -> FakeActivity {
  requests += 1
  let activity = FakeActivity(attributes, content); activities.append(activity); return activity
 }
 func end(_ content: ActivityContent?, dismissalPolicy: Dismissal) async {
  await withCheckedContinuation { Self.waits.append($0) }
  Self.activities.removeAll { $0 === self }
 }
 func update(_ content: ActivityContent) async { self.content = content }
 static func release() { let pending = waits; waits = []; pending.forEach { $0.resume() } }
}
'''
test='''
@main struct Test {
 @MainActor static func main() async {
  let manager = LiveActivityManager.shared
  let seed = CatchStopActivityAttributes(stopCode:"old",stopName:"Old",stopShortName:"Old",walkMinutes:1,roadName:nil)
  let content = ActivityContent(state:.init(services:[],updatedAt:Date(),progressStartedAt:nil),staleDate:nil)
  FakeActivity.activities = [FakeActivity(seed,content)]
  let first = Task { await manager.startStopWatch(stopCode:"A",stopName:"A",walkMinutes:1,services:[BusService(ServiceNo:"1")]) }
  while FakeActivity.waits.count < 1 { await Task.yield() }
  let second = Task { await manager.startStopWatch(stopCode:"B",stopName:"B",walkMinutes:1,services:[BusService(ServiceNo:"2")]) }
  while FakeActivity.waits.count < 2 { await Task.yield() }
  FakeActivity.release()
  await first.value; await second.value
  guard FakeActivity.activities.count == 1, FakeActivity.activities.first?.attributes.stopCode == "B" else { fatalError("Concurrent starts created duplicate or wrong activity") }
  print("PASS: newest concurrent start wins; only one activity exists")
  let third = Task { await manager.startStopWatch(stopCode:"C",stopName:"C",walkMinutes:1,services:[BusService(ServiceNo:"3")]) }
  while FakeActivity.waits.count < 1 { await Task.yield() }
  let stop = Task { await manager.endAll() }
  while FakeActivity.waits.count < 2 { await Task.yield() }
  FakeActivity.release()
  await third.value; await stop.value
  guard FakeActivity.activities.isEmpty else { fatalError("Pending start resurrected after stop") }
  print("PASS: stop cancels a suspended start")
 }
}
'''
with tempfile.TemporaryDirectory() as tmp:
 p=Path(tmp); (p/'check.swift').write_text(stubs+source+test)
 subprocess.run(['swiftc','-parse-as-library',str(p/'check.swift'),'-o',str(p/'check')],check=True)
 subprocess.run([str(p/'check')],check=True,timeout=20)
