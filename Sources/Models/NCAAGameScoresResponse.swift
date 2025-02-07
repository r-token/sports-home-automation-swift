//
//  NCAAGameScoresResponse.swift
//  sports-home-automation-swift
//
//  Created by Ryan Token on 2/2/25.
//

// The response type we get from hitting ncaa-api's /scoreboard endpoint

public struct NCAAGameScoresResponse: Codable {
    let inputMD5Sum: String
    let instanceId: String
    let updated_at: String
    public let games: [GameWrapper]
}

public struct GameWrapper: Codable {
    public let game: Game
}

public struct Game: Codable {
    public let gameID: String
    public let away: Team
    public let home: Team
    public let finalMessage: String
    public let title: String
    public let gameState: String
    public let startDate: String
    public let currentPeriod: String
    public let startTime: String
    public let startTimeEpoch: String
}

public struct Team: Codable {
    public let score: String
    public let names: TeamNames
    public let winner: Bool
    public let description: String
    public let rank: String
    public let conferences: [Conference]
}

public struct TeamNames: Codable {
    public let char6: String
    public let short: String
    public let seo: String
    public let full: String
}

public struct Conference: Codable {
    public let conferenceName: String
    public let conferenceSeo: String
}
