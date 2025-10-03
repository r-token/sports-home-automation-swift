//
//  NFLGameScoresResponse.swift
//  sports-home-automation-swift
//
//  Created by Ryan Token on 2/6/25.
//

// The response type we get from hitting ESPN's /scoreboard site API endpoint

public struct NFLGameScoresResponse: Codable {
    public let leagues: [League]
    public let season: Season
    public let week: Week
    public let events: [Event]
}

public struct League: Codable {
    public let id: String
    public let name: String
    public let abbreviation: String
    public let season: LeagueSeason
    public let calendar: [Calendar]
}

public struct LeagueSeason: Codable {
    public let year: Int
    public let startDate: String
    public let endDate: String
    public let type: SeasonType
}

public struct SeasonType: Codable {
    public let id: String
    public let type: Int
    public let name: String
    public let abbreviation: String
}

public struct Calendar: Codable {
    public let label: String
    public let value: String
    public let startDate: String
    public let endDate: String
    public let entries: [CalendarEntry]
}

public struct CalendarEntry: Codable {
    public let label: String
    public let alternateLabel: String
    public let detail: String
    public let value: String
    public let startDate: String
    public let endDate: String
}

public struct Season: Codable {
    public let type: Int
    public let year: Int
}

public struct Week: Codable {
    public let number: Int
}

public struct Event: Codable {
    public let id: String
    public let date: String
    public let name: String
    public let shortName: String
    public let competitions: [Competition]
}

public struct Competition: Codable {
    public let id: String
    public let date: String
    public let venue: Venue?
    public let competitors: [Competitor]
    public let status: Status
    public let broadcasts: [Broadcast]?
}

public struct Venue: Codable {
    public let fullName: String
    public let address: Address
    public let indoor: Bool
}

public struct Address: Codable {
	public let city: String
	public let state: String?
	public let country: String?
}

public struct Competitor: Codable {
    public let id: String
    public let homeAway: String
    public let team: NFLTeam
    public let score: String
}

public struct NFLTeam: Codable {
    public let id: String
    public let location: String
    public let name: String
    public let abbreviation: String
    public let displayName: String
    public let color: String
    public let logo: String
}

public struct Status: Codable {
    public let clock: Double
    public let displayClock: String
    public let period: Int
    public let type: StatusType
}

public struct StatusType: Codable {
    public let id: String
    public let name: String
    public let state: String
    public let completed: Bool
    public let description: String
    public let detail: String
    public let shortDetail: String
}

public struct Broadcast: Codable {
    public let market: String
    public let names: [String]
}
