//
//  SharedUtils.swift
//  sports-home-automation-swift
//
//  Created by Ryan Token on 2/6/25.
//

import Extensions
import Foundation

// Football season = August through February
public let isFootballSeason = (8...12).contains(Date().month) || (1...2).contains(Date().month)

// Basketball season = October through April 15
public let isBasketballSeason = (10...12).contains(Date().month) || (1...4).contains(Date().month) && !(Date().month == 4 && Date().day > 15)
