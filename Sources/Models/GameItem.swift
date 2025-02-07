//
//  GameItem.swift
//  sports-home-automation-swift
//
//  Created by Ryan Token on 2/2/25.
//

public struct GameItem: Codable {
    public let gameId: String
    public let sport: String
    public let myTeam: String
    public let myTeamScore: Int
    public let opposingTeam: String
    public let opposingTeamScore: Int
    public let gamePeriod: String

    public init(gameId: String, sport: String, myTeam: String, myTeamScore: Int, opposingTeam: String, opposingTeamScore: Int, gamePeriod: String) {
        self.gameId = gameId
        self.sport = sport
        self.myTeam = myTeam
        self.myTeamScore = myTeamScore
        self.opposingTeam = opposingTeam
        self.opposingTeamScore = opposingTeamScore
        self.gamePeriod = gamePeriod
    }
}
