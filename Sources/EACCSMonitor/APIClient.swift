import Foundation

// MARK: - Config

enum Config {
    static let apiBase = "http://seasonsolt.myds.me:8888/api/v1/admin"
    static let bearerToken = "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJ1c2VyX2lkIjoxLCJlbWFpbCI6InRoaW5Ac3ViMmFwaS5sb2NhbCIsInJvbGUiOiJhZG1pbiIsInRva2VuX3ZlcnNpb24iOjAsImV4cCI6MTc3MzgyNzM4MSwibmJmIjoxNzczNzQwOTgxLCJpYXQiOjE3NzM3NDA5ODF9.b2psDZ5oFFeHCKd5NfKK-4MhTgTWddDS2fLxrQZHFWs"
    static let sessionToken = "eyJhbGciOiJkaXIiLCJlbmMiOiJBMjU2R0NNIn0..qX2Y4huODLB3r3c-.Gp58Zrz4UrLyyAQbLjF7VH-4HqjJQh26ECbs5wSfPt-Z_lX4rYitNdATXeApQ0WZ-rqUJoILH1zUiyMhSYV8cS5rB1xLwcVlWwsP_d4DP2vvMlyPNjmrN2SPdgcq_mLKtbzdi3TBV4NX3z4aQlIV28PAZCxyGwrEOpidZwP0WJeA60FNrimKzwh1z2Zyxb9nLcsprhO9uCkiLRt39F6uD1IQFyTgHAAeYjgWbmu-OFzEjg8jdLgAflTntbVS4BbsitHMyTnRnMNQUrJZRdPSz1ts_72Oj9de7sVl9cgs4FzyEJsKqd-sGP6Kkgst9eeGW0fRI_IqTWaloRdinNw0bJKoDa8ugH-FfbinOr0KHiGBR1zkTdcYRsS_3DZbsSGzVz3_aTckgVzvNtQmXx_nf6Jhz14Rix1T_-PAYoOZvmrKOyKLV5Dz1sPUcAzgsvZbNRJ1HU1cm8vD-8LhNNOMlz4Xhf5w-xefbHycoxRmXLJT0-gH2K2UuNWsL5uZNfYj1LGzjffqro0m2L6Pt6HMgOLucxfa-3JJIKm8FRVbxao3bAob5l7fMZSpLrqcph9CGiEpG6y2SVV9Kev7ZHZcJ8DWiz5TZ6zxTww6LE25ZU3Jr_y3u2fTdhrZPzePxbOqUFbREbXop9RljMtirW-k9VzJcZ1e9-1AhAVSaMuvATp0AP_ywoGo6G83MBQv0BQMBUy2OmRnjhxauLiWUV318X8XulmOoeqEZKjqqLFEFyDquE4PMptOguB94D_oiUwoQTnDu-KiAlCY5WwE8pphmak23NpGQC5bpTm4Tx_iiKi3r91lipVC0spmGsdmxKzDNXH9Pbh2mwmgggiC8xNE7AgmirHSjnjbHp4zFMscVRbiJWjckIUOBFQO3HZcap1wmyouypNsVcMOYwpy2QCaRIp2rSXGID5zTt3yA_0lOJq803oNKjk0fY89MPHzrx73Hn0gHYYaKRK1lAwmV0SYM5n0o6Rrcfp9CL_4iz3t-HmFCWOYrub9B2rtDprgpum-y9-qzJeyTOPR226xYc6tllr8PwgZDUIBBgKNrjPBNPzZormC7cfn_CXonFQrVNqud-qpQDr3yntpIu2pNbdcZtcVGDfR8f12_HESsflAwrc2PmlWiHNpblt93LQbsC6-K6BU_V5QyC0l6wmhNiq2OtpZ-VFe8OE2ZPgoDMU3IYBeYIyZoZnFUCwLcR_-OyOPs2E-WlRFdkaRP6FQVXxmE9TdoY6MpQ7BGfA7l4QHWV3275lJY2ksPKFzP2zTHuJ6f6uqTT2eDTUp7IKEH5VpXZ0M30SxU2cniEqiDeAAjQ-pC27QL4PX4OizRs4dGDQuOlqsfbKJTDbXIdtqToseFf7pzeftdnN-l_jLrn_5Zub9DDBYL3DPj19iTqKFk9jmx9wb1IAa7nVSb9EE0pcfn4kVeB5wv9kBR6Uy_S4zbAC8Z6dLyWJqrd0s4SNnnT-v8tS7bpwBrtUjqNjryHB8zYSrw56nPJCbD7XLISuKtS-VBEbfi4-yoKU79gwCws49GNgkqY966wAXA4PDNQSIghLU5MSviKuiW7YsjNqTAx6YlvYd4X8lPqkECvzegdxClX7Cb6-U9cYry8NFdiYgqsjlY_gQRcA3_tTIhV2cBQDWx57XeYFTO54Zi-kaDb9x06aGtJCyqGpvAwxGCz2xxCnrEzdryV0toOFqkAKETuAFl5xTMgslJTRMP27DICigSF7pAcD9hCoqAiehPnu2T0xXfaJE4BngNZO92E2w1osX6zN5tZkaA5zNN7fRq40qV6dOQQNbnCTh2dnQNeFvz8q4xMDjWn-G9Cxi1msDC4wjd3uPmpButmyFsTswvpRQYyNuAjhft7GmUxjJGkabZoyKO_G7ywDYRhCLKy6lhq5tYiU4TOCDHaFNs6616JZ3zCb5Zulfktkv0G3wFK9TLcoZiyfP_7qhj9Sjrx2kx5YbLpY5SakECZZsMgdGRLmlIdNx_AqKreGsKottdsfYADdG14vQ8F5jGzyTTobFW-jMLp0jigrCuu4dS6G7Y6fsveu9C6D7Rh9Q6UbTR8EBubnvFRRB39_lNmnOknUxHGkjcJvODg0fSoiaseXHJIuv3kKQT-A0obrnDWGo2QLX7pwFIXYC9A8keCntYXoC-k3cLc8mYOOpwW_dEu_jO8uKxmYSRNYt2zHxNFIXtDWFlHX8zxjdhXsngN5ia4b7jUnyZwqsQc0ehoCG_4i6MWYJJ40uq0e2ZG5b8NrwLfElAVT_-vjel_k9a4DTCfXIJhEhjX14gArZ2Zxdx9TWkUH87TvOtxKa4KFTUex_VGI_E2Uh82qcpEPoIx6LUHZlsPiRdlriCktGgM5_aeeyjEPXOYSY7awECGqLyoY_Xvh_hjxfMy3OumR9bnGrz6TuBdUJa5j4KGuhB4BymD32BcOhj2FRxo13Pn53_TkBdlPax0nXcZePITgh8InLfPLndyK5MPJV-GK7_qiBAa20abFZMN2TTvkMMZDj2xmynnr4SnpTfyWFG45NOmMYr-Xw3gddz9zQFjf7BoO-99CPWbDkDhAif8NKpJWriZ2EPZOH6Axap5xDtN8zz9_hdOORTUxUV7UXgEpKnwq6yHW50pjFGRCDbViDiaRSZOccki3AY5kGHxttGCZq3MNEU6ezq_Ct-qSe1yBDi1LeUa9dfZISspcg0nr-eRPQ_SNZnbkxfAKehhaL4q3g0oq-YduhiK9_Mha57zSGGbqmdUN5vJOKs1LXM5-QEa8VnQR4xRD1LtuZmNLl9xIAfwcsmvApJtKokV1o3pWIclNcqMRSUJg9PDzKmHEsbeYEI-DrpHgrT1prxn3VIAb5zPPgAn6fgR1q0bsZ5M-mmPD2YGHTzM6LehvVZw2OfkB90BQk9hQhJ1f5wKFm0NliiPqhBumIF6X-6ocgpyDIp00loUYyisyKfCGnkDkXpPXkDl2UL0Sa3XJJEXgsY0YZ5zlgqC_MTELYKMAgkBqwMpcCeI4ZMMXld3z5Hpx4hlSHadqZLlUHTcSWcix6Hy17NPj2SbbjDhz0gchoQzKmyUhr_DS0u_wBEBj3gb8i5fYtY7dFsMfvLupPhWAju6CYqX5CCXLlmOtAS431xZf2T2ZRMJF9bBN0VS9mt_xC0YZGxEAFU9I0rGx8SMINOLHGyV9aNzWOvyvidr1vu62xsgac9aKS_I_MyX4MJoexCPtCw34WZaD2-sihpLxaH8ZNiDJpukJOkn2bTt8fvbEnI2Mc8oermaMQIGczI44VFH2xeOtQSY26fAvhkwyAVIZCN6ieKbhti2OSGfnIDQbVc7ztT7CRxMs4PdUsnKYa9y5S8D7YBB8VEmIjxuYDU6WF_Q9OnQ9vFeRYKktdx1j5M5llGp_N6u_PQV8QUs79mXBrjRObLrWMfi83G_dEuLVJ99GHieDkcE0kdotm31rrJ453vx86QmV3jV4UR270Kq7ixWva0iWK-lXBRoxkM-2G-nG0uOAPlqJUtbxkKBpMYiC9FDMyc0o-TxFQSssg_mltC5gZ_Wza81yAlswmOTuROMVmjAIx_TkCFonAd7LAaF4qu-BMX7upjTZFkCl2.jZdPwKVriHH545zNJafacw"
    static let authSession = "Mjg3NjVhMDMtMmRhNi00MDdjLWIzMDMtMjQzZmEwMTkwZGFj"
    static let refreshInterval: TimeInterval = 30
}

