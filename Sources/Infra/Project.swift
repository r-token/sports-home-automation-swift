//
//  Project.swift
//  sports-home-automation-swift
//
//  Created by Ryan Token on 2/2/25.
//

import Cloud

// EventBridge cannot do seconds, so we have EventBridge do every minute
// That EventBridge schedule triggers a scheduler function that fires off 6 SQS messages, one for every 10 seconds (via the delaySeconds SQS input option)
// Those SQS events trigger the API poller every 10 seconds, which writes relevant games to DynamoDB
// Those DynamoDB writes get streamed to the processor Lambda which can control my lights if the relevant team wins
@main
struct SportsHomeAutomationSwift: AWSProject {
    func build() async throws -> Outputs {
        let cron = AWS.Cron(
            "sports-api-cron-job",
            schedule: .rate(.minutes(1))
        )

        let sportsApiScheduler = AWS.Function(
            "sports-api-scheduler",
            targetName: "Scheduler"
        )

        let sportsApiPollerQueue = AWS.Queue("sports-api-poller-queue")

        let sportsApiPoller = AWS.Function(
            "sports-api-poller-function",
            targetName: "Poller"
        )

        let scoresTable = AWS.DynamoDB(
            "Scores",
            primaryIndex: .init(
                partitionKey: ("gameId", .string)
            ),
            streaming: .enabled(viewType: .newAndOldImages)
        )

        let scoreProcessor = AWS.Function(
            "score-processor",
            targetName: "ScoreProcessor"
        )

        cron.invoke(sportsApiScheduler) // cron job triggers the scheduler Lambda
        sportsApiScheduler.link(sportsApiPollerQueue) // scheduler Lambda has write permissions to the poller SQS queue
        sportsApiPollerQueue.subscribe(sportsApiPoller) // API poller is invoked by SQS events
        sportsApiPoller.link(scoresTable) // API poller Lambda has write permissions on the 'Scores' DynamoDB table
        scoresTable.subscribe(scoreProcessor) // 'Scores' DynamoDB table streams NEW_AND_OLD_IMAGES change events to scoreProcessor Lambda

        // getParameter permissions for hue-remote-username & hue-access-token
        scoreProcessor.link(
            Link(
                name: "hue-remote-username-permissions-link",
                effect: "Allow",
                actions: ["ssm:GetParameter"],
                resources: [
                    "arn:aws:ssm:us-east-1:725350831613:parameter/hue-remote-username",
                    "arn:aws:ssm:us-east-1:725350831613:parameter/hue-access-token"
                ],
                properties: nil
            )
        )

        return Outputs([
            "cron-job-name": cron.name,
            "sports-poller-function-name": sportsApiPoller.name,
            "scores-table-name": scoresTable.name,
            "score-processor-function-name": scoreProcessor.name
        ])
    }
}
