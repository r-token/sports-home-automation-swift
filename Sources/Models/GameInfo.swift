//
//  GameInfo.swift
//  sports-home-automation-swift
//
//  Created by Ryan Token on 2/6/25.
//

public struct GameInfo {
    public var currentGame: GameItem
    public var previousGamePeriod: String
    public var previousMyTeamScore: Int

    public init(currentGame: GameItem, previousGamePeriod: String, previousMyTeamScore: Int) {
        self.currentGame = currentGame
        self.previousGamePeriod = previousGamePeriod
        self.previousMyTeamScore = previousMyTeamScore
    }
}