// MARK: - Models

struct Account: Identifiable {
    let id: Int
    let name: String
    let platform: String
    let type: String

    var icon: String {
        switch platform {
        case "openai": return "cube.transparent"
        case "anthropic": return "brain.head.profile"
        case "antigravity": return "arrow.up.right.circle"
        default: return "server.rack"
        }
    }

    var platformColor: String {
        switch platform {
        case "openai": return "openai"
        case "anthropic": return "anthropic"
        case "antigravity": return "antigravity"
        default: return "gray"
        }
    }
}

struct WindowUsage {
    let utilization: Int
    let remainingSeconds: Int
    let requests: Int
    let tokens: Int
}

struct ModelQuota: Identifiable {
    let id: String
    let displayName: String
    let utilization: Int
    let resetTime: String
}

enum UsageData {
    case openai(fiveHour: WindowUsage, sevenDay: WindowUsage)
    case antigravity(fiveHour: WindowUsage, models: [ModelQuota], tier: String, credits: Int)
}

struct AccountWithUsage: Identifiable {
    let id: Int
    let account: Account
    let usage: UsageData?

    var maxUtilization: Int {
        guard let usage else { return 0 }
        switch usage {
        case .openai(let fh, let sd):
            return max(fh.utilization, sd.utilization)
        case .antigravity(let fh, let models, _, _):
            let modelMax = models.map(\.utilization).max() ?? 0
            return max(fh.utilization, modelMax)
        }
    }

