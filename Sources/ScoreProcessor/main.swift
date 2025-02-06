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

        if tulsaWon(gameInfo) {
            context.logger.info("Tulsa won! Flashing lights...")
            try await flashTheaterLightsTulsaColors(context: context)
        }
    }

    return true
}

try await runtime.run()


// MARK: ScoreProcessor Utilities

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
          case .number(let tulsaScore) = newImage["tulsaScore"],
          case .number(let opposingScore) = newImage["opposingScore"],
          case .string(let opposingTeam) = newImage["opposingTeam"],
          case .string(let oldGamePeriod) = oldImage["gamePeriod"],
          case .string(let gamePeriod) = newImage["gamePeriod"] else {
        context.logger.error("Missing or invalid attributes in DynamoDB record")
        return nil
    }

    let gameItem = GameItem(
        gameId: gameId,
        sport: sport,
        tulsaScore: Int(tulsaScore) ?? 0,
        opposingScore: Int(opposingScore) ?? 0,
        opposingTeam: opposingTeam,
        gamePeriod: gamePeriod
    )

    context.logger.info("Processed gameItem: \(gameItem) and previousGamePeriod as: \(oldGamePeriod)")
    return GameInfo(currentGame: gameItem, previousGamePeriod: oldGamePeriod)
}

private func tulsaWon(_ gameInfo: GameInfo) -> Bool {
    let tulsaScore = gameInfo.currentGame.tulsaScore
    let opposingScore = gameInfo.currentGame.opposingScore
    let previousGamePeriod = gameInfo.previousGamePeriod
    let currentGamePeriod = gameInfo.currentGame.gamePeriod

    let gameJustEnded = previousGamePeriod != "FINAL" && currentGamePeriod == "FINAL"

    return gameJustEnded && tulsaScore > opposingScore
}

private func flashTheaterLightsTulsaColors(context: LambdaContext) async throws {
    guard let hueRemoteUsername = try await getSSMParameterValue(parameterName: "hue-remote-username", context: context) else { return }
    guard let hueAccessToken = try await getSSMParameterValue(parameterName: "hue-access-token", context: context) else { return }

    try await turnTheaterLights(.gold, hueUsername: hueRemoteUsername, hueAccessToken: hueAccessToken, context: context)
    try await Task.sleep(for: .seconds(0.5))

    try await turnTheaterLights(.blue, hueUsername: hueRemoteUsername, hueAccessToken: hueAccessToken, context: context)
    try await Task.sleep(for: .seconds(0.5))

    try await turnTheaterLights(.red, hueUsername: hueRemoteUsername, hueAccessToken: hueAccessToken, context: context)
    try await Task.sleep(for: .seconds(0.5))

    try await turnTheaterLights(.gold, hueUsername: hueRemoteUsername, hueAccessToken: hueAccessToken, context: context)
    try await Task.sleep(for: .seconds(0.5))

    try await turnTheaterLights(.blue, hueUsername: hueRemoteUsername, hueAccessToken: hueAccessToken, context: context)
    try await Task.sleep(for: .seconds(0.5))

    try await turnTheaterLights(.red, hueUsername: hueRemoteUsername, hueAccessToken: hueAccessToken, context: context)
    try await Task.sleep(for: .seconds(0.5))

    try await turnTheaterLights(.gold, hueUsername: hueRemoteUsername, hueAccessToken: hueAccessToken, context: context)
    try await Task.sleep(for: .seconds(0.5))

    try await turnTheaterLights(.blue, hueUsername: hueRemoteUsername, hueAccessToken: hueAccessToken, context: context)
    try await Task.sleep(for: .seconds(0.5))

    try await turnTheaterLights(.red, hueUsername: hueRemoteUsername, hueAccessToken: hueAccessToken, context: context)
    try await Task.sleep(for: .seconds(0.5))

    try await turnTheaterLights(.gold, hueUsername: hueRemoteUsername, hueAccessToken: hueAccessToken, context: context)
    try await Task.sleep(for: .seconds(0.5))

    try await turnTheaterLights(.blue, hueUsername: hueRemoteUsername, hueAccessToken: hueAccessToken, context: context)
    try await Task.sleep(for: .seconds(0.5))

    try await turnTheaterLights(.red, hueUsername: hueRemoteUsername, hueAccessToken: hueAccessToken, context: context)
    try await Task.sleep(for: .seconds(0.5))

    try await turnTheaterLights(.gold, hueUsername: hueRemoteUsername, hueAccessToken: hueAccessToken, context: context)
    try await Task.sleep(for: .seconds(0.5))
}

private func turnTheaterLights(_ color: TulsaColor, hueUsername: String, hueAccessToken: String, context: LambdaContext) async throws {
    await withThrowingTaskGroup(of: Void.self) { group in
        for lightNumber in [4, 7, 8, 9] { // emma's lamp & theater lights
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

                    // Make the request
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
        }
    }
}

private func buildHueBody(for color: TulsaColor) -> [String: Any] {
    var hueBody: [String: Any] = [:]

    switch color {
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
    }

    return hueBody
}

enum TulsaColor {
    case gold, blue, red
}
