//
//  MeasurableValue.swift
//  gym app
//
//  Represents a logged value for an implement measurable
//  Supports both numeric (24.0 for height) and string ("Red" for band color) values
//

import Foundation

struct MeasurableValue: Codable, Hashable {
    var numericValue: Double?
    var stringValue: String?

    init(numericValue: Double? = nil, stringValue: String? = nil) {
        self.numericValue = numericValue
        self.stringValue = stringValue
    }
}
