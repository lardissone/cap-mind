import Foundation

struct ObjectRef: Decodable, Equatable {
    let id: String
    let title: String?
    let url: String?
    let created: String?
    let modified: String?
    let bumped: String?
}

struct ProblemJSON: Decodable, Equatable {
    let type: String
    let status: Int
    let detail: String?
}

enum RateLimitHeader {
    /// Parses a `RateLimit` header value, returns the max `t` among policies with `r=0`, else nil.
    static func maxResetForExhausted(_ value: String) -> Int? {
        var maxT: Int?
        for policy in value.split(separator: ",") {
            var r: Int?
            var t: Int?
            for field in policy.split(separator: ";") {
                let kv = field.split(separator: "=", maxSplits: 1)
                guard kv.count == 2 else { continue }
                let k = kv[0].trimmingCharacters(in: .whitespaces)
                let v = Int(kv[1].trimmingCharacters(in: .whitespaces))
                if k == "r" { r = v }
                if k == "t" { t = v }
            }
            if r == 0, let t { maxT = max(maxT ?? 0, t) }
        }
        return maxT
    }
}
