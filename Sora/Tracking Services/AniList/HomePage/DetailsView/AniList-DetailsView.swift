//
//  AniList-DetailsView.swift
//  Sora
//
//  Created by Francesco on 11/02/25.
//

import SwiftUI
import Kingfisher

struct AniListDetailsView: View {
    let animeID: Int
    @StateObject private var viewModel: AniListDetailsViewModel
    
    init(animeID: Int) {
        self.animeID = animeID
        _viewModel = StateObject(wrappedValue: AniListDetailsViewModel(animeID: animeID))
    }
    
    var body: some View {
        ScrollView {
            VStack(spacing: 16) {
                if viewModel.isLoading {
                    ProgressView()
                        .padding()
                } else if let media = viewModel.mediaInfo {
                    MediaHeaderView(media: media)
                    Divider()
                    MediaDetailsScrollView(media: media)
                    Divider()
                    SynopsisView(synopsis: media["description"] as? String)
                    Divider()
                    CharactersView(characters: media["characters"] as? [String: Any])
                    Divider()
                    ScoreDistributionView(stats: media["stats"] as? [String: Any])
                } else {
                    Text("Failed to load media details.")
                        .padding()
                }
            }
        }
#if !os(tvOS)
        .navigationBarTitle("", displayMode: .inline)
#endif
        .navigationViewStyle(StackNavigationViewStyle())
        .onAppear {
            viewModel.fetchDetails()
        }
    }
}

class AniListDetailsViewModel: ObservableObject {
    @Published var mediaInfo: [String: AnyHashable]?
    @Published var isLoading: Bool = true
    
    let animeID: Int
    
    init(animeID: Int) {
        self.animeID = animeID
    }
    
    func fetchDetails() {
        AnilistServiceMediaInfo.fetchAnimeDetails(animeID: animeID) { result in
            DispatchQueue.main.async {
                switch result {
                case .success(let media):
                    var convertedMedia: [String: AnyHashable] = [:]
                    for (key, value) in media {
                        if let value = value as? AnyHashable {
                            convertedMedia[key] = value
                        }
                    }
                    self.mediaInfo = convertedMedia
                case .failure(let error):
                    print("Error: \(error)")
                }
                self.isLoading = false
            }
        }
    }
}

struct MediaHeaderView: View {
    let media: [String: Any]
    
    var body: some View {
        HStack(alignment: .top, spacing: 16) {
            if let coverDict = media["coverImage"] as? [String: Any],
               let posterURLString = coverDict["extraLarge"] as? String,
               let posterURL = URL(string: posterURLString) {
                KFImage(posterURL)
                    .placeholder {
                        RoundedRectangle(cornerRadius: 10)
                            .fill(Color.gray.opacity(0.3))
                            .frame(width: 150, height: 225)
                            .shimmering()
                    }
                    .resizable()
                    .aspectRatio(2/3, contentMode: .fill)
                    .cornerRadius(10)
                    .frame(width: 150, height: 225)
            }
            
            VStack(alignment: .leading) {
                if let titleDict = media["title"] as? [String: Any],
                   let userPreferred = titleDict["english"] as? String {
                    Text(userPreferred)
                        .font(.system(size: 17))
                        .fontWeight(.bold)
#if !os(tvOS)
                        .onLongPressGesture {
                            UIPasteboard.general.string = userPreferred
                            DropManager.shared.showDrop(title: "Copied to Clipboard", subtitle: "", duration: 1.0, icon: UIImage(systemName: "doc.on.clipboard.fill"))
                        }
#endif
                }
                
                if let titleDict = media["title"] as? [String: Any],
                   let userPreferred = titleDict["romaji"] as? String {
                    Text(userPreferred)
                        .font(.system(size: 13))
                        .foregroundColor(.secondary)
                }
                
                if let titleDict = media["title"] as? [String: Any],
                   let userPreferred = titleDict["native"] as? String {
                    Text(userPreferred)
                        .font(.system(size: 13))
                        .foregroundColor(.secondary)
                }
            }
            
            Spacer()
        }
        .padding()
    }
}

