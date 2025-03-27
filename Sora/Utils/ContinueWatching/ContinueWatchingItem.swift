//
//  ContinueWatchingItem.swift
//  Sora
//
//  Created by Francesco on 14/02/25.
//

import Foundation

struct ContinueWatchingItem: Codable, Identifiable {
    let id: UUID
    let imageUrl: String
    let topLevelImageUrl: String?
    let episodeNumber: Int
    let mediaTitle: String
    let progress: Double
    let streamUrl: String
    let fullUrl: String
    let subtitles: String?
    let module: ScrapingModule
    
    var displayImageTypeURL: URL? {
        if !imageUrl.isEmpty {
            return URL(string: imageUrl)
        } else if let topLevelUrl = topLevelImageUrl, !topLevelUrl.isEmpty {
            return URL(string: topLevelUrl)
        }
        return URL(string: "https://raw.githubusercontent.com/cranci1/Sora/refs/heads/main/assets/banner2.png")
    }
}
