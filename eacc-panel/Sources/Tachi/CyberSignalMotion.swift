import Foundation

enum CyberSignalMotion {
    static let revolutionDuration: TimeInterval = 10

    static func rotationDegrees(
        at date: Date,
        startDate: Date,
        hasMotion: Bool,
        revolutionDuration: TimeInterval = CyberSignalMotion.revolutionDuration
    ) -> Double {
        guard hasMotion, revolutionDuration > 0 else { return 0 }

        let elapsed = max(0, date.timeIntervalSince(startDate))
        return -((elapsed / revolutionDuration) * 360)
    }
}
