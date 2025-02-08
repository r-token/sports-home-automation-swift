//
//  main.swift
//  sports-home-automation-swift
//
//  Created by Ryan Token on 2/2/25.
//

import AsyncHTTPClient
import AWSDynamoDB
import AWSLambdaEvents
import AWSLambdaRuntime
import Foundation
import Models
import NIOCore
import SSMUtils

let runtime = LambdaRuntime { (event: DynamoDBEvent, context: LambdaContext) async throws -> Bool in
    context.logger.info("Received DynamoDB event: \(event)")

    for event in event.records {
        guard let gameInfo: GameInfo = parseDynamoEventIntoGameItem(event: event, context: context) else { continue }

        if isFootballGame(game: gameInfo.currentGame) {
            if myTeamScored(gameInfo) {
                try await flashLightsAppropriateColors(gameInfo: gameInfo, context: context)
            }
        }

        if myTeamWon(gameInfo) {
            try await flashLightsAppropriateColors(gameInfo: gameInfo, context: context)
        }
    }

    return true
}

try await runtime.run()


// MARK: ScoreProcessor Utilities

private func isFootballGame(game: GameItem) -> Bool {
    game.sport == "cfb" || game.sport == "nfl"
}

private func parseDynamoEventIntoGameItem(event: DynamoDBEvent.EventRecord, context: LambdaContext) -> GameInfo? {
    guard let oldImage = event.change.oldImage else {
        context.logger.info("No old image in record, skipping")
        return nil
    }
    guard let newImage = event.change.newImage else {
        context.logger.info("No new image in record, skipping")
        return nil
    }

    guard case .string(let gameId) = newImage["gameId"],
          case .string(let sport) = newImage["sport"],
          case .string(let myTeam) = newImage["myTeam"],
          case .number(let myTeamScore) = newImage["myTeamScore"],
          case .number(let previousMyTeamScore) = oldImage["myTeamScore"],
          case .string(let opposingTeam) = newImage["opposingTeam"],
          case .number(let opposingTeamScore) = newImage["opposingTeamScore"],
          case .string(let previousGamePeriod) = oldImage["gamePeriod"],
          case .string(let gamePeriod) = newImage["gamePeriod"] else {
        context.logger.error("Missing or invalid attributes in DynamoDB record")
        return nil
    }

    let gameItem = GameItem(
        gameId: gameId,
        sport: sport,
        myTeam: myTeam,
        myTeamScore: Int(myTeamScore) ?? 0,
        opposingTeam: opposingTeam,
        opposingTeamScore: Int(opposingTeamScore) ?? 0,
        gamePeriod: gamePeriod
    )

    context.logger.info("Processed gameItem: \(gameItem), previousGamePeriod as: \(previousGamePeriod), and previousMyTeamScore as: \(Int(previousMyTeamScore) ?? 0)")
    return GameInfo(
        currentGame: gameItem,
        previousGamePeriod: previousGamePeriod,
        previousMyTeamScore: Int(previousMyTeamScore) ?? 0
    )
}

private func myTeamScored(_ gameInfo: GameInfo) -> Bool {
    let oldMyTeamScore = gameInfo.previousMyTeamScore
    let newMyTeamScore = gameInfo.currentGame.myTeamScore

    return newMyTeamScore > oldMyTeamScore
}

private func myTeamWon(_ gameInfo: GameInfo) -> Bool {
    let myTeamScore = gameInfo.currentGame.myTeamScore
    let opposingTeamScore = gameInfo.currentGame.opposingTeamScore
    let previousGamePeriod = gameInfo.previousGamePeriod
    let currentGamePeriod = gameInfo.currentGame.gamePeriod

    let gameJustEnded = !previousGamePeriod.contains("FINAL") && currentGamePeriod.contains("FINAL")

    return gameJustEnded && myTeamScore > opposingTeamScore
}

