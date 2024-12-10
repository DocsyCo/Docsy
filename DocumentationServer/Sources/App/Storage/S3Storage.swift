//
//  File.swift
//  DocumentationServer
//
//  Created by Noah Kamara on 08.12.24.
//

import Foundation
import AWSClientRuntime
import AWSS3
import AWSSDKIdentity

//init(from environment: Hummingbird.Environment)
struct S3StorageRepository {}


public protocol StorageRepository {
//    func sign(url: URL)
}


struct StorageController {
    let repository: StorageRepository
}


struct S3Storage {
    struct Configuration {
        let endpoint: String
        let region: String
        let accessKey: String
        let secretKey: String
        
        static let localDevelopment = Configuration(
            endpoint: "http://localhost:9000",
            region: "us-east-1",
            accessKey: "EWJTeVeyeVSPIZ9dpEXq",
            secretKey: "rJ5zRZvfAyCNhDqkpCrTuD5zVrBCtk2l4zoNMG9r"
        )
    }
    
    func create(config: Configuration = .localDevelopment) async throws {
        let identityResolver = try StaticAWSCredentialIdentityResolver(.init(
            accessKey: config.accessKey,
            secret: config.secretKey
        ))
        
        
        let clientConfig = try await S3Client.S3ClientConfiguration.init(
            awsCredentialIdentityResolver: identityResolver,
            region: config.region,
            endpoint: config.endpoint
        )
        
        print("HI")
        
        
        // Initialize the S3 client
        let client = S3Client(config: clientConfig)
        let buckets = try await client.listBuckets(input: .init())
        print(buckets)
    }
}
