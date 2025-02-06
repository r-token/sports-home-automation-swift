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
import NIOCore
import Utils

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
        refreshToken: hueRefreshToken
    ) {
        try await updateSSMParameters(tokenResponse: tokenResponse)

        context.logger.info("Updated hue-access-token and hue-refresh-token in the SSM Parameter Store")
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

private func refreshHueTokens(clientId: String, clientSecret: String, refreshToken: String) async throws -> HueTokenResponse? {
    var request = HTTPClientRequest(url: "https://api.meethue.com/oauth2/refresh?grant_type=refresh_token")
    request.method = .POST
    request.headers.add(name: "Content-Type", value: "application/x-www-form-urlencoded")

    // Add Basic Auth header
    let authString = "\(clientId):\(clientSecret)".data(using: .utf8)!.base64EncodedString()
    request.headers.add(name: "Authorization", value: "Basic \(authString)")

    // Create form body
    var buffer = ByteBuffer()
    buffer.writeString("refresh_token=\(refreshToken)")
    request.body = .bytes(buffer)

    let response = try await HTTPClient.shared.execute(request, timeout: .seconds(30))

    guard (200...299).contains(response.status.code) else {
        return nil
    }

    let body = try await response.body.collect(upTo: 1024 * 1024)
    let data = Data(body.readableBytesView)

    let tokenResponse = try JSONDecoder().decode(HueTokenResponse.self, from: data)
    return tokenResponse
}

private func updateSSMParameters(tokenResponse: HueTokenResponse) async throws {
    let ssmClient = SSMClient(config: try await SSMClient.SSMClientConfiguration(region: "us-east-1"))

    let accessTokenInput = PutParameterInput(
        name: "hue-access-token",
        overwrite: true,
        type: .string,
        value: tokenResponse.access_token
    )

    let refreshTokenInput = PutParameterInput(
        name: "hue-refresh-token",
        overwrite: true,
        type: .string,
        value: tokenResponse.refresh_token
    )

    _ = try await ssmClient.putParameter(input: accessTokenInput)
    _ = try await ssmClient.putParameter(input: refreshTokenInput)
}


struct HueTokenResponse: Codable {
    let access_token: String
    let refresh_token: String
}
