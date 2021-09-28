//
//  GeneralTests.swift
//  
//
//  Created by Christopher G Prince on 9/25/21.
//

import XCTest
@testable import SolidResourcesSwift
import SolidAuthSwiftTools
import HeliumLogger
import LoggerAPI

// Run tests (on Linux):
//  swift test --enable-test-discovery

// swift test --enable-test-discovery --filter SolidResourcesSwiftTests.GeneralTests

final class GeneralTests: Common {
    // swift test --enable-test-discovery --filter SolidResourcesSwiftTests.GeneralTests/testLookupBaseDirectory
    func testLookupBaseDirectory() throws {
        try refreshCreds()
        
        let exp = expectation(description: "exp")

        credentials.lookupDirectory(named: nil) { result in
            XCTAssert(result == .found, "\(result)")
            exp.fulfill()
        }
        
        waitForExpectations(timeout: 10, handler: nil)
    }
    
    // swift test --enable-test-discovery --filter SolidResourcesSwiftTests.GeneralTests/testLookupExistingDirectory
    func testLookupExistingDirectory() throws {
        try refreshCreds()
        
        let exp = expectation(description: "exp")

        credentials.lookupDirectory(named: existingDirectory) { result in
            XCTAssert(result == .found)
            exp.fulfill()
        }
        
        waitForExpectations(timeout: 10, handler: nil)
    }
    
    // swift test --enable-test-discovery --filter SolidResourcesSwiftTests.GeneralTests/testLookupNonExistingDirectory
    func testLookupNonExistingDirectory() throws {
        try refreshCreds()
        
        let exp = expectation(description: "exp")

        credentials.lookupDirectory(named: nonExistingDirectory) { result in
            XCTAssert(result == .notFound)
            exp.fulfill()
        }
        
        waitForExpectations(timeout: 10, handler: nil)
    }

#if false
    // Run this just once
    // swift test --enable-test-discovery --filter SolidResourcesSwiftTests.GeneralTests/testSetupExistingDirectoryExistingFile
    func testSetupExistingDirectoryExistingFile() throws {
        try refreshCreds()

        let exp = expectation(description: "exp")
        
        let mimeType = "text/plain"
        let fileName = existingFile
        
        guard let uploadData = "Hello, World!".data(using: .utf8) else {
            XCTFail()
            return
        }

        credentials.uploadFile(named: fileName, inDirectory: existingDirectory, data:uploadData, mimeType: mimeType) { error in
            
            guard error == nil else {
                XCTFail()
                exp.fulfill()
                return
            }
            
            exp.fulfill()
        }
        
        waitForExpectations(timeout: 10, handler: nil)
    }
#endif
    
    // swift test --enable-test-discovery --filter SolidResourcesSwiftTests.GeneralTests/testUploadNewFile_ExistingDirectory
    func testUploadNewFile_ExistingDirectory() throws {
        try refreshCreds()
        
        let exp = expectation(description: "exp")
        
        let mimeType = "text/plain"
        
        let fileName = UUID().uuidString + ".txt"
        
        guard let uploadData = "Hello, World!".data(using: .utf8) else {
            XCTFail()
            return
        }

        credentials.uploadFile(named: fileName, inDirectory: existingDirectory, data:uploadData, mimeType: mimeType) { error in
            
            guard error == nil else {
                XCTFail()
                exp.fulfill()
                return
            }
            
            self.credentials.deleteResource(named: fileName, inDirectory: self.existingDirectory) { error in
                XCTAssert(error == nil)
                exp.fulfill()
            }
        }
        
        waitForExpectations(timeout: 10, handler: nil)
    }

    // swift test --enable-test-discovery --filter SolidResourcesSwiftTests.GeneralTests/testUploadNewFile_NewDirectory
    // Upload a file to a new directory. Make sure to remove that file and the directory afterwards, to cleanup.
    func testUploadNewFile_NewDirectory() throws {
        try refreshCreds()
        
        let exp = expectation(description: "exp")
        
        let mimeType = "text/plain"
        
        let fileName = UUID().uuidString + ".txt"
        
        guard let uploadData = "Hello, World!".data(using: .utf8) else {
            XCTFail()
            return
        }
        
        let newDirectory = UUID().uuidString

        credentials.uploadFile(named: fileName, inDirectory: newDirectory, data:uploadData, mimeType: mimeType) { error in
            
            guard error == nil else {
                XCTFail()
                exp.fulfill()
                return
            }
            
            self.credentials.deleteResource(named: fileName, inDirectory: newDirectory) { error in
                XCTAssert(error == nil)
                
                self.credentials.deleteResource(named: newDirectory, inDirectory: nil) { error in
                    XCTAssert(error == nil)

                    exp.fulfill()
                }
            }
        }
        
        waitForExpectations(timeout: 10, handler: nil)
    }
    
    // swift test --enable-test-discovery --filter SolidResourcesSwiftTests.GeneralTests/testDeleteFile
    /*
    func testDeleteFile() throws {
        solidCreds = try refreshCreds()
        
        let exp = expectation(description: "exp")
        
        solidCreds.deleteResource(named: "567714D1-BEB0-4F1E-A415-0A7285EADF6C.txt", inDirectory: nil) { error in
            XCTAssert(error == nil)
            exp.fulfill()
        }

        waitForExpectations(timeout: 10, handler: nil)
    }
    */
    
    // swift test --enable-test-discovery --filter SolidResourcesSwiftTests.GeneralTests/testLookupExistingFile
    func testLookupExistingFile() throws {
        try refreshCreds()
        
        let exp = expectation(description: "exp")

        credentials.lookupFile(named: existingFile, inDirectory: existingDirectory) { result in
            XCTAssert(result == .found)
            exp.fulfill()
        }
        
        waitForExpectations(timeout: 10, handler: nil)
    }
    
    // swift test --enable-test-discovery --filter SolidResourcesSwiftTests.GeneralTests/testLookupNonExistingFile
    func testLookupNonExistingFile() throws {
        try refreshCreds()
        
        let exp = expectation(description: "exp")

        credentials.lookupFile(named: "FooblyWoobly.txt", inDirectory: existingDirectory) { result in
            XCTAssert(result == .notFound)
            exp.fulfill()
        }
        
        waitForExpectations(timeout: 10, handler: nil)
    }
    
    // swift test --enable-test-discovery --filter SolidResourcesSwiftTests.GeneralTests/testDownloadNonExistentFile
    func testDownloadNonExistentFile() throws {
        try refreshCreds()
        
        let exp = expectation(description: "exp")

        credentials.downloadFile(named: "FooblyBloobly.txt", inDirectory: existingDirectory) { result in
            switch result {
            case .success:
                XCTFail()
    
            case .fileNotFound:
                break

            case .failure:
                XCTFail()
            }
            
            exp.fulfill()
        }
        
        waitForExpectations(timeout: 10, handler: nil)
    }
}
