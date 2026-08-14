//
//  IPv4PreferringHTTP.swift
//  WorkX
//
//  Prefer IPv4 when calling the API so attendance IP whitelist (stable office
//  WAN IPv4) matches. Dual-stack hosts (e.g. Cloudflare) otherwise often use
//  temporary IPv6 that changes and fails exact-IP matching.
//
//  Connects to an A-record address while keeping TLS SNI + Host = original hostname
//  (same idea as OkHttp Dns filtering on Android).
//

import Foundation
import Network
import Darwin

enum IPv4PreferringHTTP {
    static func isIPLiteral(_ host: String) -> Bool {
        if host.contains(":") { return true }
        let parts = host.split(separator: ".", omittingEmptySubsequences: false)
        guard parts.count == 4 else { return false }
        return parts.allSatisfy { p in
            guard let n = Int(p), (0...255).contains(n) else { return false }
            return true
        }
    }

    static func resolveIPv4(_ hostname: String) -> [String] {
        var hints = addrinfo(
            ai_flags: AI_ADDRCONFIG,
            ai_family: AF_INET,
            ai_socktype: SOCK_STREAM,
            ai_protocol: 0,
            ai_addrlen: 0,
            ai_canonname: nil,
            ai_addr: nil,
            ai_next: nil
        )
        var result: UnsafeMutablePointer<addrinfo>?
        let rc = getaddrinfo(hostname, nil, &hints, &result)
        guard rc == 0, let first = result else { return [] }
        defer { freeaddrinfo(first) }

        var out: [String] = []
        var ptr: UnsafeMutablePointer<addrinfo>? = first
        while let info = ptr {
            if info.pointee.ai_family == AF_INET, let addr = info.pointee.ai_addr {
                var buf = [CChar](repeating: 0, count: Int(NI_MAXHOST))
                let gni = getnameinfo(
                    addr,
                    socklen_t(info.pointee.ai_addrlen),
                    &buf,
                    socklen_t(buf.count),
                    nil,
                    0,
                    NI_NUMERICHOST
                )
                if gni == 0 {
                    let s = String(cString: buf)
                    if !out.contains(s) { out.append(s) }
                }
            }
            ptr = info.pointee.ai_next
        }
        return out
    }

    /// Fetch via IPv4 when possible; falls back to system URLSession (may use IPv6).
    static func data(for request: URLRequest, fallbackSession: URLSession) async throws -> (Data, URLResponse) {
        guard let url = request.url,
              let host = url.host,
              !host.isEmpty,
              !isIPLiteral(host),
              url.scheme?.lowercased() == "https",
              let ipv4 = resolveIPv4(host).first
        else {
            return try await fallbackSession.data(for: request)
        }

        do {
            return try await ipv4HTTPSData(for: request, host: host, ipv4: ipv4)
        } catch {
            // Fallback if direct IPv4 path fails (TLS/network)
            return try await fallbackSession.data(for: request)
        }
    }

    private static func ipv4HTTPSData(
        for request: URLRequest,
        host: String,
        ipv4: String
    ) async throws -> (Data, URLResponse) {
        let port: UInt16 = UInt16(request.url?.port ?? 443)
        let tcp = NWProtocolTCP.Options()
        let tls = NWProtocolTLS.Options()
        host.withCString { cName in
            sec_protocol_options_set_tls_server_name(
                tls.securityProtocolOptions,
                cName
            )
        }
        let params = NWParameters(tls: tls, tcp: tcp)
        let connection = NWConnection(
            host: NWEndpoint.Host(ipv4),
            port: NWEndpoint.Port(rawValue: port)!,
            using: params
        )

        try await withCheckedThrowingContinuation { (cont: CheckedContinuation<Void, Error>) in
            connection.stateUpdateHandler = { state in
                switch state {
                case .ready:
                    connection.stateUpdateHandler = nil
                    cont.resume()
                case .failed(let err):
                    connection.stateUpdateHandler = nil
                    cont.resume(throwing: err)
                case .cancelled:
                    connection.stateUpdateHandler = nil
                    cont.resume(throwing: URLError(.cancelled))
                default:
                    break
                }
            }
            connection.start(queue: .global(qos: .userInitiated))
        }

        defer { connection.cancel() }

        let http = try buildHTTP11Request(request, host: host)
        try await sendAll(connection, data: http)
        let raw = try await readHTTPResponse(connection)
        return try parseHTTPResponse(raw, originalURL: request.url!)
    }

