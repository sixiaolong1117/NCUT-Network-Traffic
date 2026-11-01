import Foundation

// ponytail: 用 JSONSerialization 而不是 Codable，SRun 各版本字段时而 Int 时而 String，Any 兜底最少代码。
struct TrafficInfo {
    let remainBytes: Int64
    let usedBytes: Int64
    let userName: String
    let productName: String
    let onlineIP: String
    let deviceCount: Int
    let fetchedAt: Date
}

enum SRunError: LocalizedError {
    case notOnline(String)
    case badResponse(String)
    case network(Error)

    var errorDescription: String? {
        switch self {
        case .notOnline(let msg): return msg.isEmpty ? "未登录校园网" : msg
        case .badResponse(let msg): return "解析失败：\(msg)"
        case .network(let e): return e.localizedDescription
        }
    }
}

enum SRunClient {
    static let host = "http://10.0.31.130"

    static func fetch() async throws -> TrafficInfo {
        // callback 名任意，_ 防缓存
        let ms = Int(Date().timeIntervalSince1970 * 1000)
        guard let url = URL(string: "\(host)/cgi-bin/rad_user_info?callback=jsonp&_=\(ms)") else {
            throw SRunError.badResponse("URL 非法")
        }
        var req = URLRequest(url: url, timeoutInterval: 8)
        req.setValue("Mozilla/5.0 (Macintosh; Intel Mac OS X) NCUT-Traffic/1.0", forHTTPHeaderField: "User-Agent")
        req.cachePolicy = .reloadIgnoringLocalCacheData

        let data: Data
        do {
            (data, _) = try await URLSession.shared.data(for: req)
        } catch {
            throw SRunError.network(error)
        }
        guard let text = String(data: data, encoding: .utf8) else {
            throw SRunError.badResponse("非 UTF-8")
        }
        // jsonp({...}) -> {...}
        guard let l = text.firstIndex(of: "("), let r = text.lastIndex(of: ")"), l < r else {
            throw SRunError.badResponse(text.prefix(80).description)
        }
        let jsonStr = String(text[text.index(after: l)..<r])
        guard let jsonData = jsonStr.data(using: .utf8),
              let obj = try? JSONSerialization.jsonObject(with: jsonData) as? [String: Any] else {
            throw SRunError.badResponse(jsonStr.prefix(80).description)
        }

        let err = (obj["error"] as? String) ?? ""
        guard err == "ok" else {
            throw SRunError.notOnline(err)
        }

        func i64(_ key: String) -> Int64 {
            if let v = obj[key] as? Int64 { return v }
            if let v = obj[key] as? Int { return Int64(v) }
            if let v = obj[key] as? Double { return Int64(v) }
            if let v = obj[key] as? String, let p = Int64(v) { return p }
            if let v = obj[key] as? NSNumber { return v.int64Value }
            return 0
        }
        func str(_ key: String) -> String {
            if let v = obj[key] as? String { return v }
            if let v = obj[key] as? NSNumber { return v.stringValue }
            return ""
        }
        func int(_ key: String) -> Int {
            let v = i64(key)
            return v > 0 ? Int(v) : 0
        }

        let product = str("products_name").isEmpty ? str("billing_name") : str("products_name")
        return TrafficInfo(
            remainBytes: i64("remain_bytes"),
            usedBytes: i64("sum_bytes"),
            userName: str("user_name"),
            productName: product,
            onlineIP: str("online_ip"),
            deviceCount: int("online_device_total"),
            fetchedAt: Date()
        )
    }
}

/// 1024 基，菜单栏 1 位小数，下拉 2 位小数。校园网习惯叫 GB，实际按 GiB 算。
enum ByteFormat {
    static func menu(_ bytes: Int64) -> String {
        String(format: "%.1fG", Double(bytes) / 1024 / 1024 / 1024)
    }
    static func detail(_ bytes: Int64) -> String {
        let g = Double(bytes) / 1024 / 1024 / 1024
        if g >= 1 { return String(format: "%.2f GB", g) }
        let m = Double(bytes) / 1024 / 1024
        return String(format: "%.1f MB", m)
    }
    static func masked(_ name: String) -> String {
        guard name.count > 8 else { return name }
        return String(name.prefix(4)) + "***" + String(name.suffix(4))
    }
}
