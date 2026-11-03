import ActivityKit
import Foundation

/// Live Activity for what is playing (recitation or radio): Lock Screen and Dynamic Island.
/// Shared by the app (starts, updates, ends it from AudioCenter) and the widget (draws it).
struct ListeningAttributes: ActivityAttributes {
    struct ContentState: Codable, Hashable {
        var title: String
        var subtitle: String
        var isPlaying: Bool
        var isLive: Bool
    }
}