    /// Activity weight: requests for OpenAI, active model count for Antigravity
    var activityWeight: Double {
        guard let usage else { return 0 }
        switch usage {
        case .openai(let fh, _):
            // Use 5h tokens as primary weight, fallback to requests, minimum 1
            if fh.tokens > 0 { return Double(fh.tokens) }
            return max(1, Double(fh.requests))
        case .antigravity(_, let models, _, _):
            let active = models.filter { $0.utilization > 0 }.count
            return max(1, Double(active))
        }
    }
}

enum TestState: Equatable {
    case idle
    case testing
    case success(model: String, text: String)
    case failure(error: String)
}

// MARK: - API Client

final class APIClient: NSObject, URLSessionDelegate {
    static let shared = APIClient()
    private lazy var session: URLSession = {
        URLSession(configuration: .default, delegate: self, delegateQueue: nil)
    }()

    func urlSession(_ session: URLSession, didReceive challenge: URLAuthenticationChallenge) async
        -> (URLSession.AuthChallengeDisposition, URLCredential?)
    {
        if let trust = challenge.protectionSpace.serverTrust {
            return (.useCredential, URLCredential(trust: trust))
        }
        return (.performDefaultHandling, nil)
    }

    private func makeRequest(path: String) -> URLRequest {
        var req = URLRequest(url: URL(string: Config.apiBase + path)!)
        req.setValue("application/json", forHTTPHeaderField: "Accept")
        req.setValue("Bearer \(Config.bearerToken)", forHTTPHeaderField: "Authorization")
        req.setValue("no-cache", forHTTPHeaderField: "Cache-Control")
        req.setValue(
            "next-auth.session-token=\(Config.sessionToken); AUTH_SESSION=\(Config.authSession)",
            forHTTPHeaderField: "Cookie")
        req.timeoutInterval = 15
        return req
    }

    private func fetchJSON(path: String) async -> [String: Any]? {
        let req = makeRequest(path: path)
        guard let (data, _) = try? await session.data(for: req),
            let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
            json["code"] as? Int == 0,
            let inner = json["data"] as? [String: Any]
        else { return nil }
        return inner
    }

    func fetchAccounts() async -> [Account] {
        guard let data = await fetchJSON(path: "/accounts"),
            let items = data["items"] as? [[String: Any]]
        else { return [] }

        return items.compactMap { item in
            guard let id = item["id"] as? Int, let name = item["name"] as? String else {
                return nil
            }
            return Account(
                id: id, name: name,
                platform: item["platform"] as? String ?? "",
                type: item["type"] as? String ?? "")
        }
    }

    func fetchUsage(accountId: Int) async -> UsageData? {
        guard let data = await fetchJSON(path: "/accounts/\(accountId)/usage?timezone=Asia%2FShanghai")
        else { return nil }

        if let quota = data["antigravity_quota"] as? [String: [String: Any]] {
            return parseAntigravity(data: data, quota: quota)
        }
        return parseOpenAI(data: data)
    }