struct MediaDetailsScrollView: View {
    let media: [String: Any]
    
    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 4) {
                if let type = media["type"] as? String {
                    MediaDetailItem(title: "Type", value: type)
                    Divider()
                }
                if let episodes = media["episodes"] as? Int {
                    MediaDetailItem(title: "Episodes", value: "\(episodes)")
                    Divider()
                }
                if let duration = media["duration"] as? Int {
                    MediaDetailItem(title: "Length", value: "\(duration) mins")
                    Divider()
                }
                if let format = media["format"] as? String {
                    MediaDetailItem(title: "Format", value: format)
                    Divider()
                }
                if let status = media["status"] as? String {
                    MediaDetailItem(title: "Status", value: status)
                    Divider()
                }
                if let season = media["season"] as? String {
                    MediaDetailItem(title: "Season", value: season)
                    Divider()
                }
                if let startDate = media["startDate"] as? [String: Any],
                   let year = startDate["year"] as? Int,
                   let month = startDate["month"] as? Int,
                   let day = startDate["day"] as? Int {
                    MediaDetailItem(title: "Start Date", value: "\(year)-\(month)-\(day)")
                    Divider()
                }
                if let endDate = media["endDate"] as? [String: Any],
                   let year = endDate["year"] as? Int,
                   let month = endDate["month"] as? Int,
                   let day = endDate["day"] as? Int {
                    MediaDetailItem(title: "End Date", value: "\(year)-\(month)-\(day)")
                }
            }
        }
    }
}

struct SynopsisView: View {
    let synopsis: String?
    
    var body: some View {
        if let synopsis = synopsis {
            Text(synopsis.strippedHTML)
                .padding(.horizontal)
                .foregroundColor(.secondary)
                .font(.system(size: 14))
        } else {
            EmptyView()
        }
    }
}

struct CharactersView: View {
    let characters: [String: Any]?
    
    var body: some View {
        if let charactersDict = characters,
           let edges = charactersDict["edges"] as? [[String: Any]] {
            VStack(alignment: .leading, spacing: 8) {
                Text("Characters")
                    .font(.headline)
                    .padding(.horizontal)
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 8) {
                        ForEach(Array(edges.prefix(15).enumerated()), id: \.offset) { _, edge in
                            if let node = edge["node"] as? [String: Any],
                               let nameDict = node["name"] as? [String: Any],
                               let fullName = nameDict["full"] as? String,
                               let imageDict = node["image"] as? [String: Any],
                               let imageUrlStr = imageDict["large"] as? String,
                               let imageUrl = URL(string: imageUrlStr) {
                                CharacterItemView(imageUrl: imageUrl, name: fullName)
                            }
                        }
                    }
                    .padding(.horizontal)
                }
            }
        } else {
            EmptyView()
        }
    }
}

struct CharacterItemView: View {
    let imageUrl: URL
    let name: String
    
    var body: some View {
        VStack {
            KFImage(imageUrl)
                .placeholder {
                    Circle()
                        .fill(Color.gray.opacity(0.3))
                        .frame(width: 90, height: 90)
                        .shimmering()
                }
                .resizable()
                .scaledToFill()
                .frame(width: 90, height: 90)
                .clipShape(Circle())
            Text(name)
                .font(.caption)
                .lineLimit(1)
        }
        .frame(width: 105, height: 110)
    }
}

struct ScoreDistributionView: View {
    let stats: [String: Any]?
    
    @State private var barHeights: [CGFloat] = []
    
    var body: some View {
        if let stats = stats,
           let scoreDistribution = stats["scoreDistribution"] as? [[String: AnyHashable]] {
            
            let maxValue: Int = scoreDistribution.compactMap { $0["amount"] as? Int }.max() ?? 1
            
            let calculatedHeights = scoreDistribution.map { dataPoint -> CGFloat in
                guard let amount = dataPoint["amount"] as? Int else { return 0 }
                return CGFloat(amount) / CGFloat(maxValue) * 100
            }
            
            VStack {
                Text("Score Distribution")
                    .font(.headline)
                HStack(alignment: .bottom) {
                    ForEach(Array(scoreDistribution.enumerated()), id: \.offset) { index, dataPoint in
                        if let score = dataPoint["score"] as? Int {
                            VStack {
                                Rectangle()
                                    .fill(Color.accentColor)
                                    .frame(width: 20, height: calculatedHeights[index])
                                Text("\(score)")
                                    .font(.caption)
                            }
                        }
                    }
                }
            }
            .frame(maxWidth: .infinity)
            .padding(.horizontal)
            .onAppear {
                barHeights = calculatedHeights
            }
            .onChange(of: scoreDistribution) { _ in
                barHeights = calculatedHeights
            }
        } else {
            EmptyView()
        }
    }
}

struct MediaDetailItem: View {
    var title: String
    var value: String
    
    var body: some View {
        VStack {
            Text(value)
                .font(.system(size: 17))
            Text(title)
                .font(.system(size: 13))
                .foregroundColor(.secondary)
        }
        .padding(.horizontal)
    }
}
