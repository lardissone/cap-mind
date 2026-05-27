import Foundation

enum MyMindRequests {
    static func noteJSONBody(markdown: String) throws -> Data {
        let payload: [String: Any] = ["content": ["type": "text/markdown", "body": markdown]]
        return try JSONSerialization.data(withJSONObject: payload, options: [.sortedKeys])
    }
    static func urlJSONBody(url: URL) throws -> Data {
        try JSONSerialization.data(withJSONObject: ["url": url.absoluteString], options: [.sortedKeys])
    }
    /// Builds multipart body with empty metadata `{}` and the binary blob. Returns (body, Content-Type).
    static func multipart(boundary: String = UUID().uuidString,
                          blob: Data, mimeType: String, filename: String) -> (Data, String) {
        var body = Data()
        func append(_ s: String) { body.append(Data(s.utf8)) }
        append("--\(boundary)\r\n")
        append("Content-Disposition: form-data; name=\"metadata\"\r\n")
        append("Content-Type: application/json\r\n\r\n")
        append("{}\r\n")
        append("--\(boundary)\r\n")
        append("Content-Disposition: form-data; name=\"blob\"; filename=\"\(filename)\"\r\n")
        append("Content-Type: \(mimeType)\r\n\r\n")
        body.append(blob)
        append("\r\n")
        append("--\(boundary)--\r\n")
        return (body, "multipart/form-data; boundary=\(boundary)")
    }
}
