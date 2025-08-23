//
//  UserStats+CoreDataProperties.swift
//  Tokiyo Casino
//
//  Created by Mayank Jangid on 5/31/25.
//
//

import Foundation
import CoreData


extension UserStats {

    @nonobjc public class func fetchRequest() -> NSFetchRequest<UserStats> {
        return NSFetchRequest<UserStats>(entityName: "UserStats")
    }

    @NSManaged public var collectedCoinsToday: Bool
    @NSManaged public var lastDailyRewardDate: Date?
    @NSManaged public var totalCoins: Int64

}

extension UserStats : Identifiable {

}
