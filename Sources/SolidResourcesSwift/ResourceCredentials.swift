//
//  ResourceCredentials.swift
//  
//
//  Created by Christopher G Prince on 9/25/21.
//

import Foundation
import SolidAuthSwiftTools

public protocol RefreshDelegate: AnyObject {
    // Called on a successful refresh of the access token.
    // The completion handler should only be called with false if an error occurred in the delegate handling. E.g., if this saved creds to a database and that failed.
    func accessTokenRefreshed(_ credentials: ResourceCredentials, completion:(Bool)->())
}

public protocol ResourceConfiguration {
    // The public PEM key converted to a JWK.
    var jwk: JWK_RSA { get }
    
    var privateKey: String { get }
    
    var clientId: String { get }
    var clientSecret: String { get }
    
    // The "base URL" to use to make requests to the users Solid Pod.
    var storageIRI: URL { get }
    
    var tokenEndpoint: URL { get }
    
    var authenticationMethod: TokenEndpointAuthenticationMethod { get }
    
    var refreshDelegate:RefreshDelegate? { get }
}

public protocol ResourceCredentials: AnyObject {
    var config: ResourceConfiguration! { get }
    
    // Leave this nil. Just a convenience.
    var tokenRequest:TokenRequest<JWK_RSA>? { get set }
        
    var accessToken: String! { get set }
    var refreshToken: String! { get set }
}
