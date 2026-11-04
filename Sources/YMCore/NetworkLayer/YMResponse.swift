import Foundation

/// Root API response envelope returned by Yandex Music API:
/// `{ "invocationInfo": {...}, "result": <T>, "error": {...} }`
public struct YMResponse<T: Decodable & Sendable>: Decodable, Sendable {
    public let invocationInfo: YMInvocationInfo?
    public let result: T?
    public let error: YMAPIErrorPayload?

    public init(invocationInfo: YMInvocationInfo? = nil, result: T? = nil, error: YMAPIErrorPayload? = nil) {
        self.invocationInfo = invocationInfo
        self.result = result
        self.error = error
    }

    /// Automatically unwraps the result or throws a typed `YMAPIError`.
    public func unwrap() throws -> T {
        if let error = error {
            throw YMAPIError.serverError(
                name: error.name ?? "unknown_error",
                message: error.message ?? "No error message provided."
            )
        }
        guard let result = result else {
            throw YMAPIError.emptyResult
        }
        return result
    }
}

public struct YMInvocationInfo: Decodable, Sendable {
    public let reqId: String?
    public let hostname: String?
    public let execDurationMillis: Int?

    enum CodingKeys: String, CodingKey {
        case reqId = "req-id"
        case hostname
        case execDurationMillis = "exec-duration-millis"
    }

    public init(reqId: String? = nil, hostname: String? = nil, execDurationMillis: Int? = nil) {
        self.reqId = reqId
        self.hostname = hostname
        self.execDurationMillis = execDurationMillis
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        self.reqId = try? container.decodeIfPresent(String.self, forKey: .reqId)
        self.hostname = try? container.decodeIfPresent(String.self, forKey: .hostname)
        if let intVal = try? container.decodeIfPresent(Int.self, forKey: .execDurationMillis) {
            self.execDurationMillis = intVal
        } else if let strVal = try? container.decodeIfPresent(String.self, forKey: .execDurationMillis), let parsed = Int(strVal) {
            self.execDurationMillis = parsed
        } else {
            self.execDurationMillis = nil
        }
    }
}

public struct YMAPIErrorPayload: Decodable, Sendable {
    public let name: String?
    public let message: String?

    public init(from decoder: Decoder) throws {
        if let container = try? decoder.container(keyedBy: CodingKeys.self) {
            self.name = try? container.decodeIfPresent(String.self, forKey: .name)
            self.message = try? container.decodeIfPresent(String.self, forKey: .message)
        } else if let singleContainer = try? decoder.singleValueContainer(),
                  let stringVal = try? singleContainer.decode(String.self) {
            self.name = stringVal
            self.message = stringVal
        } else {
            self.name = nil
            self.message = nil
        }
    }

    enum CodingKeys: String, CodingKey {
        case name
        case message
    }
}

public enum YMAPIError: Error, LocalizedError, Sendable {
    case invalidURL(String)
    case unauthorized
    case serverError(name: String, message: String)
    case httpError(statusCode: Int, data: Data?)
    case emptyResult
    case streamExpired
    case decodingError(String)

    public var errorDescription: String? {
        switch self {
        case .invalidURL(let url):
            return "Invalid URL: \(url)"
        case .unauthorized:
            return "Unauthorized (401). Invalid or expired OAuth token."
        case .serverError(let name, let message):
            return "Yandex Music API error [\(name)]: \(message)"
        case .httpError(let statusCode, _):
            return "HTTP Error \(statusCode)"
        case .emptyResult:
            return "Response returned empty result with no error."
        case .streamExpired:
            return "Audio stream link expired (CDN 401/403)."
        case .decodingError(let details):
            return "Failed to decode response: \(details)"
        }
    }
}
