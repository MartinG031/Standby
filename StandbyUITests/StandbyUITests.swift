//
//  StandbyUITests.swift
//  StandbyUITests
//
//  Created by Martin Jay on 2025/12/3.
//

import XCTest

final class StandbyUITests: XCTestCase {

    override func setUpWithError() throws {
        continueAfterFailure = false
    }

    @MainActor
    func testLaunchShowsClock() throws {
        let app = XCUIApplication()
        app.launchEnvironment["STANDBY_DISABLE_NIGHT_HIDE"] = "1"
        app.launch()

        XCTAssertTrue(app.staticTexts["standbyClockTime"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.staticTexts["standbyClockDate"].exists)
    }

    @MainActor
    func testLaunchPerformance() throws {
        measure(metrics: [XCTApplicationLaunchMetric()]) {
            let app = XCUIApplication()
            app.launchEnvironment["STANDBY_DISABLE_NIGHT_HIDE"] = "1"
            app.launch()
        }
    }
}