private func flashLightsAppropriateColors(gameInfo: GameInfo, context: LambdaContext) async throws {
    switch gameInfo.currentGame.myTeam {
    case "Tulsa":
        context.logger.info("Tulsa won! Flashing lights Tulsa colors...")
        try await flashLightsTulsaColors(context: context)
    case "Eagles":
        context.logger.info("Eagles won! Flashing lights Eagles colors...")
        try await flashLightsEaglesColors(context: context)
    default:
        context.logger.info("Some other team won? Flashing lights Tulsa colors...")
        try await flashLightsTulsaColors(context: context)
    }
}

private func flashLightsTulsaColors(context: LambdaContext) async throws {
    guard let hueRemoteUsername = try await getSSMParameterValue(parameterName: "hue-remote-username", context: context) else { return }
    guard let hueAccessToken = try await getSSMParameterValue(parameterName: "hue-access-token", context: context) else { return }

    try await turnLights(.gold, hueUsername: hueRemoteUsername, hueAccessToken: hueAccessToken, context: context)
    try await Task.sleep(for: .seconds(0.5))

    try await turnLights(.blue, hueUsername: hueRemoteUsername, hueAccessToken: hueAccessToken, context: context)
    try await Task.sleep(for: .seconds(0.5))

    try await turnLights(.red, hueUsername: hueRemoteUsername, hueAccessToken: hueAccessToken, context: context)
    try await Task.sleep(for: .seconds(0.5))

    try await turnLights(.gold, hueUsername: hueRemoteUsername, hueAccessToken: hueAccessToken, context: context)
    try await Task.sleep(for: .seconds(0.5))

    try await turnLights(.blue, hueUsername: hueRemoteUsername, hueAccessToken: hueAccessToken, context: context)
    try await Task.sleep(for: .seconds(0.5))

    try await turnLights(.red, hueUsername: hueRemoteUsername, hueAccessToken: hueAccessToken, context: context)
    try await Task.sleep(for: .seconds(0.5))

    try await turnLights(.gold, hueUsername: hueRemoteUsername, hueAccessToken: hueAccessToken, context: context)
    try await Task.sleep(for: .seconds(0.5))

    try await turnLights(.blue, hueUsername: hueRemoteUsername, hueAccessToken: hueAccessToken, context: context)
    try await Task.sleep(for: .seconds(0.5))

    try await turnLights(.red, hueUsername: hueRemoteUsername, hueAccessToken: hueAccessToken, context: context)
    try await Task.sleep(for: .seconds(0.5))

    try await turnLights(.gold, hueUsername: hueRemoteUsername, hueAccessToken: hueAccessToken, context: context)
    try await Task.sleep(for: .seconds(0.5))

    try await turnLights(.blue, hueUsername: hueRemoteUsername, hueAccessToken: hueAccessToken, context: context)
    try await Task.sleep(for: .seconds(0.5))

    try await turnLights(.red, hueUsername: hueRemoteUsername, hueAccessToken: hueAccessToken, context: context)
    try await Task.sleep(for: .seconds(0.5))

    try await turnLights(.gold, hueUsername: hueRemoteUsername, hueAccessToken: hueAccessToken, context: context)
    try await Task.sleep(for: .seconds(0.5))
}

