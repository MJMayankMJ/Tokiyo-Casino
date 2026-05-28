//
//  CoreDataManager.swift
//  Tokiyo Casino
//

import CoreData
import UIKit

class CoreDataManager {
    static let shared = CoreDataManager()

    let persistentContainer: NSPersistentContainer
    private(set) var loadError: Error?

    private init() {
        persistentContainer = NSPersistentContainer(name: "SlotMachineModel")
        persistentContainer.loadPersistentStores { [weak self] _, error in
            if let error = error {
                #if DEBUG
                print("Core Data failed to load store: \(error)")
                #endif
                self?.loadError = error
            }
        }
    }

    func saveContext() {
        guard loadError == nil else { return }
        let context = persistentContainer.viewContext
        if context.hasChanges {
            do {
                try context.save()
            } catch {
                #if DEBUG
                print("Error saving Core Data context: \(error)")
                #endif
            }
        }
    }

    func fetchUserStats() -> UserStats? {
        guard loadError == nil else { return nil }
        let context = persistentContainer.viewContext
        let fetchRequest: NSFetchRequest<UserStats> = UserStats.fetchRequest()

        do {
            let results = try context.fetch(fetchRequest)
            if let userStats = results.first {
                return userStats
            } else {
                let newStats = UserStats(context: context)
                newStats.totalCoins = 10000
                newStats.lastDailyRewardDate = nil
                saveContext()
                return newStats
            }
        } catch {
            #if DEBUG
            print("Failed to fetch UserStats: \(error)")
            #endif
            return nil
        }
    }
}
