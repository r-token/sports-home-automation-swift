//
//  main.swift
//  sports-home-automation-swift
//
//  Created by Ryan Token on 2/5/25.
//

import AsyncHTTPClient
import AWSLambdaEvents
import AWSLambdaRuntime
import AWSSSM
import Foundation
import Models
import NIOCore
import SSMUtils

struct HueTokenRefresherCronJob: CloudwatchDetail {
    static let name = "hue-token-refresher-cron-job"
}

let runtime = LambdaRuntime { (event: HueTokenRefresherCronJob, context: LambdaContext) async throws -> Bool in
    context.logger.info("Received cron event: \(event)")

    guard let (
        hueClientId,
        hueClientSecret,
        hueRefreshToken
    ) = try await getHueSSMParams(context: context) else { return false }
    context.logger.info("Got hueClientId, hueClientSecret, & hueRefreshToken from the SSM Parameter Store")

    if let tokenResponse = try await refreshHueTokens(
        clientId: hueClientId,
        clientSecret: hueClientSecret,
        refreshToken: hueRefreshToken,
        context: context
    ) {
        try await updateSSMParameters(tokenResponse: tokenResponse)

        context.logger.info("Updated hue-access-token and hue-refresh-token in the SSM Parameter Store")
    } else {
        context.logger.error("Unable to refresh hue access and refresh tokens")
    }

    return true
}

try await runtime.run()

private func getHueSSMParams(context: LambdaContext) async throws -> (hueClientId: String, hueClientSecret: String, hueRefreshToken: String)? {
    guard let hueClientId = try await getSSMParameterValue(parameterName: "hue-client-id", context: context) else { return nil }
    guard let hueClientSecret = try await getSSMParameterValue(parameterName: "hue-client-secret", context: context) else { return nil }
    guard let hueRefreshToken = try await getSSMParameterValue(parameterName: "hue-refresh-token", context: context) else { return nil }

    return (hueClientId, hueClientSecret, hueRefreshToken)
}

private func refreshHueTokens(clientId: String, clientSecret: String, refreshToken: String, context: LambdaContext) async throws -> HueTokenResponse? {
    let url = "https://api.meethue.com/v2/oauth2/token"
    var request = HTTPClientRequest(url: url)
    request.method = .POST
    request.headers.add(name: "Content-Type", value: "application/x-www-form-urlencoded")

    // Add Basic Auth header
    let authString = "\(clientId):\(clientSecret)".data(using: .utf8)!.base64EncodedString()
    request.headers.add(name: "Authorization", value: "Basic \(authString)")

    let formData = "grant_type=refresh_token&refresh_token=\(refreshToken)"
    var buffer = ByteBuffer()
    buffer.writeString(formData)
    request.body = .bytes(buffer)

    let response = try await HTTPClient.shared.execute(request, timeout: .seconds(30))
    let body = try await response.body.collect(upTo: 1024 * 1024)
    let data = Data(body.readableBytesView)

    guard (200...299).contains(response.status.code) else {
        context.logger.error("Error: received response code of \(response.status.code)")
        return nil
    }

    do {
        let tokenResponse = try JSONDecoder().decode(HueTokenResponse.self, from: data)
        return tokenResponse
    } catch {
        context.logger.error("JSON decode error: \(error)")
        return nil
    }
}
