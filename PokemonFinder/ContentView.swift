//
//  ContentView.swift
//  PokemonFinder
//
//  Created by Student on 5/8/25.
//

import SwiftUI

struct ContentView: View {
    @State private var searchText: String = ""
    @State private var pokemon: PokemonResponse?
    @State private var isLoading: Bool = false
    @State private var errorMessage: String?

    private let apiService = PokeAPIService()

    var body: some View {
        NavigationView {
            VStack(spacing: 20) {
                HStack {
                    TextField("Enter Pokémon name or ID", text: $searchText)
                        .textFieldStyle(RoundedBorderTextFieldStyle())
                        .autocapitalization(.none)
                        .disableAutocorrection(true)
                        .onSubmit(performSearch)

                    Button(action: performSearch) {
                        Image(systemName: "magnifyingglass")
                            .font(.title2)
                    }
                    .disabled(searchText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                }
                .padding(.horizontal)

                if isLoading {
                    ProgressView("Searching...")
                        .padding()
                } else if let errorMsg = errorMessage {
                    Text("Error: \(errorMsg)")
                        .foregroundColor(.red)
                        .padding()
                } else if let pokemon = pokemon {
                    // Pass the apiService to PokemonDetailView for fetching species data
                    PokemonDetailView(pokemon: pokemon, apiService: apiService)
                } else {
                    Text("Search for a Pokémon to see its details.")
                        .foregroundColor(.gray)
                        .padding()
                }
                
                Spacer()
            }
            .navigationTitle("PokéSearch")
            .padding(.top)
        }
    }

    func performSearch() {
        guard !searchText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            self.errorMessage = "Search term cannot be empty."
            self.pokemon = nil
            return
        }
        
        isLoading = true
        errorMessage = nil
        pokemon = nil

        Task {
            do {
                let result = try await apiService.fetchPokemon(nameOrId: searchText)
                DispatchQueue.main.async {
                    self.pokemon = result
                    self.isLoading = false
                }
            } catch let apiError as APIError {
                DispatchQueue.main.async {
                    switch apiError {
                    case .invalidURL:
                        self.errorMessage = "Invalid URL constructed."
                    case .requestFailed:
                        self.errorMessage = "Network request failed. Check your connection."
                    case .invalidResponse:
                        self.errorMessage = "Received an invalid response from the server."
                    case .decodingError:
                        self.errorMessage = "Failed to decode Pokémon data."
                    case .pokemonNotFound:
                        self.errorMessage = "Pokémon '\(searchText)' not found."
                    case .speciesDataNotFound:
                        self.errorMessage = "Could not find species data for this Pokémon."
                    }
                    self.isLoading = false
                }
            } catch {
                 DispatchQueue.main.async {
                    self.errorMessage = "An unexpected error occurred: \(error.localizedDescription)"
                    self.isLoading = false
                }
            }
        }
    }
}

struct PokemonDetailView: View {
    let pokemon: PokemonResponse
    let apiService: PokeAPIService // Inject APIService

    @State private var flavorText: String?
    @State private var isLoadingFlavorText: Bool = false
    @State private var flavorTextError: String?

    var body: some View {
        ScrollView {
            VStack(alignment: .center, spacing: 15) {
                Text(pokemon.displayName)
                    .font(.largeTitle)
                    .fontWeight(.bold)

                Text(pokemon.displ)
                    .font(.title2)
                    .foregroundColor(.gray)

                AsyncImage(url: pokemon.sprites.frontDefault) { phase in
                    switch phase {
                    case .empty:
                        ProgressView().frame(width: 150, height: 150)
                    case .success(let image):
                        image.resizable().aspectRatio(contentMode: .fit).frame(width: 150, height: 150)
                    case .failure:
                        Image(systemName: "questionmark.diamond").resizable().aspectRatio(contentMode: .fit).frame(width: 100, height: 100).foregroundColor(.gray)
                    @unknown default: EmptyView()
                    }
                }
                .padding(.bottom)

                // --- Types ---
                HStack {
                    ForEach(pokemon.types) { typeElement in // Made TypeElement Identifiable
                        Text(typeElement.type.name.capitalized)
                            .font(.headline)
                            .padding(.horizontal, 12)
                            .padding(.vertical, 6)
                            .background(typeColor(for: typeElement.type.name))
                            .foregroundColor(.white)
                            .cornerRadius(15)
                    }
                }

                // --- Pokedex Entry (Flavor Text) ---
                VStack(alignment: .leading, spacing: 5) {
                    Text("Pokedex Entry")
                        .font(.title3)
                        .fontWeight(.semibold)
                    if isLoadingFlavorText {
                        ProgressView()
                    } else if let error = flavorTextError {
                        Text("Error: \(error)")
                            .font(.footnote)
                            .foregroundColor(.red)
                    } else if let text = flavorText {
                        Text(text)
                            .font(.body)
                            .italic()
                            .padding(.vertical, 5)
                            .fixedSize(horizontal: false, vertical: true) // Allow text to wrap
                    } else {
                        Text("No Pokedex entry available.")
                            .font(.footnote)
                            .foregroundColor(.gray)
                    }
                }
                .padding()
                .frame(maxWidth: .infinity, alignment: .leading) // Make it take full width
                .background(Color(UIColor.secondarySystemBackground))
                .cornerRadius(10)


                // --- Basic Info (Height, Weight) ---
                SectionView(title: "Info") {
                    DetailRow(label: "Height", value: pokemon.displayHeight)
                    DetailRow(label: "Weight", value: pokemon.displayWeight)
                }

                // --- Abilities ---
                SectionView(title: "Abilities") {
                    ForEach(pokemon.abilities) { abilityElement in
                        HStack {
                            Text(abilityElement.ability.displayName)
                                .fontWeight(abilityElement.isHidden ? .regular : .semibold)
                            if abilityElement.isHidden {
                                Text("(Hidden)")
                                    .font(.caption)
                                    .foregroundColor(.gray)
                            }
                            Spacer()
                        }
                        .padding(.vertical, 2)
                    }
                }

                // --- Base Stats ---
                SectionView(title: "Base Stats") {
                    ForEach(pokemon.stats) { statElement in
                        StatRow(
                            label: statElement.stat.displayName,
                            value: statElement.baseStat,
                            maxValue: statElement.stat.maxStatValue, // Use stat-specific max
                            color: typeColor(for: pokemon.mainType ?? "normal") // Color based on main type
                        )
                    }
                }
                Spacer()
            }
            .padding()
        }
        .onAppear {
            fetchSpeciesData()
        }
        .onChange(of: pokemon.id) { _ in // Re-fetch if Pokemon changes
             fetchSpeciesData()
        }
    }

