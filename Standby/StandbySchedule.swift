// StandbySchedule.swift
// Defines deterministic display schedule rules for the standby clock.

import Foundation

struct StandbySchedule {
    var hiddenHourRange: Range<Int> = 0..<6
    var calendar: Calendar = .current

    nonisolated func shouldHideDisplay(at date: Date) -> Bool {
        let hour = calendar.component(.hour, from: date)
        return hiddenHourRange.contains(hour)
    }
}
