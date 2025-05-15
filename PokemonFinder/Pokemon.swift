//
//  Pokemon.swift
//  PokemonFinder
//
//  Created by Student on 5/8/25.
//

import Foundation

// --- Main Pokemon Response ---
struct PokemonResponse: Codable, Identifiable {
    let id: Int
    let name: String
    let sprites: Sprites
    let types: [TypeElement]
    let height: Int // in decimetres
    let weight: Int // in hectograms
    let abilities: [AbilityElement]
    let stats: [StatElement]
    let species: SpeciesLink // Link to species data for Pokedex entry

    // Computed properties for better display
    var displayName: String { name.capitalized }
    var displayID: String { String(format: "#%03d", id) }
    var displayHeight: String { "\(Double(height) / 10.0) m" }
    var displayWeight: String { "\(Double(weight) / 10.0) kg" }
    var mainType: String? { types.first?.type.name.capitalized }
}

// --- Sprites ---
struct Sprites: Codable {
    let frontDefault: URL?
    enum CodingKeys: String, CodingKey {
        case frontDefault = "front_default"
    }
}

// --- Types ---
struct TypeElement: Codable, Identifiable { // Make Identifiable if used in ForEach with \.self
    var id: Int { slot } // Or generate a UUID if slot isn't unique enough for complex scenarios
    let slot: Int
    let type: TypeInfo
}

struct TypeInfo: Codable {
    let name: String
    let url: String
}

// --- Abilities ---
struct AbilityElement: Codable, Identifiable {
    var id = UUID() // For ForEach
    let ability: AbilityInfo
    let isHidden: Bool
    let slot: Int

    enum CodingKeys: String, CodingKey {
        case ability
        case isHidden = "is_hidden"
        case slot
    }
}

struct AbilityInfo: Codable {
    let name: String
    let url: String

    var displayName: String {
        name.replacingOccurrences(of: "-", with: " ").capitalized
    }
}

// --- Stats ---
struct StatElement: Codable, Identifiable {
    var id: String { stat.name } // stat.name is unique per Pokemon
    let baseStat: Int
    let effort: Int
    let stat: StatInfo

    enum CodingKeys: String, CodingKey {
        case baseStat = "base_stat"
        case effort
        case stat
    }
}

struct StatInfo: Codable {
    let name: String
    let url: String

    var displayName: String {
        switch name {
        case "hp": return "HP"
        case "attack": return "Attack"
        case "defense": return "Defense"
        case "special-attack": return "Sp. Atk"
        case "special-defense": return "Sp. Def"
        case "speed": return "Speed"
        default: return name.capitalized
        }
    }
    // Max base stat for scaling progress bars (approximate, adjust if needed)
    var maxStatValue: Double {
        switch name {
        case "hp": return 255
        case "attack": return 190
        case "defense": return 230 // Shuckle
        case "special-attack": return 194
        case "special-defense": return 230 // Shuckle
        case "speed": return 200
        default: return 200
        }
    }
}

// --- Species Link (for Pokedex entry) ---
struct SpeciesLink: Codable {
    let name: String
    let url: String // This URL will be used for the second API call
}

// --- Pokemon Species Response (for Pokedex entry) ---
struct PokemonSpeciesResponse: Codable {
    let flavorTextEntries: [FlavorTextEntry]

    enum CodingKeys: String, CodingKey {
        case flavorTextEntries = "flavor_text_entries"
    }

    // Helper to get the first English flavor text
    var englishFlavorText: String? {
        flavorTextEntries.first(where: { $0.language.name == "en" })?.flavorText
            .replacingOccurrences(of: "\n", with: " ")
            .replacingOccurrences(of: "\u{000C}", with: " ") // Form Feed character
    }
}

struct FlavorTextEntry: Codable {
    let flavorText: String
    let language: LanguageLink
    let version: VersionLink

    enum CodingKeys: String, CodingKey {
        case flavorText = "flavor_text"
        case language
        case version
    }
}

struct LanguageLink: Codable {
    let name: String // e.g., "en"
    let url: String
}

struct VersionLink: Codable {
    let name: String // e.g., "red", "blue"
    let url: String
}
