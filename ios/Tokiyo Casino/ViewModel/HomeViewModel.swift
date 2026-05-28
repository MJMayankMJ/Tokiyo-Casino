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
    private let dailySpinManager: DailySpinManager
    
    var onUpdate: (() -> Void)?
    
    var totalCoins: Int64 {
        return userStats?.totalCoins ?? 0
    }
    
    var remainingDailySpins: Int {
        return dailySpinManager.remainingSpinsToday
    }
    
    var canSpinForCoins: Bool {
        return remainingDailySpins > 0
    }
    
    init(dailySpinManager: DailySpinManager = .shared) {
        self.dailySpinManager = dailySpinManager
        fetchUserStats()
    }
    
    func fetchUserStats() {
        self.userStats = CoreDataManager.shared.fetchUserStats()
    }

}
