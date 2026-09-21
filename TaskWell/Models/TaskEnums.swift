import Foundation
import SwiftData

/// Effort estimate for a task. Stored as raw Int for CloudKit-friendly sync later.
enum EffortLevel: Int, Codable, CaseIterable, Identifiable, Sendable {
    case quick = 0
    case medium = 1
    case big = 2

    var id: Int { rawValue }

    var title: String {
        switch self {
        case .quick: "Quick"
        case .medium: "Medium"
        case .big: "Big"
        }
    }

    var symbolName: String {
        switch self {
        case .quick: "bolt.fill"
        case .medium: "leaf.fill"
        case .big: "mountain.2.fill"
        }
    }
}

/// How enjoyable the task feels. Stored as raw Int for sync-friendly shapes.
enum EnjoymentLevel: Int, Codable, CaseIterable, Identifiable, Sendable {
    case dread = 0
    case meh = 1
    case enjoy = 2

    var id: Int { rawValue }

    var title: String {
        switch self {
        case .dread: "Dread"
        case .meh: "Meh"
        case .enjoy: "Enjoy"
        }
    }

    var symbolName: String {
        switch self {
        case .dread: "cloud.rain.fill"
        case .meh: "cloud.fill"
        case .enjoy: "sun.max.fill"
        }
    }
}
