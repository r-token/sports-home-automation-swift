//
//  Date+Month-Day.swift
//  sports-home-automation-swift
//
//  Created by Ryan Token on 2/6/25.
//

import Foundation

public extension Date {
    var month: Int { Calendar.current.component(.month, from: self) }
    var day: Int { Calendar.current.component(.day, from: self) }
}