private func flashLightsEaglesColors(context: LambdaContext) async throws {
    guard let hueRemoteUsername = try await getSSMParameterValue(parameterName: "hue-remote-username", context: context) else { return }
    guard let hueAccessToken = try await getSSMParameterValue(parameterName: "hue-access-token", context: context) else { return }

    try await turnLights(.midnightGreen, hueUsername: hueRemoteUsername, hueAccessToken: hueAccessToken, context: context)
    try await Task.sleep(for: .seconds(0.5))

    try await turnLights(.silver, hueUsername: hueRemoteUsername, hueAccessToken: hueAccessToken, context: context)
    try await Task.sleep(for: .seconds(0.5))

    try await turnLights(.midnightGreen, hueUsername: hueRemoteUsername, hueAccessToken: hueAccessToken, context: context)
    try await Task.sleep(for: .seconds(0.5))

    try await turnLights(.silver, hueUsername: hueRemoteUsername, hueAccessToken: hueAccessToken, context: context)
    try await Task.sleep(for: .seconds(0.5))

    try await turnLights(.midnightGreen, hueUsername: hueRemoteUsername, hueAccessToken: hueAccessToken, context: context)
    try await Task.sleep(for: .seconds(0.5))

    try await turnLights(.silver, hueUsername: hueRemoteUsername, hueAccessToken: hueAccessToken, context: context)
    try await Task.sleep(for: .seconds(0.5))

    try await turnLights(.midnightGreen, hueUsername: hueRemoteUsername, hueAccessToken: hueAccessToken, context: context)
    try await Task.sleep(for: .seconds(0.5))

    try await turnLights(.silver, hueUsername: hueRemoteUsername, hueAccessToken: hueAccessToken, context: context)
    try await Task.sleep(for: .seconds(0.5))

    try await turnLights(.midnightGreen, hueUsername: hueRemoteUsername, hueAccessToken: hueAccessToken, context: context)
    try await Task.sleep(for: .seconds(0.5))

    try await turnLights(.silver, hueUsername: hueRemoteUsername, hueAccessToken: hueAccessToken, context: context)
    try await Task.sleep(for: .seconds(0.5))

    try await turnLights(.midnightGreen, hueUsername: hueRemoteUsername, hueAccessToken: hueAccessToken, context: context)
    try await Task.sleep(for: .seconds(0.5))

    try await turnLights(.silver, hueUsername: hueRemoteUsername, hueAccessToken: hueAccessToken, context: context)
    try await Task.sleep(for: .seconds(0.5))
}

private func turnLights(_ color: TeamColor, hueUsername: String, hueAccessToken: String, context: LambdaContext) async throws {
    try await withThrowingTaskGroup(of: Void.self) { group in
        for lightNumber in [1, 3, 4, 16] { // both front room lamps and both big lamp bulbs
            group.addTask {
                let hueBody = buildHueBody(for: color)
                let url = "https://api.meethue.com/bridge/\(hueUsername)/lights/\(lightNumber)/state"

                var request = HTTPClientRequest(url: url)
                request.method = .PUT
                request.headers.add(name: "Content-Type", value: "application/json; charset=utf-8")
                request.headers.add(name: "Authorization", value: "Bearer \(hueAccessToken)")

                do {
                    let jsonData = try JSONSerialization.data(withJSONObject: hueBody)
                    var buffer = ByteBuffer()
                    buffer.writeBytes(jsonData)
                    request.body = .bytes(buffer)

                    let response = try await HTTPClient.shared.execute(request, timeout: .seconds(30))

                    guard (200...299).contains(response.status.code) else {
                        context.logger.error("HTTP request failed with status: \(response.status)")
                        return
                    }

                    context.logger.info("Successfully updated light \(lightNumber) state. Status: \(response.status)")
                } catch {
                    context.logger.error("Error updating light \(lightNumber): \(error)")
                }
            }

            try await group.waitForAll()
        }
    }
}

private func buildHueBody(for color: TeamColor) -> [String: Any] {
    var hueBody: [String: Any] = [:]

    switch color {
        // Tulsa Colors
    case .gold:
        hueBody = [
            "on": true,
            "hue": 6926,
            "sat": 89,
            "bri": 254
        ]
    case .blue:
        hueBody = [
            "on": true,
            "hue": 46000,
            "sat": 254,
            "bri": 254
        ]
    case .red:
        hueBody = [
            "on": true,
            "hue": 65535,
            "sat": 237,
            "bri": 254
        ]

        // Eagles Colors
    case .midnightGreen:
        hueBody = [
            "on": true,
            "hue": 33660,
            "sat": 254,
            "bri": 254
        ]
    case .silver:
        hueBody = [
            "on": true,
            "hue": 37145,
            "sat": 10,
            "bri": 254
        ]
    }

    return hueBody
}

enum TeamColor {
    // Tulsa
    case gold, blue, red

    // Eagles
    case midnightGreen, silver
}
