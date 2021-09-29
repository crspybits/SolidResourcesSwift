//
//  ResourceRequest.swift
//
//
//  Created by Christopher G Prince on 8/20/21.
//

import Foundation
#if canImport(FoundationNetworking)
    import FoundationNetworking
#endif
import LoggerAPI
import HeliumLogger
import SolidAuthSwiftTools

public enum HttpMethod: String {
    case POST
    case GET
    case DELETE
    case HEAD
    case PUT
}

public enum Header: String {
    case contentType = "Content-Type"
    case slug // resource name
    case authorization
    case dpop
    case link = "Link" // Upper case "L" because response headers have it this way.
    case host
    case accept
    
    // At least in the NSS for PUT requests, this wasn't implemented when I tried it: https://github.com/solid/node-solid-server/issues/1431
    case ifNoneMatch = "If-None-Match"
}

public protocol DebugResponse {
    var data: Data? { get }
    var headers: [AnyHashable : Any] { get }
    var statusCode: Int? { get }
}

public struct DebugOptions: OptionSet {
    public let rawValue: Int
    
    public init(rawValue:Int) {
        self.rawValue = rawValue
    }

    public static let data = DebugOptions(rawValue: 1 << 0)
    public static let headers = DebugOptions(rawValue: 1 << 1)
    public static let statusCode = DebugOptions(rawValue: 1 << 2)

    public static let all: DebugOptions = [.data, .headers, .statusCode]
}

extension DebugResponse {
    func debug(_ options: DebugOptions = [.data], heading: String? = nil) -> String {
        var result = ""
        
        if options.contains(.data) {
            if let data = data, let dataString = String(data: data, encoding: .utf8) {
                result += "Data: \(dataString)"
            }
        }
        
        if options.contains(.headers) {
            result += "Headers: \(headers)"
        }
        
        if options.contains(.statusCode) {
            if let statusCode = statusCode {
                result += "Status Code: \(statusCode)"
            }
        }
        
        if let heading = heading, result.count > 0 {
            result = "\(heading):\n\(result)"
        }
        
        return result
    }
}

enum RequestError: Error {
    case noHTTPURLResponse
    case badStatusCode
    case noAccessToken
    case noRefreshToken
    case headersAlreadyHave(Header)
    case noConfiguration
    case couldNotGetURLHost
    case failedToRefreshAccessToken(Error)
    case refreshDelegateFailure
}

public struct Success: DebugResponse {
    public let data: Data?
    public let headers: [AnyHashable : Any]
    public let statusCode: Int?
}

public struct Failure: DebugResponse {
    public let error: Error
    public let data: Data?
    public let headers: [AnyHashable : Any]
    public let statusCode: Int?
    
    init(_ error: Error, data: Data? = nil, headers: [AnyHashable : Any] = [:], statusCode: Int? = nil) {
        self.error = error
        self.data = data
        self.headers = headers
        self.statusCode = statusCode
    }
}

public enum RequestResult {
    case success(Success)
    case failure(Failure)
}
    
public extension ResourceCredentials {
    /* Returns DPoP and access token headers. Format is:
        Headers: {
            authorization: "DPoP ACCESS TOKEN",
            dpop: "DPOP TOKEN"
        }
        See https://solid.github.io/solid-oidc/primer/
        Depends on the `jwk`, `configuration`, and the current `accessToken`
        
        `url` is the actual endpoint used in the HTTP request.
    */
    private func createAuthenticationHeaders(url: URL, httpMethod: HttpMethod) throws -> [Header: String] {
        guard let config = resourceConfigurable else {
            throw RequestError.noConfiguration
        }
        
        guard let accessToken = accessToken else {
            throw RequestError.noAccessToken
        }
        
        let jti = UUID().uuidString
        
        /* I thought initially, I should append a "/" to the htu because I was getting the following in the http response (despite having a 200 status code):
            
            AnyHashable("Www-Authenticate"): "Bearer realm=\"https://inrupt.net\", error=\"invalid_token\", error_description=\"htu https://crspybits.inrupt.net/NewDirectory does not match https://crspybits.inrupt.net/NewDirectory/\""
            
            But that response header doesn't always occur: https://github.com/solid/node-solid-server/issues/1572#issuecomment-903193101
        */
        let htu = url.absoluteString
        Log.debug("htu: \(htu)")
        
        let ath = try BodyClaims.athFromAccessToken(accessToken)
        Log.debug("ath: \(ath)")
        
        let body = BodyClaims(htu: htu, htm: httpMethod.rawValue, jti: jti, ath: ath)
        let dpop = DPoP(jwk: config.jwk, privateKey: config.privateKey, body: body)
        let signed = try dpop.generate()
        
        return [
            .authorization: "DPoP \(accessToken)",
            .dpop: signed
        ]
    }
    
