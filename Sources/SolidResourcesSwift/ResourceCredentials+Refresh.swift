//
//  ResourceCredentials+Refresh.swift
//  
//
//  Created by Christopher G Prince on 9/25/21.
//

import Foundation
import SolidAuthSwiftTools
import LoggerAPI
import HeliumLogger

extension ResourceCredentials {
    // Uses the refresh token to generate a new access token.
    // If error is nil when the completion handler is called, then the accessToken of this object has been refreshed.
    public func refresh(queue: DispatchQueue = .global(), completion:@escaping (Error?)->()) {
        guard let config = resourceConfigurable else {
            completion(RequestError.noConfiguration)
            return
        }

        guard let refreshToken = refreshToken else {
            completion(RequestError.noRefreshToken)
            return
        }
        
        let refreshParameters = RefreshParameters(tokenEndpoint: config.tokenEndpoint, refreshToken: refreshToken, clientId: config.clientId, clientSecret: config.clientSecret, authenticationMethod: config.authenticationMethod)

        let signingKeys = TokenRequest<JWK_RSA>.SigningKeys(jwk: config.jwk, privateKey: config.privateKey)
        
        tokenRequest = TokenRequest(requestType: .refresh(refreshParameters), signingKeys: signingKeys)
        tokenRequest?.send(queue: queue) { [weak self] result in
            guard let self = self else { return }

            switch result {
            case .failure(let error):
                completion(error)
                
            case .success(let response):
                guard let accessToken = response.access_token else {
                    completion(RequestError.noAccessToken)
                    return
                }
                
                self.accessToken = accessToken
                self.refreshToken = response.refresh_token
                
                guard let refreshDelegate = self.resourceConfigurable.refreshDelegate else {
                    Log.warning("No delegate.")
                    completion(nil)
                    return
                }
                
                refreshDelegate.accessTokenRefreshed(self) { success in
                    guard success else {
                        completion(RequestError.refreshDelegateFailure)
                        return
                    }
                    
                    completion(nil)
                }
            }
        }
    }
}
