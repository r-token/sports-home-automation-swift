//
//  File.swift
//  sports-home-automation-swift
//
//  Created by Ryan Token on 2/5/25.
//

import AWSSSM
import AWSLambdaRuntime

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
