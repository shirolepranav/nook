import Foundation
import Testing
@testable import NookKit

/// 04 §8, D19: every link survives a round trip, and junk is refused.
@Test(arguments: [DeepLink.spot("lived-box-14"), .item(UUID()), .room(UUID()), .find(nil), .find("car keys & fob"),
                  .scan, .warranties])
func deepLinkRoundTrips(_ link: DeepLink) {
    #expect(DeepLink(url: link.url) == link)
}

@Test func deepLinkReadsTheDocumentedForms() {
    #expect(DeepLink(url: URL(string: "nook://spot/abc")!) == .spot("abc"))
    #expect(DeepLink(url: URL(string: "nook://find?q=passport")!) == .find("passport"))
    #expect(DeepLink(url: URL(string: "nook://find")!) == .find(nil))
    #expect(DeepLink(url: URL(string: "nook://scan")!) == .scan)
}

@Test func deepLinkRefusesOtherLinks() {
    #expect(DeepLink(url: URL(string: "https://example.com/spot/abc")!) == nil)
    #expect(DeepLink(url: URL(string: "nook://item/not-a-uuid")!) == nil)
    #expect(DeepLink(url: URL(string: "nook://spot/")!) == nil)
    #expect(DeepLink(url: URL(string: "nook://unknown")!) == nil)
}
