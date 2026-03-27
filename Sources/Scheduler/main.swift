//
//  main.swift
//  sports-home-automation-swift
//
//  Created by Ryan Token on 2/5/25.
//

import AWSLambdaRuntime
import AWSLambdaEvents
import CloudSDK
import Foundation
import SharedUtils
import SotoSQS

struct SportsApiCronJob: CloudwatchDetail {
    static let name = "sports-api-cron-job"
}

let client = AWSClient()
let sqs = SQS(client: client, region: .useast1)

let runtime = LambdaRuntime { (event: SportsApiCronJob, context: LambdaContext) async throws -> Bool in
    context.logger.info("Received cron event: \(event)")

    guard isFootballSeason || isBasketballSeason else {
        context.logger.info("Not currently football or basketball season, exiting")
        return false
    }

    guard let queueUrl = Cloud.env("QUEUE_SPORTS_API_POLLER_QUEUE_URL") else {
        context.logger.error("QUEUE_SPORTS_API_POLLER_QUEUE_URL environment variable not set")
        return false
    }

    for i in 0..<6 {
        let input = SQS.SendMessageRequest(
            delaySeconds: i*10,
            messageBody: "Check sports scores",
            queueUrl: queueUrl
        )

        do {
            let response = try await sqs.sendMessage(input)
            context.logger.info("Sent message with delay of \(i * 10) seconds: \(response)")
        } catch {
            context.logger.error("Failed to send message: \(error)")
            return false
        }
    }

    return true
}

try await runtime.run()
try await client.shutdown()