    private static func buildHTTP11Request(_ request: URLRequest, host: String) throws -> Data {
        let method = request.httpMethod ?? "GET"
        let path: String = {
            guard let url = request.url else { return "/" }
            var p = url.path
            if p.isEmpty { p = "/" }
            if let q = url.query, !q.isEmpty { p += "?\(q)" }
            return p
        }()

        var headerLines: [String] = [
            "\(method) \(path) HTTP/1.1",
            "Host: \(host)",
            "Connection: close",
        ]

        var hasContentType = false
        var hasAccept = false
        if let headers = request.allHTTPHeaderFields {
            for (k, v) in headers {
                let key = k.lowercased()
                if key == "host" || key == "connection" { continue }
                if key == "content-type" { hasContentType = true }
                if key == "accept" { hasAccept = true }
                headerLines.append("\(k): \(v)")
            }
        }
        if !hasContentType {
            headerLines.append("Content-Type: application/json")
        }
        if !hasAccept {
            headerLines.append("Accept: application/json")
        }
        headerLines.append("Accept-Encoding: identity")

        let body = request.httpBody ?? Data()
        headerLines.append("Content-Length: \(body.count)")

        var message = headerLines.joined(separator: "\r\n") + "\r\n\r\n"
        var data = Data(message.utf8)
        data.append(body)
        return data
    }

    private static func sendAll(_ connection: NWConnection, data: Data) async throws {
        try await withCheckedThrowingContinuation { (cont: CheckedContinuation<Void, Error>) in
            connection.send(content: data, completion: .contentProcessed { error in
                if let error {
                    cont.resume(throwing: error)
                } else {
                    cont.resume()
                }
            })
        }
    }

    private static func readHTTPResponse(_ connection: NWConnection) async throws -> Data {
        var buffer = Data()
        while true {
            let chunk: Data = try await withCheckedThrowingContinuation { cont in
                connection.receive(minimumIncompleteLength: 1, maximumLength: 64 * 1024) { content, _, isComplete, error in
                    if let error {
                        cont.resume(throwing: error)
                        return
                    }
                    cont.resume(returning: content ?? Data())
                    if isComplete && (content == nil || content?.isEmpty == true) {
                        // handled below via empty chunk
                    }
                }
            }
            if !chunk.isEmpty {
                buffer.append(chunk)
            }
            if buffer.range(of: Data("\r\n\r\n".utf8)) != nil {
                // If Content-Length known and satisfied, or Connection close with body started — keep reading until empty
                if let contentLength = contentLength(of: buffer) {
                    if let headerEnd = buffer.range(of: Data("\r\n\r\n".utf8)) {
                        let bodyStart = headerEnd.upperBound
                        if buffer.count - bodyStart >= contentLength {
                            break
                        }
                    }
                } else if chunk.isEmpty {
                    break
                }
            } else if chunk.isEmpty {
                break
            }
        }
        guard !buffer.isEmpty else {
            throw URLError(.badServerResponse)
        }
        return buffer
    }

    private static func contentLength(of raw: Data) -> Int? {
        guard let headerEnd = raw.range(of: Data("\r\n\r\n".utf8)) else { return nil }
        let headerData = raw.subdata(in: raw.startIndex..<headerEnd.lowerBound)
        guard let headerText = String(data: headerData, encoding: .utf8) else { return nil }
        for line in headerText.split(separator: "\r\n") {
            let parts = line.split(separator: ":", maxSplits: 1)
            if parts.count == 2, parts[0].lowercased() == "content-length" {
                return Int(parts[1].trimmingCharacters(in: .whitespaces))
            }
        }
        return nil
    }

    private static func parseHTTPResponse(_ raw: Data, originalURL: URL) throws -> (Data, URLResponse) {
        guard let headerEnd = raw.range(of: Data("\r\n\r\n".utf8)) else {
            throw URLError(.badServerResponse)
        }
        let headerData = raw.subdata(in: raw.startIndex..<headerEnd.lowerBound)
        let body = raw.subdata(in: headerEnd.upperBound..<raw.endIndex)
        guard let headerText = String(data: headerData, encoding: .utf8) else {
            throw URLError(.badServerResponse)
        }
        let lines = headerText.split(separator: "\r\n", omittingEmptySubsequences: false)
        guard let statusLine = lines.first else { throw URLError(.badServerResponse) }
        let statusParts = statusLine.split(separator: " ")
        guard statusParts.count >= 2, let code = Int(statusParts[1]) else {
            throw URLError(.badServerResponse)
        }
        var headers: [String: String] = [:]
        for line in lines.dropFirst() {
            if line.isEmpty { break }
            let parts = line.split(separator: ":", maxSplits: 1)
            if parts.count == 2 {
                headers[String(parts[0])] = parts[1].trimmingCharacters(in: .whitespaces)
            }
        }
        let response = HTTPURLResponse(
            url: originalURL,
            statusCode: code,
            httpVersion: "HTTP/1.1",
            headerFields: headers
        )!
        return (body, response)
    }
}
