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
import CloudSDK
import Foundation
import Models
import SharedUtils

let runtime = LambdaRuntime { (event: SQSEvent, context: LambdaContext) async throws -> Bool in
    context.logger.info("Received SQS event: \(event)")

    let apiHost = "ncaa-api.henrygd.me"
    let footballScoresUrl = "https://\(apiHost)/scoreboard/football/fbs"
    let mensBasketballScoresUrl = "https://\(apiHost)/scoreboard/basketball-men/d1"
    let womensBasketballScoresUrl = "https://\(apiHost)/scoreboard/basketball-women/d1"

    guard isFootballSeason || isBasketballSeason else {
        context.logger.info("Not currently football or basketball season, exiting")
        return false
    }

    if isFootballSeason {
        context.logger.info("Checking football scores...")
        let footballScores = try await getScores(url: footballScoresUrl, sport: .cfb, context: context)
        if let scores = footballScores {
            if let tulsaFootballGame = getTulsaGameFromAPI(scores: scores) {
                context.logger.info("Found Tulsa football game: \(tulsaFootballGame.title)")
                try await writeGameStatusToDynamoDB(tulsaGame: tulsaFootballGame, sport: .cfb, context: context)
            } else {
                context.logger.info("Tulsa FB is not playing right now")
            }
        }
    }

    if isBasketballSeason {
        context.logger.info("Checking basketball scores...")
        if let mensBasketballScores = try await getScores(url: mensBasketballScoresUrl, sport: .mbb, context: context) {
            if let tulsaMbbGame = getTulsaGameFromAPI(scores: mensBasketballScores) {
                context.logger.info("Found Tulsa men's basketball game: \(tulsaMbbGame.title)")
                try await writeGameStatusToDynamoDB(tulsaGame: tulsaMbbGame, sport: .mbb, context: context)
            } else {
                context.logger.info("Tulsa MBB is not playing right now")
            }
        }

        if let womensBasketballScores = try await getScores(url: womensBasketballScoresUrl, sport: .wbb, context: context) {
            if let tulsaWbbGame = getTulsaGameFromAPI(scores: womensBasketballScores) {
                context.logger.info("Found Tulsa women's basketball game: \(tulsaWbbGame.title)")
                try await writeGameStatusToDynamoDB(tulsaGame: tulsaWbbGame, sport: .wbb, context: context)
            } else {
                context.logger.info("Tulsa WBB is not playing right now")
            }
        }
    }

    return true
}

try await runtime.run()


// MARK: Poller Utilities

private func getScores(url: String, sport: Sport, context: LambdaContext) async throws -> GameScoresResponse? {
    let httpClient = HTTPClient(eventLoopGroupProvider: .singleton)
    defer {
        _ = httpClient.shutdown()
    }

    var request = HTTPClientRequest(url: url)
    request.method = .GET
    request.headers.add(name: "Accept", value: "application/json")

    do {
        context.logger.info("Making GET request to \(url)")
        let response = try await HTTPClient.shared.execute(request, timeout: .seconds(30))

        guard response.status == .ok else {
            context.logger.error("HTTP request failed with status: \(response.status)")
            return nil
        }

        let body = try await response.body.collect(upTo: 10 * 1024 * 1024) // 10 MB

        // Convert ByteBuffer to Data using readableBytesView
        let data = Data(body.readableBytesView)

        let decoder = JSONDecoder()
        context.logger.info("Decoding data into GameScoresResponse")
        let scores = try decoder.decode(GameScoresResponse.self, from: data)

        context.logger.info("Received scores for \(scores.games.count) \(sport) games")
        return scores
    } catch {
        context.logger.error("Request failed: \(error)")
        return nil
    }
}

private func getTulsaGameFromAPI(scores: GameScoresResponse) -> Game? {
    return scores.games.first(where: { $0.game.title.contains("Tulsa") })?.game
}

private func writeGameStatusToDynamoDB(tulsaGame: Game, sport: Sport, context: LambdaContext) async throws {
    let scoresTableName = Cloud.env("DYNAMODB_SCORES_NAME")
    let ddbConfig = try await DynamoDBClient.DynamoDBClientConfiguration(
        region: "us-east-1"
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
        sport: sport.rawValue,
        tulsaScore: Int(tulsaScore) ?? 0,
        opposingScore: Int(opposingScore) ?? 0,
        opposingTeam: opposingTeam,
        gamePeriod: tulsaGame.currentPeriod
    )
    context.logger.info("GameItem created as \(gameItem)")

    let dynamoItem: [String: DynamoDBClientTypes.AttributeValue] = [
        "gameId": .s(gameItem.gameId),
        "sport": .s(gameItem.sport),
        "tulsaScore": .n(String(gameItem.tulsaScore)),
        "opposingScore": .n(String(gameItem.opposingScore)),
        "opposingTeam": .s(gameItem.opposingTeam),
        "gamePeriod": .s(gameItem.gamePeriod)
    ]
    context.logger.info("DynamoItem created as \(dynamoItem)")

    let ddbInput = PutItemInput(
        item: dynamoItem,
        tableName: scoresTableName
    )

    do {
        _ = try await ddbClient.putItem(input: ddbInput)
        context.logger.info("Successfully wrote game info to DynamoDB")
    } catch {
        context.logger.error("Error writing game info to DynamoDB: \(error)")
    }
}

enum Sport: String {
    case cfb = "cfb"
    case mbb = "mbb"
    case wbb = "wbb"
}
