//
//  GameScoresResponse.swift
//  sports-home-automation-swift
//
//  Created by Ryan Token on 2/2/25.
//

// The response type we get from hitting ncaa-api's /scoreboard endpoint

struct GameScoresResponse: Codable {
    let inputMD5Sum: String
    let instanceId: String
    let updated_at: String
    let games: [Game]
}

struct Game: Codable {
    let gameID: String
    let away: Team
    let home: Team
    let finalMessage: String
    let title: String
    let gameState: String
    let startDate: String
    let currentPeriod: String
    let startTime: String
    let startTimeEpoch: String
}

struct Team: Codable {
    let score: String
    let names: TeamNames
    let winner: Bool
    let description: String
    let rank: String
    let conferences: [Conference]
}

struct TeamNames: Codable {
    let char6: String
    let short: String
    let seo: String
    let full: String
}

struct Conference: Codable {
    let conferenceName: String
    let conferenceSeo: String
}
