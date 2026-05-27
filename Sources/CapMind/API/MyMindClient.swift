import Foundation

final class MyMindClient: Sendable {
    private let credentials: CredentialsProviding
    private let session: URLSession

    init(credentialsProvider: CredentialsProviding, urlSession: URLSession = .shared) {
        self.credentials = credentialsProvider
        self.session = urlSession
    }

    func createObjectFromContent(_ markdown: String) async throws -> ObjectRef {
        let body = try MyMindRequests.noteJSONBody(markdown: markdown)
        return try await send(path: "/objects", method: "POST", body: body, contentType: "application/json")
    }
    func createObjectFromURL(_ url: URL) async throws -> ObjectRef {
        let body = try MyMindRequests.urlJSONBody(url: url)
        return try await send(path: "/objects", method: "POST", body: body, contentType: "application/json")
    }
    func createObjectFromFile(_ data: Data, mimeType: String, filename: String) async throws -> ObjectRef {
        let (body, contentType) = MyMindRequests.multipart(blob: data, mimeType: mimeType, filename: filename)
        return try await send(path: "/objects", method: "POST", body: body, contentType: contentType)
    }
    func testConnection() async throws {
        _ = try await request(path: "/objects?limit=1", signPath: "/objects", method: "GET",
                              body: nil, contentType: nil, allowRetry: false)
    }

    private func send(path: String, method: String, body: Data?, contentType: String?) async throws -> ObjectRef {
        let data = try await request(path: path, signPath: path, method: method,
                                     body: body, contentType: contentType, allowRetry: true)
        do { return try JSONDecoder().decode(ObjectRef.self, from: data) }
        catch { throw MyMindError.decoding(String(describing: error)) }
    }

    private func request(path: String, signPath: String, method: String,
                         body: Data?, contentType: String?, allowRetry: Bool) async throws -> Data {
        guard let creds = credentials.currentCredentials() else { throw MyMindError.unauthorized }
        let signer = MyMindJWTSigner(keyID: creds.keyID, secret: creds.secret)
        let jwt = try signer.sign(path: signPath, method: method)

        guard let url = URL(string: AppConstants.apiBaseURL.absoluteString + path) else {
            throw MyMindError.unavailable
        }
        var req = URLRequest(url: url)
        req.httpMethod = method
        req.setValue("Bearer \(jwt)", forHTTPHeaderField: "Authorization")
        req.setValue(AppConstants.userAgent, forHTTPHeaderField: "User-Agent")
        if let contentType { req.setValue(contentType, forHTTPHeaderField: "Content-Type") }
        req.httpBody = body

        let data: Data
        let response: URLResponse
        do { (data, response) = try await session.data(for: req) }
        catch let urlError as URLError { throw MyMindError.network(urlError) }

        guard let http = response as? HTTPURLResponse else { throw MyMindError.unavailable }
        if (200...299).contains(http.statusCode) { return data }

        let problem = try? JSONDecoder().decode(ProblemJSON.self, from: data)
        let mapped = Self.mapError(status: http.statusCode, problem: problem,
                                   rateLimitHeader: http.value(forHTTPHeaderField: "RateLimit"))
        if case .rateLimited(let secs) = mapped, allowRetry {
            if secs > 0 { try await Task.sleep(nanoseconds: UInt64(secs) * 1_000_000_000) }
            return try await request(path: path, signPath: signPath, method: method,
                                     body: body, contentType: contentType, allowRetry: false)
        }
        throw mapped
    }

    static func mapError(status: Int, problem: ProblemJSON?, rateLimitHeader: String?) -> MyMindError {
        let detail = problem?.detail ?? ""
        switch status {
        case 400: return .badRequest(detail)
        case 401: return .unauthorized
        case 403: return .forbidden
        case 404: return .notFound
        case 413: return .payloadTooLarge
        case 422: return .unprocessable(detail)
        case 429:
            let secs = rateLimitHeader.flatMap(RateLimitHeader.maxResetForExhausted) ?? 1
            return .rateLimited(retryAfterSeconds: secs)
        case 503: return .unavailable
        case 500...599: return .server(detail)
        default: return .server(detail)
        }
    }
}