    private func parseOpenAI(data: [String: Any]) -> UsageData {
        let fh = parseWindow(data["five_hour"] as? [String: Any] ?? [:])
        let sd = parseWindow(data["seven_day"] as? [String: Any] ?? [:])
        return .openai(fiveHour: fh, sevenDay: sd)
    }

    private func parseAntigravity(data: [String: Any], quota: [String: [String: Any]]) -> UsageData
    {
        let fh = parseWindow(data["five_hour"] as? [String: Any] ?? [:])
        let details = data["antigravity_quota_details"] as? [String: [String: Any]] ?? [:]
        let credits = (data["ai_credits"] as? [[String: Any]])?.first?["amount"] as? Int ?? 0
        let tier = data["subscription_tier"] as? String ?? ""

        var models: [ModelQuota] = []
        for (name, info) in quota {
            let display = details[name]?["display_name"] as? String ?? name
            models.append(
                ModelQuota(
                    id: name,
                    displayName: display,
                    utilization: info["utilization"] as? Int ?? 0,
                    resetTime: info["reset_time"] as? String ?? ""
                ))
        }
        models.sort { $0.utilization > $1.utilization }

        return .antigravity(fiveHour: fh, models: models, tier: tier, credits: credits)
    }

    private func parseWindow(_ dict: [String: Any]) -> WindowUsage {
        let stats = dict["window_stats"] as? [String: Any]
        return WindowUsage(
            utilization: dict["utilization"] as? Int ?? 0,
            remainingSeconds: dict["remaining_seconds"] as? Int ?? 0,
            requests: stats?["requests"] as? Int ?? 0,
            tokens: stats?["tokens"] as? Int ?? 0
        )
    }

    func testAccount(id: Int) async -> TestState {
        var req = makeRequest(path: "/accounts/\(id)/test")
        req.httpMethod = "POST"
        req.setValue("application/json", forHTTPHeaderField: "Content-Type")
        req.httpBody = try? JSONSerialization.data(
            withJSONObject: ["model_id": "", "prompt": ""])
        req.timeoutInterval = 30

        guard let (bytes, _) = try? await session.bytes(for: req) else {
            return .failure(error: "Connection failed")
        }

        var model = ""
        var textParts: [String] = []
        var success = false

        do {
            for try await line in bytes.lines {
                guard line.hasPrefix("data: "),
                    let eventData = line.dropFirst(6).data(using: .utf8),
                    let event = try? JSONSerialization.jsonObject(with: eventData) as? [String: Any],
                    let type = event["type"] as? String
                else { continue }

                switch type {
                case "test_start":
                    model = event["model"] as? String ?? ""
                case "content":
                    textParts.append(event["text"] as? String ?? "")
                case "test_complete":
                    success = event["success"] as? Bool ?? false
                default:
                    break
                }
            }
        } catch {
            if !success && textParts.isEmpty {
                return .failure(error: error.localizedDescription)
            }
        }

        if success {
            return .success(model: model, text: textParts.joined())
        }
        return .failure(error: textParts.joined().isEmpty ? "No response" : textParts.joined())
    }
}

// MARK: - Helpers

func utilizationColor(_ value: Int) -> (r: Double, g: Double, b: Double) {
    if value <= 30 { return (0.2, 0.78, 0.35) }
    if value <= 70 { return (1.0, 0.58, 0.0) }
    return (1.0, 0.23, 0.19)
}

func formatRemaining(_ seconds: Int) -> String {
    if seconds <= 0 { return "now" }
    let d = seconds / 86400
    let h = (seconds % 86400) / 3600
    let m = (seconds % 3600) / 60
    if d > 0 { return "\(d)d \(h)h" }
    if h > 0 { return "\(h)h \(m)m" }
    return "\(m)m"
}

func formatResetTime(_ iso: String) -> String {
    guard !iso.isEmpty else { return "" }
    let formatter = ISO8601DateFormatter()
    formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
    var date = formatter.date(from: iso)
    if date == nil {
        formatter.formatOptions = [.withInternetDateTime]
        date = formatter.date(from: iso)
    }
    if date == nil {
        let df = DateFormatter()
        df.dateFormat = "yyyy-MM-dd'T'HH:mm:ssZZZZZ"
        date = df.date(from: iso)
    }
    guard let d = date else { return "" }
    let delta = Int(d.timeIntervalSinceNow)
    if delta <= 0 { return "resetting..." }
    return formatRemaining(delta)
}

func formatTokens(_ n: Int) -> String {
    if n >= 1_000_000 { return String(format: "%.1fM", Double(n) / 1_000_000) }
    if n >= 1_000 { return String(format: "%.0fK", Double(n) / 1_000) }
    return "\(n)"
}
