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
    
    
    
    var canCollectCoins: Bool {
        return !(userStats?.collectedCoinsToday ?? false)
    }
    
    
    init() {
        fetchUserStats()
        checkDailyReward()
    }
    
    func fetchUserStats() {
        self.userStats = CoreDataManager.shared.fetchUserStats()
    }
    
    // Checks whether "today" (according to the device time) is in the Keychain list
    // for coins and spins, and updates the Core Data booleans.
    func checkDailyReward() {
        guard let stats = userStats else { return }
        
        let today = Date() // We can optionally do calendar.startOfDay(for: Date()),
                           // but we store only "yyyy-MM-dd" in the Keychain anyway.
        
        // Coins
        let coinsClaimed = KeychainHelper.shared.isDayClaimed(today, for: "claimedCoinsDates")
        stats.collectedCoinsToday = coinsClaimed
        
        
        CoreDataManager.shared.saveContext()
        onUpdate?()
    }
    
    // Adds today's date to the Keychain array for coins, updates the stats, and saves.
    func collectCoins() {
        guard let stats = userStats, !stats.collectedCoinsToday else { return }
        
        stats.totalCoins += 1000
        stats.collectedCoinsToday = true
        CoreDataManager.shared.saveContext()
        
        KeychainHelper.shared.addClaimedDay(Date(), for: "claimedCoinsDates")
        onUpdate?()
    }
    
}
