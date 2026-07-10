import Foundation

enum LLMEndpointError: Error, Equatable, Sendable {
    case emptyInput
    case invalidURL
    case unsupportedComponent(String)
    case invalidHost
    case publicHTTPNotAllowed
    case httpConfirmationRequired
}

struct LLMEndpoint: Sendable, Equatable {
    let url: URL
    let requiresHTTPConfirmation: Bool

    var normalizedString: String {
        Self.canonicalString(for: url)
    }

    func routeURL(for route: Route) -> URL {
        var components = URLComponents()
        components.scheme = url.scheme
        components.host = url.host
        components.port = url.port

        let basePath = url.path.trimmingCharacters(in: CharacterSet(charactersIn: "/"))
        let routePath = route.rawValue
        let combined = [basePath, routePath]
            .filter { !$0.isEmpty }
            .joined(separator: "/")
        components.path = combined.isEmpty ? "/" : "/\(combined)"
        guard let built = components.url else {
            preconditionFailure("Canonical endpoint should always produce route URLs.")
        }
        return built
    }

    enum Route: String, Sendable {
        case models
        case chatCompletions = "chat/completions"
    }

    static func parse(
        _ input: String,
        httpConfirmed: Bool = false
    ) throws -> LLMEndpoint {
        let trimmed = input.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else {
            throw LLMEndpointError.emptyInput
        }

        guard var components = URLComponents(string: trimmed) else {
            throw LLMEndpointError.invalidURL
        }

        if components.scheme == nil {
            components.scheme = "https"
        }

        guard let scheme = components.scheme?.lowercased(),
              scheme == "http" || scheme == "https"
        else {
            throw LLMEndpointError.unsupportedComponent("scheme")
        }

        if components.user != nil || components.password != nil {
            throw LLMEndpointError.unsupportedComponent("userinfo")
        }

        if components.query != nil {
            throw LLMEndpointError.unsupportedComponent("query")
        }

        if components.fragment != nil {
            throw LLMEndpointError.unsupportedComponent("fragment")
        }

        guard let host = components.host, !host.isEmpty else {
            throw LLMEndpointError.invalidHost
        }

        let hostClassification = try classifyHost(host)
        if scheme == "http", !hostClassification.allowsPlainHTTP {
            throw LLMEndpointError.publicHTTPNotAllowed
        }

        if let port = components.port, !(1 ... 65535).contains(port) {
            throw LLMEndpointError.invalidURL
        }

        let path = components.percentEncodedPath
        if path.contains("%2F") || path.contains("%2f") {
            throw LLMEndpointError.unsupportedComponent("encoded path separator")
        }
        if path.contains("/../") || path.hasSuffix("/..") || path.contains("/./") || path.hasSuffix("/.") {
            throw LLMEndpointError.unsupportedComponent("dot segment")
        }

        components.scheme = scheme
        components.host = hostClassification.canonicalHost
        components.path = normalizePath(path)

        guard let url = components.url else {
            throw LLMEndpointError.invalidURL
        }

        let requiresConfirmation = scheme == "http" && hostClassification.allowsPlainHTTP
        if requiresConfirmation, !httpConfirmed {
            throw LLMEndpointError.httpConfirmationRequired
        }

        return LLMEndpoint(url: url, requiresHTTPConfirmation: requiresConfirmation)
    }

    static func canonicalString(for url: URL) -> String {
        var components = URLComponents()
        components.scheme = url.scheme?.lowercased()
        components.host = url.host?.lowercased()
        components.port = url.port
        components.path = normalizePath(url.path)
        return components.string ?? url.absoluteString
    }

    private static func normalizePath(_ path: String) -> String {
        let trimmed = path.trimmingCharacters(in: CharacterSet(charactersIn: "/"))
        guard !trimmed.isEmpty else {
            return "/"
        }
        return "/\(trimmed)"
    }

    private struct HostClassification {
        let canonicalHost: String
        let allowsPlainHTTP: Bool
    }

