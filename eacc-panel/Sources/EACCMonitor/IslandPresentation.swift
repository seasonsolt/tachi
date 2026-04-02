import Foundation

struct IslandSnapshot: Equatable {
    let dominantSessionID: String?
    let signal: SessionSignal?
    let pulse: SessionPulse?
    let hasActiveSession: Bool
}

enum IslandVisibleMode: Equatable {
    case idleLine
    case eventExpanded
    case detailPopover
}

enum IslandPresentation {
    static func shouldAutoExpand(from old: IslandSnapshot?, to new: IslandSnapshot) -> Bool {
        guard new.hasActiveSession else { return false }
        guard let old else { return new.dominantSessionID != nil }

        if old.dominantSessionID != new.dominantSessionID {
            return true
        }

        if old.signal != new.signal {
            return true
        }

        if old.pulse != new.pulse {
            return true
        }

        return false
    }

    static func resolveVisibleMode(
        hasActiveSession: Bool,
        isDetailPresented: Bool,
        isTransientlyExpanded: Bool
    ) -> IslandVisibleMode {
        if isDetailPresented {
            return .detailPopover
        }

        if isTransientlyExpanded {
            return .eventExpanded
        }

        return .idleLine
    }
}
