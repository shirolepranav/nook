import Foundation

/// `nook://` links (D19). P10 has one: a box label's QR code opens its container from the
/// Camera app (F8). P12's widgets and intents add item, room, find and scan.
enum DeepLink: Equatable {
    case spot(String)

    static let scheme = "nook"

    init?(url: URL) {
        guard url.scheme == Self.scheme, url.host() == "spot", let id = url.pathComponents.dropFirst().first,
              !id.isEmpty else { return nil }
        self = .spot(id)
    }

    /// "nook://spot/<qrID>".
    var url: URL {
        switch self {
        case .spot(let id): URL(string: "\(Self.scheme)://spot/\(id)")!
        }
    }
}
