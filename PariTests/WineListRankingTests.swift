//
//  WineListRankingTests.swift
//  PariTests
//
//  The list ranking makes two decisions that are expensive to get wrong at a table:
//  how affinity is computed, and where unmatched lines go. Both are tested here.
//

import XCTest
@testable import Pari

final class WineListRankingTests: XCTestCase {

    // MARK: - Affinity

    func testIdenticalVectorsScoreOne() {
        let v = Array(repeating: 1.0 / 8.0, count: 64)   // unit length
        XCTAssertEqual(TasteVectorMath.affinity(v, v)!, 1.0, accuracy: 1e-9)
    }

    func testOrthogonalVectorsScoreZero() {
        var a = Array(repeating: 0.0, count: 64)
        var b = Array(repeating: 0.0, count: 64)
        a[0] = 1.0
        b[1] = 1.0
        XCTAssertEqual(TasteVectorMath.affinity(a, b)!, 0.0, accuracy: 1e-9)
    }

    /// Opposed style is "no information", not negative evidence. Letting it go below
    /// zero would push opposed wines below wines we know nothing about.
    func testOpposedVectorsClampToZero() {
        var a = Array(repeating: 0.0, count: 64)
        var b = Array(repeating: 0.0, count: 64)
        a[0] = 1.0
        b[0] = -1.0
        XCTAssertEqual(TasteVectorMath.affinity(a, b)!, 0.0)
    }

    func testMismatchedLengthsReturnNil() {
        XCTAssertNil(TasteVectorMath.affinity([1.0, 0.0], Array(repeating: 0.0, count: 64)))
    }

    func testEmptyReturnsNil() {
        XCTAssertNil(TasteVectorMath.affinity([], []))
    }

    func testResultNeverExceedsOne() {
        // Non-unit input should still not produce a score above 1.
        let a = Array(repeating: 1.0, count: 64)
        XCTAssertLessThanOrEqual(TasteVectorMath.affinity(a, a)!, 1.0)
    }

    // MARK: - Ordering

    private func item(_ name: String, affinity: Double?, matched: Bool = true) -> MatchedWineListItem {
        let listItem = WineListItem(name: name)
        let wine = matched
            ? Wine(id: UUID(), name: name, producer: "P", vintage: nil,
                   variety: nil, region: nil, labelImageURL: nil, category: "Red")
            : nil
        return MatchedWineListItem(
            listItem: listItem, wine: wine, matchConfidence: matched ? 0.9 : nil,
            embedding: nil, affinity: affinity
        )
    }

    /// Reproduces the comparator in WineListScanService.rank so the ordering contract
    /// is pinned even though the service method needs a network round trip.
    private func sorted(_ items: [MatchedWineListItem]) -> [MatchedWineListItem] {
        items.sorted { lhs, rhs in
            switch (lhs.affinity, rhs.affinity) {
            case let (l?, r?): return l > r
            case (.some, .none): return true
            case (.none, .some): return false
            case (.none, .none): return false
            }
        }
    }

    func testHigherAffinityRanksFirst() {
        let result = sorted([item("low", affinity: 0.2), item("high", affinity: 0.9)])
        XCTAssertEqual(result.first?.displayName, "high")
    }

    func testUnmatchedLinesSinkBelowScoredOnes() {
        let result = sorted([
            item("unknown", affinity: nil, matched: false),
            item("scored", affinity: 0.1)
        ])
        XCTAssertEqual(result.first?.displayName, "scored")
        XCTAssertEqual(result.last?.displayName, "unknown")
    }

    /// Unmatched lines are kept, never dropped. The person is holding the list and
    /// can see the wines we failed to resolve.
    func testUnmatchedLinesAreRetained() {
        let input = [
            item("a", affinity: 0.5),
            item("b", affinity: nil, matched: false),
            item("c", affinity: nil, matched: false)
        ]
        XCTAssertEqual(sorted(input).count, 3)
        XCTAssertEqual(sorted(input).filter { !$0.isMatched }.count, 2)
    }

    func testUnmatchedLinesKeepTheirPrintedOrder() {
        let input = [
            item("first", affinity: nil, matched: false),
            item("second", affinity: nil, matched: false),
            item("third", affinity: nil, matched: false)
        ]
        XCTAssertEqual(sorted(input).map(\.displayName), ["first", "second", "third"])
    }

    // MARK: - Display fallbacks

    func testUnmatchedItemFallsBackToPrintedName() {
        let unmatched = item("Château Something", affinity: nil, matched: false)
        XCTAssertEqual(unmatched.displayName, "Château Something")
        XCTAssertFalse(unmatched.isMatched)
    }
}
