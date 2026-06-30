import XCTest
@testable import Tachi

final class CodexRateLimitTests: XCTestCase {
    func testParsesOfficialAppServerRateLimitSnapshot() {
        let payload: [String: Any] = [
            "result": [
                "rateLimits": [
                    "limitId": "codex",
                    "planType": "pro",
                    "primary": [
                        "usedPercent": 15,
                        "windowDurationMins": 300,
                        "resetsAt": 1_782_627_980,
                    ],
                    "secondary": [
                        "usedPercent": 59,
                        "windowDurationMins": 10_080,
                        "resetsAt": 1_782_800_300,
                    ],
                ],
                "rateLimitsByLimitId": [
                    "codex": [
                        "limitId": "codex",
                        "planType": "pro",
                        "primary": [
                            "usedPercent": 15,
                            "windowDurationMins": 300,
                            "resetsAt": 1_782_627_980,
                        ],
                        "secondary": [
                            "usedPercent": 59,
                            "windowDurationMins": 10_080,
                            "resetsAt": 1_782_800_300,
                        ],
                    ],
                ],
                "rateLimitResetCredits": [
                    "availableCount": 4,
                ],
            ],
        ]

        let snapshot = CodexRateLimitSnapshot.fromAppServerResponse(payload)

        XCTAssertEqual(snapshot?.limitId, "codex")
        XCTAssertEqual(snapshot?.resetCreditCount, 4)
        XCTAssertEqual(snapshot?.validityLabel, "5h / 1w")
        XCTAssertEqual(snapshot?.windows.map(\.validityLabel), ["5h", "1w"])
        XCTAssertEqual(snapshot?.windows.map(\.usedPercent), [15, 59])
        XCTAssertEqual(snapshot?.windows.map(\.remainingPercent), [85, 41])
        XCTAssertEqual(snapshot?.windows.map { Int($0.resetsAt.timeIntervalSince1970) }, [1_782_627_980, 1_782_800_300])
    }

    func testParsesResetCreditValidDates() throws {
        let data = """
        {
          "available_count": 2,
          "credits": [
            {
              "id": "credit-1",
              "status": "available",
              "expires_at": "2026-07-11T21:13:00Z"
            },
            {
              "id": "credit-2",
              "status": "redeemed",
              "expires_at": "2026-07-12T21:13:00Z"
            },
            {
              "id": "credit-3",
              "status": "available",
              "expires_at": "2026-07-10T21:13:00Z"
            }
          ]
        }
        """.data(using: .utf8)!

        let response = try XCTUnwrap(CodexResetCreditsResponse.fromJSONData(data))

        XCTAssertEqual(response.availableCount, 2)
        XCTAssertEqual(response.availableCredits.count, 2)
        XCTAssertEqual(
            response.availableCredits.map { Int($0.expiresAt?.timeIntervalSince1970 ?? 0) },
            [1_783_717_980, 1_783_804_380]
        )
    }

    func testMergesResetCreditValidDatesIntoSnapshot() throws {
        let snapshot = CodexRateLimitSnapshot(
            limitId: "codex",
            limitName: nil,
            windows: [],
            resetCreditCount: 4
        )
        let credits = try XCTUnwrap(CodexResetCreditsResponse.fromJSONObject([
            "available_count": 1,
            "credits": [
                [
                    "status": "available",
                    "expires_at": "2026-07-11T21:13:00Z",
                ],
            ],
        ]))

        let merged = snapshot.withResetCredits(credits)

        XCTAssertEqual(merged.resetCreditCount, 1)
        XCTAssertEqual(merged.availableResetCredits.count, 1)
        XCTAssertEqual(Int(merged.availableResetCredits[0].expiresAt?.timeIntervalSince1970 ?? 0), 1_783_804_380)
    }
}
