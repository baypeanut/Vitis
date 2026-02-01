//
//  WineCategoryResolverTests.swift
//  VitisTests
//
//  Unit tests for WineCategoryResolver determinism.
//

import XCTest
@testable import Vitis

final class WineCategoryResolverTests: XCTestCase {

    func testExplicitCategoryRed() {
        XCTAssertEqual(WineCategoryResolver.resolve(category: "Red", variety: nil, name: nil), "Red")
    }

    func testExplicitCategoryWhite() {
        XCTAssertEqual(WineCategoryResolver.resolve(category: "White", variety: nil, name: nil), "White")
    }

    func testVarietyImpliesRed() {
        XCTAssertEqual(WineCategoryResolver.resolve(category: nil, variety: "Cabernet Sauvignon", name: nil), "Red")
    }

    func testVarietyImpliesWhite() {
        XCTAssertEqual(WineCategoryResolver.resolve(category: nil, variety: "Chardonnay", name: nil), "White")
    }

    func testNameImpliesSparkling() {
        XCTAssertEqual(WineCategoryResolver.resolve(category: nil, variety: nil, name: "Prosecco DOC"), "Sparkling")
    }

    func testUnknownFallsToOther() {
        XCTAssertEqual(WineCategoryResolver.resolve(category: nil, variety: nil, name: "Unknown Wine"), "Other")
    }
}
