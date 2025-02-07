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

    let ncaaApiHost = "ncaa-api.henrygd.me" // from https://github.com/henrygd/ncaa-api
    let nflScoresUrl = "http://site.api.espn.com/apis/site/v2/sports/football/nfl/scoreboard"
    let ncaaFootballScoresUrl = "https://\(ncaaApiHost)/scoreboard/football/fbs"
    let mensBasketballScoresUrl = "https://\(ncaaApiHost)/scoreboard/basketball-men/d1"
    let womensBasketballScoresUrl = "https://\(ncaaApiHost)/scoreboard/basketball-women/d1"

    guard isFootballSeason || isBasketballSeason else {
        context.logger.info("Not currently football or basketball season, exiting")
        return false
    }

    if isFootballSeason {
        // Check active NCAA and NFL scores for Tulsa and/or Eagles football games
        try await withThrowingTaskGroup(of: Void.self) { group in
            group.addTask {
                context.logger.info("Checking ncaa football scores...")
                let ncaaFootballScores = try await getNCAAScores(url: ncaaFootballScoresUrl, sport: .cfb, context: context)
                if let ncaaFootballScores {
                    if let tulsaFootballGame = getTulsaGameFromAPI(ncaaScores: ncaaFootballScores) {
                        context.logger.info("Found Tulsa football game: \(tulsaFootballGame.title)")
                        try await writeNCAAGameStatusToDynamoDB(tulsaGame: tulsaFootballGame, sport: .cfb, context: context)
                    } else {
                        context.logger.info("Tulsa FB is not playing right now")
                    }
                }
            }

            group.addTask {
                context.logger.info("Checking nfl football scores...")
                let nflScores = try await getNFLScores(url: nflScoresUrl, context: context)
                if let nflScores {
                    if let eaglesGame: Event = getEaglesGameFromAPI(nflScores: nflScores) {
                        context.logger.info("Found Eagles game: \(eaglesGame.shortName)")
                        try await writeNFLGameStatusToDynamoDB(eaglesGame: eaglesGame, context: context)
                    } else {
                        context.logger.info("The Eagles are not playing right now")
                    }
                }
            }

            try await group.waitForAll()
        }
    }

    if isBasketballSeason {
        // Check active NCAA scores for Tulsa men's & women's basketball games
        try await withThrowingTaskGroup(of: Void.self) { group in
            group.addTask {
                context.logger.info("Checking basketball scores...")
                if let mensBasketballScores = try await getNCAAScores(url: mensBasketballScoresUrl, sport: .mbb, context: context) {
                    if let tulsaMbbGame = getTulsaGameFromAPI(ncaaScores: mensBasketballScores) {
                        context.logger.info("Found Tulsa men's basketball game: \(tulsaMbbGame.title)")
                        try await writeNCAAGameStatusToDynamoDB(tulsaGame: tulsaMbbGame, sport: .mbb, context: context)
                    } else {
                        context.logger.info("Tulsa MBB is not playing right now")
                    }
                }
            }

            group.addTask {
                if let womensBasketballScores = try await getNCAAScores(url: womensBasketballScoresUrl, sport: .wbb, context: context) {
                    if let tulsaWbbGame = getTulsaGameFromAPI(ncaaScores: womensBasketballScores) {
                        context.logger.info("Found Tulsa women's basketball game: \(tulsaWbbGame.title)")
                        try await writeNCAAGameStatusToDynamoDB(tulsaGame: tulsaWbbGame, sport: .wbb, context: context)
                    } else {
                        context.logger.info("Tulsa WBB is not playing right now")
                    }
                }
            }

            try await group.waitForAll()
        }
    }

    return true
}

try await runtime.run()


// MARK: Poller Utilities

private func getNCAAScores(url: String, sport: Sport, context: LambdaContext) async throws -> NCAAGameScoresResponse? {
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
        context.logger.info("Decoding data into NCAAGameScoresResponse")
        let scores = try decoder.decode(NCAAGameScoresResponse.self, from: data)

        context.logger.info("Received scores for \(scores.games.count) \(sport) games")
        return scores
    } catch {
        context.logger.error("Request failed: \(error)")
        return nil
    }
}

private func getTulsaGameFromAPI(ncaaScores: NCAAGameScoresResponse) -> Game? {
    return ncaaScores.games.first(where: { $0.game.title.contains("Tulsa") })?.game
}

private func getNFLScores(url: String, context: LambdaContext) async throws -> NFLGameScoresResponse? {
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
        context.logger.info("Decoding data into NFLGameScoresResponse")
        let scores = try decoder.decode(NFLGameScoresResponse.self, from: data)

        context.logger.info("Received scores for \(scores.events.count) nfl games")
        return scores
    } catch {
        context.logger.error("Request failed: \(error)")
        return nil
    }
}

