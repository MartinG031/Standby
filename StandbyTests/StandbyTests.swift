//
//  StandbyTests.swift
//  StandbyTests
//
//  Created by Martin Jay on 2025/12/3.
//

import Foundation
import Testing
@testable import Standby

struct StandbyTests {

    @Test func displayIsHiddenDuringDefaultNightHours() {
        let schedule = StandbySchedule(calendar: utcCalendar)

        #expect(schedule.shouldHideDisplay(at: date(hour: 0)))
        #expect(schedule.shouldHideDisplay(at: date(hour: 5, minute: 59)))
    }

    @Test func displayIsVisibleOutsideDefaultNightHours() {
        let schedule = StandbySchedule(calendar: utcCalendar)

        #expect(!schedule.shouldHideDisplay(at: date(hour: 6)))
        #expect(!schedule.shouldHideDisplay(at: date(hour: 23, minute: 59)))
    }

    @Test func customHiddenHoursAreSupported() {
        let schedule = StandbySchedule(hiddenHourRange: 22..<24, calendar: utcCalendar)

        #expect(schedule.shouldHideDisplay(at: date(hour: 22)))
        #expect(!schedule.shouldHideDisplay(at: date(hour: 21, minute: 59)))
    }

    @Test @MainActor func faceStyleIndexCyclesThroughAllClockFaces() {
        let lastIndex = StandbyFaceStyle.allCases.count - 1

        #expect(StandbyFaceStyle.index(after: 0) == 1)
        #expect(StandbyFaceStyle.index(after: lastIndex) == 0)
    }

    private var utcCalendar: Calendar {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(secondsFromGMT: 0)!
        return calendar
    }

    private func date(hour: Int, minute: Int = 0) -> Date {
        DateComponents(
            calendar: utcCalendar,
            timeZone: TimeZone(secondsFromGMT: 0),
            year: 2026,
            month: 5,
            day: 27,
            hour: hour,
            minute: minute
        ).date!
    }

}
