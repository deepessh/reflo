import Foundation

enum HTTPTransportError: Error, Equatable, Sendable {
    case redirectRejected
    case invalidResponse
    case network
    case cancelled
}

struct HTTPRequest: Sendable {
    let url: URL
    let method: String
    let headers: [String: String]
    let body: Data?

    init(url: URL, method: String = "GET", headers: [String: String] = [:], body: Data? = nil) {
        self.url = url
        self.method = method
        self.headers = headers
        self.body = body
    }
}

struct HTTPResponse: Sendable {
    let statusCode: Int
    let body: Data
}

protocol HTTPTransport: Sendable {
    func send(_ request: HTTPRequest) async throws -> HTTPResponse
}

final class NoRedirectURLSessionTransport: HTTPTransport, @unchecked Sendable {
    private let session: URLSession

    init(session: URLSession? = nil) {
        if let session {
            self.session = session
        } else {
            let config = URLSessionConfiguration.default
            config.timeoutIntervalForRequest = 150
            config.timeoutIntervalForResource = 300
            self.session = URLSession(
                configuration: config,
                delegate: NoRedirectSessionDelegate.shared,
                delegateQueue: nil
            )
        }
    }

    func send(_ request: HTTPRequest) async throws -> HTTPResponse {
        var urlRequest = URLRequest(url: request.url)
        urlRequest.httpMethod = request.method
        for (key, value) in request.headers {
            urlRequest.setValue(value, forHTTPHeaderField: key)
        }
        urlRequest.httpBody = request.body

        let data: Data
        let response: URLResponse
        do {
            (data, response) = try await session.data(for: urlRequest)
        } catch is CancellationError {
            throw HTTPTransportError.cancelled
        } catch let error as URLError where error.code == .cancelled {
            throw HTTPTransportError.cancelled
        } catch {
            throw HTTPTransportError.network
        }

        guard let http = response as? HTTPURLResponse else {
            throw HTTPTransportError.invalidResponse
        }

        return HTTPResponse(statusCode: http.statusCode, body: data)
    }
}

private final class NoRedirectSessionDelegate: NSObject, URLSessionTaskDelegate, @unchecked Sendable {
    static let shared = NoRedirectSessionDelegate()

    func urlSession(
        _ session: URLSession,
        task: URLSessionTask,
        willPerformHTTPRedirection response: HTTPURLResponse,
        newRequest request: URLRequest,
        completionHandler: @escaping (URLRequest?) -> Void
    ) {
        completionHandler(nil)
    }
}

actor FakeHTTPTransport: HTTPTransport {
    struct Observation: Sendable {
        let request: HTTPRequest
    }

    private var responses: [(HTTPResponse?, HTTPTransportError?)]
    private(set) var observations: [Observation] = []

    init(responses: [(HTTPResponse?, HTTPTransportError?)]) {
        self.responses = responses
    }

    func send(_ request: HTTPRequest) async throws -> HTTPResponse {
        observations.append(Observation(request: request))
        guard !responses.isEmpty else {
            throw HTTPTransportError.network
        }
        let next = responses.removeFirst()
        if let error = next.1 {
            throw error
        }
        guard let response = next.0 else {
            throw HTTPTransportError.network
        }
        return response
    }
}
