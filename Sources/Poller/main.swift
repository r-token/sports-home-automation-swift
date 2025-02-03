//
//  main.swift
//  sports-home-automation-swift
//
//  Created by Ryan Token on 2/2/25.
//

import AsyncHTTPClient
import AWSDynamoDB
import AWSLambdaRuntime
import AWSLambdaEvents
import Foundation
import Models

struct NcaaApiCronJob: CloudwatchDetail {
    static let name = "ncaa-api-cron-job"
}

let runtime = LambdaRuntime { (event: EventBridgeEvent<NcaaApiCronJob>, context: LambdaContext) -> Bool in
    context.logger.info("Received cron event: \(event)")

    let apiHost = "ncaa-api.henrygd.me"
    let footballScoresUrl = "https://\(apiHost)/scoreboard/football/fbs"
    let mensBasketballScoresUrl = "https://\(apiHost)/scoreboard/basketball-men/d1"
    let womensBasketballScoresUrl = "https://\(apiHost)/scoreboard/basketball-women/d1"

    let isFootballSeason = (8...12).contains(Date().month) || (Date().month == 1 && Date().day <= 30)
    let isBasketballSeason = (10...12).contains(Date().month) || (1...4).contains(Date().month) && !(Date().month == 4 && Date().day > 15)

    guard isFootballSeason || isBasketballSeason else { return false }

    if isFootballSeason {
        guard let footballScores = try await getScores(url: footballScoresUrl, context: context) else { return false }
        if let tulsaFootballGame = getTulsaGameFromAPI(scores: footballScores) {
            context.logger.info("There is a Tulsa football game happening now; writing latest results to DynamoDB")
            try await writeGameStatusToDynamoDB(tulsaGame: tulsaFootballGame, sport: "cfb", context: context)
        } else {
            context.logger.info("No Tulsa football game happening now, returning")
        }
    } else if isBasketballSeason {
        guard let mensBasketballScores = try await getScores(url: mensBasketballScoresUrl, context: context) else { return false }
        guard let womensBasketballScores = try await getScores(url: womensBasketballScoresUrl, context: context) else { return false }

        if let tulsaMbbGame = getTulsaGameFromAPI(scores: mensBasketballScores) {
            context.logger.info("There is a Tulsa men's basketball game happening now; writing latest results to DynamoDB")
            try await writeGameStatusToDynamoDB(tulsaGame: tulsaMbbGame, sport: "mbb", context: context)
        } else {
            context.logger.info("No Tulsa men's basketball game happening now, returning")
        }

        if let tulsaWbbGame = getTulsaGameFromAPI(scores: womensBasketballScores) {
            context.logger.info("There is a Tulsa women's basketball game happening now; writing latest results to DynamoDB")
            try await writeGameStatusToDynamoDB(tulsaGame: tulsaWbbGame, sport: "wbb", context: context)
        } else {
            context.logger.info("No Tulsa women's basketball game happening now, returning")
        }
    }

    return true
}

try await runtime.run()


// MARK: Poller Utilities

private func getScores(url: String, context: LambdaContext) async throws -> GameScoresResponse? {
    let httpClient = HTTPClient(eventLoopGroupProvider: .singleton)
    defer {
        _ = httpClient.shutdown()
    }

    var request = HTTPClientRequest(url: url)
    request.method = .GET
    request.headers.add(name: "Accept", value: "application/json")

    do {
        let response = try await HTTPClient.shared.execute(request, timeout: .seconds(30))

        guard response.status == .ok else {
            context.logger.error("HTTP request failed with status: \(response.status)")
            return nil
        }

        let body = try await response.body.collect(upTo: 10 * 1024 * 1024) // 10 MB

        // Convert ByteBuffer to Data using readableBytesView
        let data = Data(body.readableBytesView)

        let decoder = JSONDecoder()
        let scores = try decoder.decode(GameScoresResponse.self, from: data)

        context.logger.info("Received scores for \(scores.games.count) games")
        return scores
    } catch {
        context.logger.error("Request failed: \(error)")
        return nil
    }
}

private func getTulsaGameFromAPI(scores: GameScoresResponse) -> Game? {
    return scores.games.first(where: { $0.title.contains("Tulsa") })
}

private func writeGameStatusToDynamoDB(tulsaGame: Game, sport: String, context: LambdaContext) async throws {
    let ddbConfig = try await DynamoDBClient.DynamoDBClientConfiguration(
        region: "us-east-1"  // replace with your region
    )
    let ddbClient = DynamoDBClient(config: ddbConfig)

    let homeTeam = tulsaGame.home.names.short

    var tulsaScore = "0"
    var opposingScore = "0"
    var opposingTeam = ""
    if homeTeam == "Tulsa" {
        tulsaScore = tulsaGame.home.score
        opposingScore = tulsaGame.away.score
        opposingTeam = tulsaGame.away.names.short
    } else {
        tulsaScore = tulsaGame.away.score
        opposingScore = tulsaGame.home.score
        opposingTeam = tulsaGame.home.names.short
    }

    let gameItem = GameItem(
        gameId: tulsaGame.gameID,
        sport: sport,
        tulsaScore: tulsaScore,
        opposingScore: opposingScore,
        opposingTeam: opposingTeam,
        gamePeriod: tulsaGame.currentPeriod
    )
    context.logger.info("GameItem created as \(gameItem)")

    let dynamoItem: [String: DynamoDBClientTypes.AttributeValue] = [
        "gameId": .s(gameItem.gameId),
        "sport": .s(gameItem.sport),
        "tulsaScore": .n(gameItem.tulsaScore),
        "opposingScore": .n(gameItem.opposingScore),
        "opposingTeam": .s(gameItem.opposingTeam),
        "gamePeriod": .s(gameItem.gamePeriod)
    ]
    context.logger.info("DynamoItem created as \(dynamoItem)")

    let ddbInput = PutItemInput(
        item: dynamoItem,
        tableName: "Scores"
    )

    do {
        _ = try await ddbClient.putItem(input: ddbInput)
        context.logger.info("Successfully wrote game info to DynamoDB")
    } catch {
        context.logger.error("Error writing game info to DynamoDB: \(error)")
    }
}
