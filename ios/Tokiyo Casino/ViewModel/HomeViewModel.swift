//
//  HomeViewModel.swift
//  Tokiyo Casino
//
//  Created by Mayank Jangid on 5/31/25.
//


import Foundation
import CoreData

class HomeViewModel {
    var userStats: UserStats?

    var onUpdate: (() -> Void)?

    var totalCoins: Int64 {
        return userStats?.totalCoins ?? 0
    }

    init() {
        fetchUserStats()
    }

    func fetchUserStats() {
        self.userStats = CoreDataManager.shared.fetchUserStats()
    }

}