    private static func classifyHost(_ rawHost: String) throws -> HostClassification {
        let host = rawHost.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !host.isEmpty else {
            throw LLMEndpointError.invalidHost
        }

        if host.contains(":") {
            return try classifyIPv6Host(host)
        }

        if isLegacyNumericHost(host) {
            throw LLMEndpointError.invalidHost
        }

        if let ipv4 = parseIPv4(host) {
            let allows = isPrivateIPv4(ipv4)
            return HostClassification(canonicalHost: host, allowsPlainHTTP: allows)
        }

        let lower = host.lowercased()
        if lower == "localhost" {
            return HostClassification(canonicalHost: lower, allowsPlainHTTP: true)
        }

        if lower.hasSuffix(".local") {
            return HostClassification(canonicalHost: lower, allowsPlainHTTP: true)
        }

        if isUnqualifiedLocalName(lower) {
            return HostClassification(canonicalHost: lower, allowsPlainHTTP: true)
        }

        return HostClassification(canonicalHost: lower, allowsPlainHTTP: false)
    }

    private static func classifyIPv6Host(_ host: String) throws -> HostClassification {
        var bracketed = host
        if bracketed.hasPrefix("[") && bracketed.hasSuffix("]") {
            bracketed = String(bracketed.dropFirst().dropLast())
        }

        if let mapped = parseIPv4MappedIPv6(bracketed) {
            return HostClassification(
                canonicalHost: "[\(bracketed.lowercased())]",
                allowsPlainHTTP: isPrivateIPv4(mapped)
            )
        }

        guard isValidIPv6(bracketed) else {
            throw LLMEndpointError.invalidHost
        }

        let lower = bracketed.lowercased()
        let allows = isPrivateIPv6(lower)
        return HostClassification(canonicalHost: "[\(lower)]", allowsPlainHTTP: allows)
    }

    private static func isLegacyNumericHost(_ host: String) -> Bool {
        if host.hasPrefix("0x") || host.hasPrefix("0X") {
            return true
        }
        if host.hasPrefix("0") && host.count > 1 && host.allSatisfy({ $0.isNumber }) {
            return true
        }
        if host.allSatisfy({ $0.isNumber }) {
            return true
        }
        return false
    }

    private static func parseIPv4(_ host: String) -> (UInt8, UInt8, UInt8, UInt8)? {
        let parts = host.split(separator: ".", omittingEmptySubsequences: false)
        guard parts.count == 4 else { return nil }
        var bytes: [UInt8] = []
        for part in parts {
            guard let value = Int(part), (0 ... 255).contains(value) else {
                return nil
            }
            bytes.append(UInt8(value))
        }
        return (bytes[0], bytes[1], bytes[2], bytes[3])
    }

    private static func parseIPv4MappedIPv6(_ host: String) -> (UInt8, UInt8, UInt8, UInt8)? {
        let lower = host.lowercased()
        if lower.hasPrefix("::ffff:") {
            let suffix = String(lower.dropFirst("::ffff:".count))
            if suffix.contains(".") {
                return parseIPv4(suffix)
            }
        }
        return nil
    }

    private static func isValidIPv6(_ host: String) -> Bool {
        let parts = host.split(separator: ":", omittingEmptySubsequences: false)
        guard parts.count >= 2, parts.count <= 8 else { return false }
        return parts.allSatisfy { part in
            part.isEmpty || (part.count <= 4 && part.allSatisfy { $0.isHexDigit })
        }
    }

    private static func isPrivateIPv4(_ address: (UInt8, UInt8, UInt8, UInt8)) -> Bool {
        let (a, b, _, _) = address
        if a == 127 { return true }
        if a == 10 { return true }
        if a == 172 && (16 ... 31).contains(b) { return true }
        if a == 192 && b == 168 { return true }
        if a == 169 && b == 254 { return true }
        return false
    }

    private static func isPrivateIPv6(_ host: String) -> Bool {
        if host == "::1" { return true }
        if host.hasPrefix("fc") || host.hasPrefix("fd") { return true }
        if host.hasPrefix("fe80") { return true }
        return false
    }

    private static func isUnqualifiedLocalName(_ host: String) -> Bool {
        guard !host.contains(".") else { return false }
        return host.range(of: "^[a-z0-9-]+$", options: .regularExpression) != nil
    }
}
