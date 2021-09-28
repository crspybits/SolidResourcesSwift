//
//  AuthenticationTests.swift
//  ServerSolidAccountTests
//
//  Created by Christopher G Prince on 8/21/21.
//

import XCTest
@testable import SolidResourcesSwift
import HeliumLogger

// swift test --enable-test-discovery --filter SolidResourcesSwift.AuthenticationTests/testGenerateTokens

// swift test --enable-test-discovery --filter SolidResourcesSwift.AuthenticationTests/testRefresh

class AuthenticationTests: Common {    
    /* 8/19/21: I just got this:
        String: Optional("{\"error\":\"invalid_grant\",\"error_description\":\"Refresh token not found\"}")
        /root/Apps/ServerSolidAccount/Tests/ServerSolidAccountTests/ServerSolidAccountTests.swift:77: error: ServerSolidAccountTests.testRefresh : failed - badStatusCode(400)
        
        I'm not sure of the conditions under which a refresh token is not found.
        
        My hypothesis is currently that you have to use the most recent refresh token that was generated from the `code` (this in the `codeParametersBase64`). It turns out that you can use the code multiple times and each time it seems to generate a new refresh token.
    */
    func testRefresh() throws {
        try refreshCreds()
    }

    // swift test --enable-test-discovery --filter SolidResourcesSwift.AuthenticationTests/testAutomaticAccessTokenRefresh

    // Don't do an overt `refreshCreds` in here. This is intended to use an expired access token, detect that the access token has expired, and automatically refresh that access token.
    // Testing: With NSS v5.6.8, from a token refresh carried out around 10am 9/5/21 Mountain, I get an access token with an expiry of 2021-09-19 15:46:17 +0000. It looks like access tokens expire in 2 weeks.
    // TODO(https://github.com/SyncServerII/ServerSolidAccount/issues/2): Test this after this access token has expired.
    func testAutomaticAccessTokenRefresh() throws {        
        credentials.accessToken = expiredAccessToken
        
        let exp = expectation(description: "exp")

        credentials.lookupDirectory(named: existingDirectory) { result in
            XCTAssert(result == .found)
            exp.fulfill()
        }
        
        waitForExpectations(timeout: 10, handler: nil)
    }
}
