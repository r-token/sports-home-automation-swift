//
//  GameItem.swift
//  sports-home-automation-swift
//
//  Created by Ryan Token on 2/2/25.
//

public struct GameItem: Codable {
    public let gameId: String
    public let sport: String
    public let tulsaScore: String
    public let opposingScore: String
    public let opposingTeam: String
    public let gamePeriod: String

    public init(gameId: String, sport: String, tulsaScore: String, opposingScore: String, opposingTeam: String, gamePeriod: String) {
        self.gameId = gameId
        self.sport = sport
        self.tulsaScore = tulsaScore
        self.opposingScore = opposingScore
        self.opposingTeam = opposingTeam
        self.gamePeriod = gamePeriod
    }
}
