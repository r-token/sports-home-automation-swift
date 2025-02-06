//
//  SSM.swift
//  sports-home-automation-swift
//
//  Created by Ryan Token on 2/5/25.
//

import AWSSSM
import AWSLambdaRuntime
import Models

public func getSSMParameterValue(parameterName: String, context: LambdaContext) async throws -> String? {
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

public func updateSSMParameters(tokenResponse: HueTokenResponse) async throws {
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
