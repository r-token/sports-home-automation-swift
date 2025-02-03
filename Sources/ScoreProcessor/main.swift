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
import AWSSSM
import Foundation
import Models
import NIOCore

let runtime = LambdaRuntime { (event: DynamoDBEvent, context: LambdaContext) -> Bool in
    context.logger.info("Received DynamoDB event: \(event)")

    for event in event.records {
        guard let gameItem = parseDynamoEventIntoGameItem(event: event, context: context) else { continue }

        if tulsaWon(gameItem) {
            try await flashTheaterLightsTulsaColors(context: context)
        }
    }

    return true
}


// MARK: ScoreProcessor Utilities

private func parseDynamoEventIntoGameItem(event: DynamoDBEvent.EventRecord, context: LambdaContext) -> GameItem? {
    guard let newImage = event.change.newImage else {
        context.logger.info("No new image in record, skipping")
        return nil
    }

    guard case .string(let gameId) = newImage["gameId"],
          case .string(let sport) = newImage["sport"],
          case .string(let tulsaScore) = newImage["tulsaScore"],
          case .string(let opposingScore) = newImage["opposingScore"],
          case .string(let opposingTeam) = newImage["opposingTeam"],
          case .string(let gamePeriod) = newImage["gamePeriod"] else {
        context.logger.error("Missing or invalid attributes in DynamoDB record")
        return nil
    }

    let gameItem = GameItem(
        gameId: gameId,
        sport: sport,
        tulsaScore: tulsaScore,
        opposingScore: opposingScore,
        opposingTeam: opposingTeam,
        gamePeriod: gamePeriod
    )

    context.logger.info("Processed game: \(gameItem)")
    return gameItem
}

private func tulsaWon(_ gameItem: GameItem) -> Bool {
    let tulsaScore = Int(gameItem.tulsaScore) ?? 0
    let opposingScore = Int(gameItem.opposingScore) ?? 0
    let gameIsOver = gameItem.gamePeriod == "FINAL"

    return gameIsOver && tulsaScore > opposingScore
}

private func flashTheaterLightsTulsaColors(context: LambdaContext) async throws {
    guard let hueBridgeIp = try await getSSMParameterValue(parameterName: "hue-bridge-ip-address", context: context) else { return }
    guard let hueUsername = try await getSSMParameterValue(parameterName: "hue-username", context: context) else { return }

    try await turnTheaterLights(.gold, hueBridgeIp: hueBridgeIp, hueUsername: hueUsername, context: context)
    try await Task.sleep(for: .seconds(0.5))

    try await turnTheaterLights(.blue, hueBridgeIp: hueBridgeIp, hueUsername: hueUsername, context: context)
    try await Task.sleep(for: .seconds(0.5))

    try await turnTheaterLights(.red, hueBridgeIp: hueBridgeIp, hueUsername: hueUsername, context: context)
    try await Task.sleep(for: .seconds(0.5))

    try await turnTheaterLights(.gold, hueBridgeIp: hueBridgeIp, hueUsername: hueUsername, context: context)
    try await Task.sleep(for: .seconds(0.5))

    try await turnTheaterLights(.blue, hueBridgeIp: hueBridgeIp, hueUsername: hueUsername, context: context)
    try await Task.sleep(for: .seconds(0.5))

    try await turnTheaterLights(.red, hueBridgeIp: hueBridgeIp, hueUsername: hueUsername, context: context)
    try await Task.sleep(for: .seconds(0.5))

    try await turnTheaterLights(.gold, hueBridgeIp: hueBridgeIp, hueUsername: hueUsername, context: context)
    try await Task.sleep(for: .seconds(0.5))

    try await turnTheaterLights(.blue, hueBridgeIp: hueBridgeIp, hueUsername: hueUsername, context: context)
    try await Task.sleep(for: .seconds(0.5))

    try await turnTheaterLights(.red, hueBridgeIp: hueBridgeIp, hueUsername: hueUsername, context: context)
    try await Task.sleep(for: .seconds(0.5))

    try await turnTheaterLights(.gold, hueBridgeIp: hueBridgeIp, hueUsername: hueUsername, context: context)
    try await Task.sleep(for: .seconds(0.5))

    try await turnTheaterLights(.blue, hueBridgeIp: hueBridgeIp, hueUsername: hueUsername, context: context)
}

private func getSSMParameterValue(parameterName: String, context: LambdaContext) async throws -> String? {
    let config = try await SSMClient.SSMClientConfiguration(region: "us-east-1")
    let ssmClient = SSMClient(config: config)
    let input = GetParameterInput(name: parameterName)

    do {
        let response = try await ssmClient.getParameter(input: input)
        guard let parameterValue = response.parameter?.value else {
            context.logger.error("Parameter value for \(input.name ?? "nil") is nil")
            return nil
        }

        context.logger.info("Retrieved parameter value: \(parameterValue)")
        return parameterValue
    } catch {
        context.logger.error("Error fetching parameter \(parameterName): \(error)")
        return nil
    }
}

private func turnTheaterLights(_ color: TulsaColor, hueBridgeIp: String, hueUsername: String, context: LambdaContext) async throws {
    await withThrowingTaskGroup(of: Void.self) { group in
        for lightNumber in 7...9 {
            group.addTask {
                let hueBody = buildHueBody(for: color)
                let url = "http://\(hueBridgeIp)/api/\(hueUsername)/lights/\(lightNumber)/state"

                var request = HTTPClientRequest(url: url)
                request.method = .PUT
                request.headers.add(name: "Content-Type", value: "application/json; charset=utf-8")

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
            "hue": 40018,
            "sat": 254,
            "bri": 254
        ]
    case .red:
        hueBody = [
            "on": true,
            "hue": 63708,
            "sat": 237,
            "bri": 254
        ]
    }

    return hueBody
}


enum TulsaColor {
    case gold, blue, red
}
