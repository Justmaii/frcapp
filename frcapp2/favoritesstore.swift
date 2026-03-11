//
//  favoritesstore.swift
//  frcapp2
//
//  Created by Mai Ddk on 10.03.2026.
//
import SwiftUI
import Combine

// MARK: - Favorites Store (paylaşılan, tüm uygulamada kullanılır)

class FavoritesStore: ObservableObject {
    static let shared = FavoritesStore()

    @Published var favoriteTeamNumbers: Set<Int> = []

    private let key = "favorite_teams"

    init() {
        if let saved = UserDefaults.standard.array(forKey: key) as? [Int] {
            favoriteTeamNumbers = Set(saved)
        }
    }

    func toggle(_ teamNumber: Int) {
        if favoriteTeamNumbers.contains(teamNumber) {
            favoriteTeamNumbers.remove(teamNumber)
        } else {
            favoriteTeamNumbers.insert(teamNumber)
        }
        UserDefaults.standard.set(Array(favoriteTeamNumbers), forKey: key)
    }

    func isFavorite(_ teamNumber: Int) -> Bool {
        favoriteTeamNumbers.contains(teamNumber)
    }
}