    // The headers must not include authorization, dpop or host: That will cause the request to fail.
    // Parameters:
    //  - path: appended to the sstorageIRI, if given.
    //  - httpMethod: The HTTP method.
    //  - body: Body data for outgoing request. Typically only used for POST's or PUT's.
    //  - headers: HTTP request headers.
    //  - accessTokenAutoRefresh: Whether or not to automatically refresh the access token if we get a http status 401. A refresh is only tried once. Callers typically should just use the default.
    func request(path: String? = nil, httpMethod: HttpMethod, body: Data? = nil, headers: [Header: String], accessTokenAutoRefresh: Bool = true, completion: @escaping (RequestResult) -> ()) {
    
        guard let config = resourceConfigurable else {
            completion(.failure(Failure(RequestError.noConfiguration)))
            return
        }

        var requestURL = config.storageIRI
        
        if let path = path {
            requestURL.appendPathComponent(path)
        }
        
        guard headers[Header.authorization] == nil,
            headers[Header.dpop] == nil else {
            completion(.failure(Failure(RequestError.headersAlreadyHave(.dpop))))
            return
        }

        guard headers[Header.host] == nil else {
            completion(.failure(Failure(RequestError.headersAlreadyHave(.host))))
            return
        }
                
        var request = URLRequest(url: requestURL)
        request.httpMethod = httpMethod.rawValue
        request.httpBody = body
        
        for (key, value) in headers {
            request.addValue(value, forHTTPHeaderField: key.rawValue)
        }

        do {
            let authHeaders = try createAuthenticationHeaders(url: requestURL, httpMethod: httpMethod)
            for (key, value) in authHeaders {
                request.addValue(value, forHTTPHeaderField: key.rawValue)
            }
        } catch let error {
            completion(.failure(Failure(error)))
            return
        }
        
        guard let urlHost = requestURL.host else {
            completion(.failure(Failure(RequestError.couldNotGetURLHost)))
            return
        }
        
        request.addValue(urlHost, forHTTPHeaderField: Header.host.rawValue)

        Log.debug("Request: method: \(httpMethod)")
        Log.debug("Request: url.host: \(urlHost)")
        Log.debug("Request: Request headers: \(String(describing:request.allHTTPHeaderFields))")
        Log.debug("Request: URL: \(requestURL)")

        let session = URLSession(configuration: .default, delegate: nil, delegateQueue: nil)
        session.dataTask(with: request, completionHandler: { [weak self] data, response, error in
            guard let self = self else { return }

            if let error = error {
                completion(.failure(Failure(error)))
                return
            }

            guard let response = response as? HTTPURLResponse else {
                completion(.failure(Failure(RequestError.noHTTPURLResponse, data: data)))
                return
            }
            
            // Do we need to refresh the access token?
            if response.statusCode == 401 && accessTokenAutoRefresh {
                self.refresh { error in
                    if let error = error {
                        completion(.failure(
                            Failure(RequestError.failedToRefreshAccessToken(error), data: data, headers:response.allHeaderFields, statusCode: response.statusCode)))
                        return
                    }
                    
                    // Retry the request, but this time don't allow the access token to be refreshed.
                    self.request(path: path, httpMethod: httpMethod, body: body, headers: headers, accessTokenAutoRefresh: false, completion: completion)
                }
                return
            }
            
            guard NetworkingExtras.statusCodeOK(response.statusCode) else {
                completion(.failure(
                    Failure(RequestError.badStatusCode, data: data, headers:response.allHeaderFields, statusCode: response.statusCode)))
                return
            }

            let success = Success(data: data, headers: response.allHeaderFields, statusCode: response.statusCode)
            
            completion(.success(success))
        }).resume()
    }
}

