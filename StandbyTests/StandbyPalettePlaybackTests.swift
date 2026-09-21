import Foundation
import Testing
@testable import Standby

@MainActor
struct StandbyPalettePlaybackTests {
    @Test func visitsEveryPaletteBeforeRepeating() {
        for style in StandbyBackgroundStyle.allCases {
            var playback = StandbyPalettePlayback(startingWith: style, at: 0)
            var visited = [playback.source]
            for step in 1..<StandbyBackgroundStyle.allCases.count {
                playback.advance(to: Double(step) * StandbyPalettePlayback.transitionDuration)
                visited.append(playback.source)
            }
            #expect(Set(visited) == Set(StandbyBackgroundStyle.allCases))
        }
    }

    @Test func boundariesPreserveThePreviousDestination() {
        var playback = StandbyPalettePlayback(startingWith: .seaMist, at: 0)
        for step in 1...100 {
            let endpoint = playback.destination
            let boundary = Double(step) * StandbyPalettePlayback.transitionDuration
            #expect(playback.blend(at: boundary) == 1)
            playback.advance(to: boundary)
            #expect(playback.source == endpoint)
            #expect(playback.destination != playback.source)
            #expect(playback.blend(at: boundary) == 0)
        }
    }

    @Test func blendIsSmoothAndClamped() {
        let playback = StandbyPalettePlayback(startingWith: .dawn, at: 10)
        #expect(playback.blend(at: 0) == 0)
        #expect(abs(playback.blend(at: 22) - 0.5) < 0.000001)
        #expect(playback.blend(at: 100) == 1)
        #expect(playback.blend(at: 10.01) < 0.00001)
        #expect(playback.blend(at: 33.99) > 0.99999)
    }

    @Test func advancingToTheSameElapsedTimeDoesNotChangePlayback() {
        var playback = StandbyPalettePlayback(startingWith: .ocean, at: 0)
        playback.advance(to: 85)
        let source = playback.source
        let destination = playback.destination
        let blend = playback.blend(at: 85)
        playback.advance(to: 85)
        #expect(playback.source == source)
        #expect(playback.destination == destination)
        #expect(playback.blend(at: 85) == blend)
        #expect(playback.startedAt == 72)
    }
}
