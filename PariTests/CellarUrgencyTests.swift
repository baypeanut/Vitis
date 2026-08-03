//
//  CellarUrgencyTests.swift
//  PariTests
//
//  The urgency strings are produced by open_tonight in SQL and parsed here. A
//  mismatch does not crash, it silently degrades every bottle to "no window yet",
//  which is exactly the kind of failure nobody notices until the wine is gone.
//
//  These cases are copied from the CASE expression in
//  supabase/migrations/20260803000013_cellar_bottles.sql. If that changes, this
//  should fail.
//

import XCTest
@testable import Pari

final class CellarUrgencyTests: XCTestCase {

    func testPastMapsFromSQL() {
        XCTAssertEqual(CellarBottle.Urgency(rawValue: "past"), .past)
    }

    /// The SQL emits a space, not camel case. This is the one most likely to rot.
    func testDrinkNowMapsFromSpacedSQLValue() {
        XCTAssertEqual(CellarBottle.Urgency(rawValue: "drink now"), .drinkNow)
    }

    func testReadyMapsFromSQL() {
        XCTAssertEqual(CellarBottle.Urgency(rawValue: "ready"), .ready)
    }

    func testStillYoungMapsFromSpacedSQLValue() {
        XCTAssertEqual(CellarBottle.Urgency(rawValue: "still young"), .stillYoung)
    }

    func testUnknownMapsFromSQL() {
        XCTAssertEqual(CellarBottle.Urgency(rawValue: "unknown"), .unknown)
    }

    func testUnrecognisedValueFallsBackRatherThanCrashing() {
        XCTAssertEqual(CellarBottle.Urgency(rawValue: "something new"), .unknown)
    }

    func testEveryCaseHasADistinctLabel() {
        let cases: [CellarBottle.Urgency] = [.past, .drinkNow, .ready, .stillYoung, .unknown]
        let labels = Set(cases.map(\.label))
        XCTAssertEqual(labels.count, cases.count, "two urgency states share a label")
        XCTAssertFalse(labels.contains(where: \.isEmpty))
    }

    /// Curator attribution is the reason the editorial layer exists. An unsigned
    /// collection is the thing it is meant to avoid.
    func testAttributionAlwaysNamesTheCurator() {
        let withCredential = CuratedCollection(
            id: UUID(), slug: "s", title: "T", subtitle: nil,
            curatorName: "Deniz", curatorCredential: "Master Sommelier",
            curatorAvatarURL: nil, wineCount: 6
        )
        XCTAssertTrue(withCredential.attribution.contains("Deniz"))
        XCTAssertTrue(withCredential.attribution.contains("Master Sommelier"))

        let withoutCredential = CuratedCollection(
            id: UUID(), slug: "s", title: "T", subtitle: nil,
            curatorName: "Deniz", curatorCredential: nil,
            curatorAvatarURL: nil, wineCount: 6
        )
        XCTAssertTrue(withoutCredential.attribution.contains("Deniz"))
        XCTAssertFalse(withoutCredential.attribution.hasSuffix(", "))
    }
}
