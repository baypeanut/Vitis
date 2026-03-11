//
//  WantToTryChipTests.swift
//  PariTests
//
//  Sanity check: WantToTryChip compiles and can be instantiated.
//

import XCTest
@testable import Pari

final class WantToTryChipTests: XCTestCase {

    func testWantToTryChipInstantiation() {
        let chip = WantToTryChip(count: 12) { }
        XCTAssertNotNil(chip)
    }

    func testWantToTryChipZeroCount() {
        let chip = WantToTryChip(count: 0) { }
        XCTAssertNotNil(chip)
    }
}
