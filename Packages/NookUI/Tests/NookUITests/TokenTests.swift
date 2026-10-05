import SwiftUI
import Testing
@testable import NookUI

@Test func spacingStaysOnTheEightPointGrid() {
    // D6: 8-pt grid, with a 4-pt half step only.
    let steps = [NookSpace.s1, NookSpace.s2, NookSpace.s3, NookSpace.s4, NookSpace.s5, NookSpace.s6]
    #expect(steps.allSatisfy { $0.truncatingRemainder(dividingBy: 8) == 0 })
    #expect(NookSpace.half == 4)
}

@Test func gridNeverPassesSixColumns() {
    // D29: 6 cards of 160 pt plus 5 gaps of 16 pt.
    #expect(NookLayout.maxGridWidth == 1040)
}

@Test func reduceMotionSwapsOrStopsAnimations() {
    #expect(NookMotion.shimmer.animation(reduceMotion: true) == nil)
    #expect(NookMotion.shimmer.animation(reduceMotion: false) != nil)
    #expect(NookMotion.settle.animation(reduceMotion: true) != NookMotion.settle.animation(reduceMotion: false))
    #expect(NookMotion.stagger(reduceMotion: true) == .zero)
    #expect(NookMotion.stagger(reduceMotion: false) == .milliseconds(180))
}

@Test func hapticTokensMapToSystemFeedback() {
    #expect(NookHaptic.saved.feedback == .success)
    #expect(NookHaptic.selected.feedback == .selection)
    #expect(NookHaptic.failed.feedback == .error)
}
