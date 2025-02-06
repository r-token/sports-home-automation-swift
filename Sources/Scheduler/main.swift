//
//  main.swift
//  sports-home-automation-swift
//
//  Created by Ryan Token on 2/5/25.
//

import AWSLambdaRuntime
import AWSLambdaEvents
import AWSSQS
import CloudSDK
import Foundation
import SharedUtils

struct SportsApiCronJob: CloudwatchDetail {
    static let name = "sports-api-cron-job"
}

let runtime = LambdaRuntime { (event: SportsApiCronJob, context: LambdaContext) async throws -> Bool in
    context.logger.info("Received cron event: \(event)")

    guard isFootballSeason || isBasketballSeason else {
        context.logger.info("Not currently football or basketball season, exiting")
        return false
    }

    let queueUrl = Cloud.env("QUEUE_SPORTS_API_POLLER_QUEUE_URL")
    let config = try await SQSClient.SQSClientConfiguration(region: "us-east-1")
    let sqsClient = SQSClient(config: config)

    for i in 0..<6 {
        let input = SendMessageInput(
            delaySeconds: i*10,
            messageBody: "Check sports scores",
            queueUrl: queueUrl
        )

        do {
            let response = try await sqsClient.sendMessage(input: input)
            context.logger.info("Sent message with delay of \(i * 10) seconds: \(response)")
        } catch {
            context.logger.error("Failed to send message: \(error)")
            return false
        }
    }

    return true
}

try await runtime.run()
