//
//  PokeAPIService.swift
//  PokemonFinder
//
//  Created by Student on 5/8/25.
//

import Foundation

enum APIError: Error {
    case invalidURL
    case requestFailed(Error)
    case invalidResponse
    case decodingError(Error)
    case pokemonNotFound
    case speciesDataNotFound
}

class PokeAPIService {
    private let baseURL = "https://pokeapi.co/api/v2/pokemon/"

    func fetchPokemon(nameOrId: String) async throws -> PokemonResponse {
        // Sanitize input: lowercase for names, keep as is for IDs
        let searchTerm = nameOrId.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        guard !searchTerm.isEmpty else {
            throw APIError.pokemonNotFound
        }

        guard let url = URL(string: baseURL + searchTerm) else {
            throw APIError.invalidURL
        }

        var request = URLRequest(url: url)
        request.httpMethod = "GET"

        do {
            let (data, response) = try await URLSession.shared.data(for: request)

            guard let httpResponse = response as? HTTPURLResponse else {
                throw APIError.invalidResponse
            }

            if httpResponse.statusCode == 404 {
                throw APIError.pokemonNotFound
            }

            guard (200...299).contains(httpResponse.statusCode) else {
                throw APIError.invalidResponse
            }
            
            let decoder = JSONDecoder()
            do {
                let pokemonResponse = try decoder.decode(PokemonResponse.self, from: data)
                return pokemonResponse
            } catch {
                print("Decoding PokemonResponse Error: \(error)")
                throw APIError.decodingError(error)
            }

        } catch let error where error is APIError {
            throw error
        } catch {
            print("Request Failed: \(error)")
            throw APIError.requestFailed(error)
        }
    }

    // New function to fetch species data
    func fetchPokemonSpecies(from urlString: String) async throws -> PokemonSpeciesResponse {
        guard let url = URL(string: urlString) else {
            throw APIError.invalidURL
        }

        var request = URLRequest(url: url)
        request.httpMethod = "GET"

        do {
            let (data, response) = try await URLSession.shared.data(for: request)

            guard let httpResponse = response as? HTTPURLResponse else {
                throw APIError.invalidResponse
            }

            if httpResponse.statusCode == 404 {
                throw APIError.speciesDataNotFound
            }

            guard (200...299).contains(httpResponse.statusCode) else {
                throw APIError.invalidResponse
            }

            let decoder = JSONDecoder()
            do {
                let speciesResponse = try decoder.decode(PokemonSpeciesResponse.self, from: data)
                return speciesResponse
            } catch {
                print("Decoding PokemonSpeciesResponse Error: \(error)")
                throw APIError.decodingError(error)
            }
        } catch let error where error is APIError {
            throw error
        } catch {
            throw APIError.requestFailed(error)
        }
    }
}
