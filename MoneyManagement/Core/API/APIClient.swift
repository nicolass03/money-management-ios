import Foundation

final class APIClient {
    private let baseURL: URL
    private let session: URLSession
    private let tokenProvider: () async throws -> String
    private let onUnauthorized: () async -> Void

    private static let decoder: JSONDecoder = {
        let d = JSONDecoder()
        return d
    }()

    private static let encoder: JSONEncoder = {
        let e = JSONEncoder()
        return e
    }()

    init(
        baseURL: URL = AppConfig.apiURL,
        session: URLSession = .shared,
        tokenProvider: @escaping () async throws -> String,
        onUnauthorized: @escaping () async -> Void
    ) {
        self.baseURL = baseURL
        self.session = session
        self.tokenProvider = tokenProvider
        self.onUnauthorized = onUnauthorized
    }

    func request<T: Decodable>(
        _ method: String,
        path: String,
        query: [URLQueryItem] = [],
        body: (any Encodable)? = nil
    ) async throws -> T {
        let data = try await requestData(method, path: path, query: query, body: body)
        if T.self == SuccessResponse.self, data.isEmpty {
            return SuccessResponse(success: true) as! T
        }
        return try Self.decoder.decode(T.self, from: data)
    }

    func requestVoid(
        _ method: String,
        path: String,
        query: [URLQueryItem] = [],
        body: (any Encodable)? = nil
    ) async throws {
        _ = try await requestData(method, path: path, query: query, body: body)
    }

    private func requestData(
        _ method: String,
        path: String,
        query: [URLQueryItem],
        body: (any Encodable)?
    ) async throws -> Data {
        let trimmed = path.trimmingCharacters(in: CharacterSet(charactersIn: "/"))
        let base = baseURL.absoluteString.trimmingCharacters(in: CharacterSet(charactersIn: "/"))
        var components = URLComponents(string: "\(base)/api/v1/\(trimmed)")
        if !query.isEmpty {
            components?.queryItems = query
        }
        guard let url = components?.url else {
            throw APIError(status: 0, message: "Invalid URL")
        }

        var request = URLRequest(url: url)
        request.httpMethod = method
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        request.setValue("Bearer \(try await tokenProvider())", forHTTPHeaderField: "Authorization")

        if let body {
            request.setValue("application/json", forHTTPHeaderField: "Content-Type")
            request.httpBody = try Self.encoder.encode(AnyEncodable(body))
        }

        let (data, response) = try await session.data(for: request)
        guard let http = response as? HTTPURLResponse else {
            throw APIError(status: 0, message: "Invalid response")
        }

        guard (200...299).contains(http.statusCode) else {
            let message = parseErrorMessage(from: data) ?? "API \(http.statusCode)"
            if http.statusCode == 401 {
                await onUnauthorized()
            }
            throw APIError(status: http.statusCode, message: message)
        }

        return data
    }

    private func parseErrorMessage(from data: Data) -> String? {
        guard !data.isEmpty,
              let err = try? Self.decoder.decode(ErrorResponse.self, from: data) else {
            return nil
        }
        return err.error
    }
}

private struct AnyEncodable: Encodable {
    private let encode: (Encoder) throws -> Void

    init(_ wrapped: any Encodable) {
        encode = wrapped.encode
    }

    func encode(to encoder: Encoder) throws {
        try encode(encoder)
    }
}
