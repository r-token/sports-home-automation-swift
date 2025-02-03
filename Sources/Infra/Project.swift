//
//  Project.swift
//  sports-home-automation-swift
//
//  Created by Ryan Token on 2/2/25.
//

import Cloud

@main
struct SportsHomeAutomationSwift: AWSProject {
    func build() async throws -> Outputs {
        let cron = AWS.Cron(
            "ncaa-api-cron-job",
            schedule: .rate(.minutes(1)) // EventBridge cannot do seconds
        )

        let ncaaApiPoller = AWS.Function(
            "ncaa-api-poller-function",
            targetName: "Poller"
        )

        let scoresTable = AWS.DynamoDB(
            "Scores",
            primaryIndex: .init(
                partitionKey: ("gameId", .string)
            ),
            streaming: .enabled(viewType: .newImage)
        )

        let scoreProcessor = AWS.Function(
            "score-processor",
            targetName: "ScoreProcessor"
        )

        cron.invoke(ncaaApiPoller) // cron job triggers API poller Lambda
        ncaaApiPoller.link(scoresTable) // API poller Lambda has write permissions on the 'Scores' DynamoDB table
        scoresTable.subscribe(scoreProcessor) // 'Scores' DynamoDB table streams NEW_IMAGE change events to scoreProcessor Lambda

        return Outputs([
            "cron-job-name": cron.name,
            "ncaa-poller-function-name": ncaaApiPoller.name,
            "scores-table-name": scoresTable.name,
            "score-processor-function-name": scoreProcessor.name
        ])
    }
}
