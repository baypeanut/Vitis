//
//  TrustHintThresholdTests.swift
//  PariTests
//
//  Trust hint threshold logic: >= 3 in last 20.
//

import XCTest
@testable import Pari

final class TrustHintThresholdTests: XCTestCase {

    func testThresholdConstant() {
        XCTAssertGreaterThanOrEqual(WishlistSourceStore.threshold, 3)
        XCTAssertGreaterThanOrEqual(WishlistSourceStore.windowSize, 20)
    }

    func testTrustHintConstantsReasonable() {
        XCTAssertTrue(WishlistSourceStore.windowSize >= WishlistSourceStore.threshold)
    }
}
