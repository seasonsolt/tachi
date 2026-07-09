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

    /// Angular speed of the ring in degrees/second (negative = counter-clockwise).
    /// `tempo` scales the base speed so more concurrent working sessions spin
    /// the ring faster.
    static func degreesPerSecond(
        hasMotion: Bool,
        tempo: Double,
        revolutionDuration: TimeInterval = CyberSignalMotion.revolutionDuration
    ) -> Double {
        guard hasMotion, revolutionDuration > 0 else { return 0 }
        return -360.0 * tempo / revolutionDuration
    }
}
