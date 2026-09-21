import Foundation

struct StandbyPalettePlayback {
    static let transitionDuration: TimeInterval = 24

    private(set) var source: StandbyBackgroundStyle
    private(set) var destination: StandbyBackgroundStyle
    private(set) var startedAt: TimeInterval
    private var remaining: [StandbyBackgroundStyle]

    init(startingWith style: StandbyBackgroundStyle, at elapsed: TimeInterval) {
        source = style
        startedAt = elapsed
        var queue = StandbyBackgroundStyle.allCases.filter { $0 != style }.shuffled()
        destination = queue.removeFirst()
        remaining = queue
    }

    mutating func advance(to elapsed: TimeInterval) {
        while elapsed >= startedAt + Self.transitionDuration {
            source = destination
            if remaining.isEmpty {
                remaining = StandbyBackgroundStyle.allCases.filter { $0 != source }.shuffled()
            }
            destination = remaining.removeFirst()
            startedAt += Self.transitionDuration
        }
    }

    func blend(at elapsed: TimeInterval) -> Double {
        let progress = min(1, max(0, (elapsed - startedAt) / Self.transitionDuration))
        // Zero velocity at each endpoint keeps consecutive color transitions continuous.
        return (1 - cos(progress * .pi)) / 2
    }
}
