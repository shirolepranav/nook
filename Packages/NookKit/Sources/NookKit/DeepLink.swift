import Foundation

/// `nook://` links (D19, 04 §8): a box label's QR code (F8), and the widgets, controls,
/// Spotlight and intents (P12). In NookKit so the widget extension builds the same links.
public enum DeepLink: Equatable, Sendable {
    /// "nook://spot/<qrID>": a box label opens its container from the Camera app.
    case spot(String)
    case item(UUID)
    case room(UUID)
    /// "nook://find?q=…": Find, with the field filled in when there's a query.
    case find(String?)
    /// "nook://scan": room scan (C-02), from the Scan Room control and the Action button.
    case scan
    /// "nook://warranties": R-04, from the Warranties widget.
    case warranties

    public static let scheme = "nook"

    public init?(url: URL) {
        guard url.scheme == Self.scheme, let host = url.host() else { return nil }
        let id = url.pathComponents.dropFirst().first ?? ""
        switch host {
        case "spot" where !id.isEmpty: self = .spot(id)
        case "item": guard let uuid = UUID(uuidString: id) else { return nil }; self = .item(uuid)
        case "room": guard let uuid = UUID(uuidString: id) else { return nil }; self = .room(uuid)
        case "find":
            let query = URLComponents(url: url, resolvingAgainstBaseURL: false)?.queryItems?
                .first { $0.name == "q" }?.value
            self = .find(query?.isEmpty == false ? query : nil)
        case "scan": self = .scan
        case "warranties": self = .warranties
        default: return nil
        }
    }

    public var url: URL {
        var components = URLComponents()
        components.scheme = Self.scheme
        switch self {
        case .spot(let id): (components.host, components.path) = ("spot", "/\(id)")
        case .item(let id): (components.host, components.path) = ("item", "/\(id.uuidString)")
        case .room(let id): (components.host, components.path) = ("room", "/\(id.uuidString)")
        case .find(let query):
            components.host = "find"
            if let query { components.queryItems = [URLQueryItem(name: "q", value: query)] }
        case .scan: components.host = "scan"
        case .warranties: components.host = "warranties"
        }
        return components.url!
    }
}
