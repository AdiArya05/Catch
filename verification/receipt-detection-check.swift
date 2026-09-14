struct PendingLiveBoardTrip: Codable {
    let stopCode: String
    var stopName: String
    var serviceNo: String
    let startedAt: Date
    var stopLatitude: Double?
    var stopLongitude: Double?
    let initialArrivalMinutes: Int?
    var sawArrivalAt: Date?
    var wasNearStop: Bool?
}

import Foundation
import CoreLocation
class LocationManager { var location: CLLocation? }
class Harness {
var locationManager = LocationManager()
var pendingLiveBoardTrip: PendingLiveBoardTrip?
var count = 0
func persistPendingLiveBoardTrip() {}
func cancelLiveBoardTripTracking() { pendingLiveBoardTrip = nil }
func recordCompletedLiveBoardTrip(_ trip: PendingLiveBoardTrip) { count += 1 }
    func completeLiveBoardTripIfReady() {
        guard var trip = pendingLiveBoardTrip else { return }
        if let location = locationManager.location,
           location.horizontalAccuracy >= 0, location.horizontalAccuracy <= 65,
           abs(location.timestamp.timeIntervalSinceNow) < 60,
           let latitude = trip.stopLatitude, let longitude = trip.stopLongitude,
           location.distance(from: CLLocation(latitude: latitude, longitude: longitude)) <= 100 {
            trip.wasNearStop = true
            pendingLiveBoardTrip = trip
            persistPendingLiveBoardTrip()
        }
        guard trip.wasNearStop == true, let sawArrivalAt = trip.sawArrivalAt else { return }
        let now = Date()
        guard now.timeIntervalSince(sawArrivalAt) <= 10 * 60 else {
            cancelLiveBoardTripTracking()
            return
        }

        guard isUserAwayFromTrackedStop(trip) else { return }
        recordCompletedLiveBoardTrip(trip)
        cancelLiveBoardTripTracking()
    }

    func isUserAwayFromTrackedStop(_ trip: PendingLiveBoardTrip) -> Bool {
        guard let location = locationManager.location,
              location.horizontalAccuracy >= 0, location.horizontalAccuracy <= 65,
              abs(location.timestamp.timeIntervalSinceNow) < 60,
              let latitude = trip.stopLatitude,
              let longitude = trip.stopLongitude else { return false }

        let stopLocation = CLLocation(latitude: latitude, longitude: longitude)
        return location.distance(from: stopLocation) > 150
    }


}
func location(_ lat: Double, accuracy: Double = 10, age: Double = 0) -> CLLocation {
 CLLocation(coordinate: CLLocationCoordinate2D(latitude: lat, longitude: 103.8), altitude: 0, horizontalAccuracy: accuracy, verticalAccuracy: 10, timestamp: Date().addingTimeInterval(-age))
}
let h = Harness()
func reset() { h.pendingLiveBoardTrip = PendingLiveBoardTrip(stopCode:"1",stopName:"Test",serviceNo:"23",startedAt:Date(),stopLatitude:1.3,stopLongitude:103.8,initialArrivalMinutes:0,sawArrivalAt:Date()) }
reset(); h.locationManager.location = location(1.31); h.completeLiveBoardTripIfReady(); assert(h.count == 0)
h.locationManager.location = location(1.3); h.completeLiveBoardTripIfReady(); assert(h.pendingLiveBoardTrip?.wasNearStop == true)
h.locationManager.location = location(1.31, accuracy:200); h.completeLiveBoardTripIfReady(); assert(h.count == 0)
h.locationManager.location = location(1.31, age:120); h.completeLiveBoardTripIfReady(); assert(h.count == 0)
h.locationManager.location = location(1.31); h.completeLiveBoardTripIfReady(); assert(h.count == 1 && h.pendingLiveBoardTrip == nil)
h.completeLiveBoardTripIfReady(); assert(h.count == 1)
reset(); h.pendingLiveBoardTrip?.sawArrivalAt = nil; h.locationManager.location = location(1.3); h.completeLiveBoardTripIfReady(); h.locationManager.location = location(1.31); h.completeLiveBoardTripIfReady(); assert(h.count == 1)
print("PASS: no remote-start trip, no stale/inaccurate location trip, near-arrival-departure counts once, departure without arrival does not count")