private func getEaglesGameFromAPI(nflScores: NFLGameScoresResponse) -> Event? {
    return nflScores.events.first(where: { $0.name.contains("Eagles") })
}

private func writeNCAAGameStatusToDynamoDB(tulsaGame: Game, sport: Sport, context: LambdaContext) async throws {
    let scoresTableName = Cloud.env("DYNAMODB_SCORES_NAME")
    let ddbConfig = try await DynamoDBClient.DynamoDBClientConfiguration(
        region: "us-east-1"
    )
    let ddbClient = DynamoDBClient(config: ddbConfig)

    let homeTeam = tulsaGame.home.names.short

    var tulsaScore = "0"
    var opposingTeamScore = "0"
    var opposingTeam = ""
    if homeTeam == "Tulsa" {
        tulsaScore = tulsaGame.home.score
        opposingTeamScore = tulsaGame.away.score
        opposingTeam = tulsaGame.away.names.short
    } else {
        tulsaScore = tulsaGame.away.score
        opposingTeamScore = tulsaGame.home.score
        opposingTeam = tulsaGame.home.names.short
    }

    let gameItem = GameItem(
        gameId: tulsaGame.gameID,
        sport: sport.rawValue,
        myTeam: "Tulsa",
        myTeamScore: Int(tulsaScore) ?? 0,
        opposingTeam: opposingTeam,
        opposingTeamScore: Int(opposingTeamScore) ?? 0,
        gamePeriod: tulsaGame.currentPeriod
    )
    context.logger.info("NCAA GameItem created as \(gameItem)")

    let dynamoItem: [String: DynamoDBClientTypes.AttributeValue] = [
        "gameId": .s(gameItem.gameId),
        "sport": .s(gameItem.sport),
        "myTeam": .s(gameItem.myTeam),
        "myTeamScore": .n(String(gameItem.myTeamScore)),
        "opposingTeam": .s(gameItem.opposingTeam),
        "opposingTeamScore": .n(String(gameItem.opposingTeamScore)),
        "gamePeriod": .s(gameItem.gamePeriod)
    ]
    context.logger.info("NCAA DynamoItem created as \(dynamoItem)")

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

private func writeNFLGameStatusToDynamoDB(eaglesGame: Event, context: LambdaContext) async throws {
    let scoresTableName = Cloud.env("DYNAMODB_SCORES_NAME")
    let ddbConfig = try await DynamoDBClient.DynamoDBClientConfiguration(
        region: "us-east-1"
    )
    let ddbClient = DynamoDBClient(config: ddbConfig)

    let competition = eaglesGame.competitions.first
    let homeCompetitor = competition?.competitors.first(where: { $0.homeAway == "home" })
    let awayCompetitor = competition?.competitors.first(where: { $0.homeAway == "away" })

    var eaglesScore = "0"
    var opposingTeamScore = "0"
    var opposingTeam = ""

    if homeCompetitor?.team.name == "Eagles" {
        eaglesScore = homeCompetitor?.score ?? "0"
        opposingTeamScore = awayCompetitor?.score ?? "0"
        opposingTeam = awayCompetitor?.team.name ?? ""
    } else {
        eaglesScore = awayCompetitor?.score ?? "0"
        opposingTeamScore = homeCompetitor?.score ?? "0"
        opposingTeam = homeCompetitor?.team.name ?? ""
    }

    let gameItem = GameItem(
        gameId: eaglesGame.id,
        sport: "nfl",
        myTeam: "Eagles",
        myTeamScore: Int(eaglesScore) ?? 0,
        opposingTeam: opposingTeam,
        opposingTeamScore: Int(opposingTeamScore) ?? 0,
        gamePeriod: competition?.status.type.name ?? ""
    )
    context.logger.info("NFL GameItem created as \(gameItem)")

    let dynamoItem: [String: DynamoDBClientTypes.AttributeValue] = [
        "gameId": .s(gameItem.gameId),
        "sport": .s(gameItem.sport),
        "myTeam": .s(gameItem.myTeam),
        "myTeamScore": .n(String(gameItem.myTeamScore)),
        "opposingTeam": .s(gameItem.opposingTeam),
        "opposingTeamScore": .n(String(gameItem.opposingTeamScore)),
        "gamePeriod": .s(gameItem.gamePeriod)
    ]
    context.logger.info("NFL DynamoItem created as \(dynamoItem)")

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
    case nfl = "nfl"
}
