//
//  PalateStructureTests.swift
//  PariTests
//
//  The structure grid encodes decisions that are expensive to get wrong: an
//  out-of-range ordinal corrupts the wine vector downstream, and asking for tannin
//  on a Chablis trains people to answer at random.
//

import XCTest
@testable import Pari

final class PalateStructureTests: XCTestCase {

    // MARK: - Range

    func testSubscriptClampsAboveRange() {
        var s = PalateStructure()
        s[.acidity] = 9
        XCTAssertEqual(s.acidity, 5)
    }

    func testSubscriptClampsBelowRange() {
        var s = PalateStructure()
        s[.body] = 0
        XCTAssertEqual(s.body, 1)
    }

    func testSubscriptAcceptsNilToClear() {
        var s = PalateStructure(acidity: 4)
        s[.acidity] = nil
        XCTAssertNil(s.acidity)
    }

    func testSubscriptRoundTripsEveryDimension() {
        var s = PalateStructure()
        for dimension in PalateDimension.allCases {
            s[dimension] = 3
            XCTAssertEqual(s[dimension], 3, "\(dimension) did not round-trip")
        }
    }

    // MARK: - Applicability

    func testTanninHiddenOnWhite() {
        XCTAssertFalse(PalateDimension.tannin.applies(toCategory: "White"))
    }

    func testTanninHiddenOnSparkling() {
        XCTAssertFalse(PalateDimension.tannin.applies(toCategory: "Sparkling"))
    }

    func testTanninShownOnRed() {
        XCTAssertTrue(PalateDimension.tannin.applies(toCategory: "Red"))
    }

    /// Unknown category is not a reason to hide it; an uncategorised red is common
    /// in the catalog and losing tannin on those would quietly starve the model.
    func testTanninShownWhenCategoryUnknown() {
        XCTAssertTrue(PalateDimension.tannin.applies(toCategory: nil))
    }

    func testNonTanninDimensionsAlwaysApply() {
        for dimension in PalateDimension.allCases where dimension != .tannin {
            XCTAssertTrue(dimension.applies(toCategory: "White"), "\(dimension) should apply to white")
        }
    }

    // MARK: - Emptiness

    func testEmptyStructureReportsEmpty() {
        XCTAssertTrue(PalateStructure.empty.isEmpty)
        XCTAssertEqual(PalateStructure.empty.answeredCount, 0)
    }

    func testOneAnswerIsNotEmpty() {
        let s = PalateStructure(tannin: 2)
        XCTAssertFalse(s.isEmpty)
        XCTAssertEqual(s.answeredCount, 1)
    }

    func testAnsweredCountTracksEveryDimension() {
        let s = PalateStructure(acidity: 4, tannin: 3, body: 3,
                                sweetness: 1, aromaIntensity: 4, finish: 4)
        XCTAssertEqual(s.answeredCount, PalateDimension.allCases.count)
    }

    // MARK: - Endpoints

    /// Descriptive words, never quality words. Somm 2's constraint, encoded.
    func testEndpointsAreDescriptiveNotEvaluative() {
        let evaluative = ["good", "bad", "better", "worse", "poor", "excellent"]
        for dimension in PalateDimension.allCases {
            let (low, high) = dimension.endpoints
            for word in evaluative {
                XCTAssertFalse(low.lowercased().contains(word), "\(dimension) low endpoint is evaluative")
                XCTAssertFalse(high.lowercased().contains(word), "\(dimension) high endpoint is evaluative")
            }
            XCTAssertNotEqual(low, high, "\(dimension) endpoints must differ")
        }
    }
}