    private func fetchSpeciesData() {
        isLoadingFlavorText = true
        flavorTextError = nil
        flavorText = nil // Clear previous

        Task {
            do {
                let speciesData = try await apiService.fetchPokemonSpecies(from: pokemon.species.url)
                DispatchQueue.main.async {
                    if let ft = speciesData.englishFlavorText, !ft.isEmpty {
                        self.flavorText = ft
                    } else {
                        self.flavorText = "No English Pokedex entry found."
                    }
                    self.isLoadingFlavorText = false
                }
            } catch let apiError as APIError {
                 DispatchQueue.main.async {
                    switch apiError {
                    case .speciesDataNotFound:
                        self.flavorTextError = "Species data not found."
                    default:
                        self.flavorTextError = "Could not load Pokedex entry."
                    }
                    self.isLoadingFlavorText = false
                }
            }
            catch {
                DispatchQueue.main.async {
                    self.flavorTextError = "An error occurred."
                    self.isLoadingFlavorText = false
                }
            }
        }
    }

    func typeColor(for typeName: String) -> Color {
        // (Keep your existing typeColor function here)
        switch typeName.lowercased() {
        case "grass": return .green
        case "fire": return .red
        case "water": return .blue
        case "electric": return .yellow
        case "psychic": return .purple
        case "normal": return .gray
        case "fighting": return .orange
        case "flying": return .cyan
        case "poison": return Color(hex: "A040A0")
        case "ground": return Color(hex: "E0C068")
        case "rock": return Color(hex: "B8A038")
        case "bug": return Color(hex: "A8B820")
        case "ghost": return Color(hex: "705898")
        case "steel": return Color(hex: "B8B8D0")
        case "dragon": return Color(hex: "7038F8")
        case "dark": return Color(hex: "705848")
        case "fairy": return Color(hex: "EE99AC")
        default: return .gray
        }
    }
}

// Reusable Section View
struct SectionView<Content: View>: View {
    let title: String
    @ViewBuilder let content: Content

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title)
                .font(.title3)
                .fontWeight(.semibold)
                .padding(.bottom, 2)
            
            VStack(alignment: .leading, spacing: 10) {
                content
            }
            .padding()
            .frame(maxWidth: .infinity, alignment: .leading) // Ensure content inside takes full width
            .background(Color(UIColor.secondarySystemBackground))
            .cornerRadius(10)
        }
    }
}

struct DetailRow: View {
    let label: String
    let value: String

    var body: some View {
        HStack {
            Text(label)
                .fontWeight(.medium) // Slightly less bold than section title
            Spacer()
            Text(value)
                .foregroundColor(.gray)
        }
    }
}

struct StatRow: View {
    let label: String
    let value: Int
    let maxValue: Double // Max possible value for this stat for scaling the bar
    let color: Color

    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            HStack {
                Text(label)
                    .font(.subheadline)
                    .fontWeight(.medium)
                Spacer()
                Text("\(value)")
                    .font(.subheadline)
                    .fontWeight(.semibold)
            }
            ProgressView(value: Double(value), total: maxValue)
                .progressViewStyle(LinearProgressViewStyle(tint: color))
                .frame(height: 8) // Make the bar a bit thicker
        }
    }
}

// Extension to allow Color initialization with hex strings
extension Color {
    init(hex: String) {
        // (Keep your existing hex color extension here)
        let hex = hex.trimmingCharacters(in: CharacterSet.alphanumerics.inverted)
        var int: UInt64 = 0
        Scanner(string: hex).scanHexInt64(&int)
        let a, r, g, b: UInt64
        switch hex.count {
        case 3: (a, r, g, b) = (255, (int >> 8) * 17, (int >> 4 & 0xF) * 17, (int & 0xF) * 17)
        case 6: (a, r, g, b) = (255, int >> 16, int >> 8 & 0xFF, int & 0xFF)
        case 8: (a, r, g, b) = (int >> 24, int >> 16 & 0xFF, int >> 8 & 0xFF, int & 0xFF)
        default:(a, r, g, b) = (255, 0, 0, 0)
        }
        self.init(.sRGB, red: Double(r) / 255, green: Double(g) / 255, blue: Double(b) / 255, opacity: Double(a) / 255)
    }
}

struct ContentView_Previews: PreviewProvider {
    static var previews: some View {
        ContentView()
    }
}
