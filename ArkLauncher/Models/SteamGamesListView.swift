//
//  SteamGamesListView.swift
//  WineLauncher
//
//  Created by Nico Werner on 04.10.26.
//

import SwiftUI

struct SteamGamesListView: View {
    
    let games: [SteamGameScanner.SteamGame]
    let onAdd: (SteamGameScanner.SteamGame) -> Void
    
    @Environment(\.dismiss) private var dismiss
    @State private var searchText = ""
    @State private var addedGames: Set<String> = []
    
    private var filteredGames: [SteamGameScanner.SteamGame] {
        if searchText.isEmpty {
            return games
        }
        return games.filter { $0.name.localizedCaseInsensitiveContains(searchText) }
    }
    
    var body: some View {
        VStack(spacing: 0) {
            // Header
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Steam-Spiele")
                        .font(.title)
                        .bold()
                    
                    Text("\(games.count) Spiele gefunden")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
                
                Spacer()
                
                Button("Fertig") {
                    dismiss()
                }
                .buttonStyle(.borderedProminent)
            }
            .padding()
            
            Divider()
            
            // Suchfeld
            HStack {
                Image(systemName: "magnifyingglass")
                    .foregroundStyle(.secondary)
                
                TextField("Spiele durchsuchen...", text: $searchText)
                    .textFieldStyle(.plain)
                
                if !searchText.isEmpty {
                    Button {
                        searchText = ""
                    } label: {
                        Image(systemName: "xmark.circle.fill")
                            .foregroundStyle(.secondary)
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding()
            .background(Color.secondary.opacity(0.1))
            
            // Spiele-Liste
            if filteredGames.isEmpty {
                emptyStateView
            } else {
                List {
                    ForEach(filteredGames) { game in
                        GameRow(
                            game: game,
                            isAdded: addedGames.contains(game.id),
                            onAdd: {
                                addGame(game)
                            }
                        )
                    }
                }
                .listStyle(.inset)
            }
        }
        .frame(width: 700, height: 600)
    }
    
    private var emptyStateView: some View {
        VStack(spacing: 16) {
            Image(systemName: searchText.isEmpty ? "tray" : "magnifyingglass")
                .font(.system(size: 64))
                .foregroundStyle(.secondary)
            
            Text(searchText.isEmpty ? "Keine Spiele gefunden" : "Keine Suchergebnisse")
                .font(.title2)
            
            Text(searchText.isEmpty ? 
                 "Installieren Sie Spiele über Steam" :
                 "Versuchen Sie einen anderen Suchbegriff")
                .font(.subheadline)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
    
    private func addGame(_ game: SteamGameScanner.SteamGame) {
        onAdd(game)
        addedGames.insert(game.id)
    }
}

// MARK: - Game Row

private struct GameRow: View {
    
    let game: SteamGameScanner.SteamGame
    let isAdded: Bool
    let onAdd: () -> Void
    
    var body: some View {
        HStack(spacing: 16) {
            // Spiel-Icon (Placeholder)
            ZStack {
                RoundedRectangle(cornerRadius: 8)
                    .fill(Color.accentColor.opacity(0.2))
                
                Image(systemName: "gamecontroller.fill")
                    .font(.title)
                    .foregroundStyle(.secondary)
            }
            .frame(width: 60, height: 60)
            
            // Spiel-Info
            VStack(alignment: .leading, spacing: 4) {
                Text(game.name)
                    .font(.headline)
                
                Text(game.installDir)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                
                Text("App-ID: \(game.id)")
                    .font(.caption2)
                    .foregroundStyle(.tertiary)
            }
            
            Spacer()
            
            // Add Button
            Button {
                onAdd()
            } label: {
                if isAdded {
                    Label("Hinzugefügt", systemImage: "checkmark.circle.fill")
                        .foregroundStyle(.green)
                } else {
                    Label("Hinzufügen", systemImage: "plus.circle")
                }
            }
            .buttonStyle(.bordered)
            .disabled(isAdded)
        }
        .padding(.vertical, 8)
    }
}

#Preview {
    SteamGamesListView(
        games: [
            SteamGameScanner.SteamGame(
                id: "730",
                name: "Counter-Strike 2",
                installDir: "Counter-Strike Global Offensive",
                executablePath: URL(fileURLWithPath: "/test/cs2.exe"),
                libraryPath: URL(fileURLWithPath: "/test")
            ),
            SteamGameScanner.SteamGame(
                id: "570",
                name: "Dota 2",
                installDir: "dota 2 beta",
                executablePath: URL(fileURLWithPath: "/test/dota.exe"),
                libraryPath: URL(fileURLWithPath: "/test")
            )
        ],
        onAdd: { _ in }
    )
}
