//
//  SpotifyLyricsManager.swift
//  koffie
//
//  Created by charles thompson on 5/8/24.
//

import Foundation

class SpotifyLyricsManager {
    static let shared = SpotifyLyricsManager()
    
    private let spDcCookie = SpotifyConfig.spDcCookie
    
    struct SpotifySearchResponse: Codable {
        let tracks: Tracks
    }
    
    struct Tracks: Codable {
        let items: [TrackItem]
    }
    
    struct TrackItem: Codable {
        let id: String
        let album: Album
    }
    
    struct Album: Codable {
        let name: String
    }
    
    private struct SpotifyTokenResponse: Codable {
        let accessToken: String?
    }
    
    func fetchSong(song: String, artist: String, completion: @escaping (Song?, Error?) -> Void) {
        fetchSpotifyToken { [weak self] accessToken in
            guard let self = self, let accessToken = accessToken else {
                completion(nil, NSError(domain: "Token Error", code: -1, userInfo: [NSLocalizedDescriptionKey: "Failed to obtain access token"]))
                return
            }
            self.fetchTrackId(song: song, artist: artist, accessToken: accessToken) { trackItem in
                guard let trackItem = trackItem else {
                    completion(nil, NSError(domain: "Track ID Error", code: -1, userInfo: [NSLocalizedDescriptionKey: "Failed to obtain track ID"]))
                    return
                }
                self.fetchLyrics(trackId: trackItem.id, accessToken: accessToken) { lyricsData, error in
                    guard let lyricsData = lyricsData, error == nil else {
                        completion(nil, error)
                        return
                    }
                    if let lyrics = lyricsData["lyrics"] as? [String: Any], let lines = lyrics["lines"] as? [[String: Any]] {
                        let lyricLines: [LyricLine] = lines.compactMap { lineDict in
                            guard let startTimeMs = lineDict["startTimeMs"] as? String,
                                  let words = lineDict["words"] as? String else {
                                return nil
                            }
                            return LyricLine(startTimeMs: startTimeMs, words: words)
                        }
                        let song = Song(title: song, artist: artist, album: trackItem.album.name, lyricsLines: lyricLines)
                        completion(song, nil)
                    } else {
                        completion(nil, NSError(domain: "Parsing Error", code: -1, userInfo: [NSLocalizedDescriptionKey: "Failed to parse lyrics data"]))
                    }
                }
            }
        }
    }
    
    private func fetchSpotifyToken(completion: @escaping (String?) -> Void) {
        let tokenUrl = "https://open.spotify.com/get_access_token?reason=transport&productType=web_player"
        guard let url = URL(string: tokenUrl) else {
            completion(nil)
            return
        }
        
        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        request.setValue("sp_dc=\(spDcCookie);", forHTTPHeaderField: "Cookie")
        request.setValue("Mozilla/5.0 (X11; Linux x86_64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/101.0.0.0 Safari/537.36", forHTTPHeaderField: "User-Agent")
        request.setValue("WebPlayer", forHTTPHeaderField: "App-platform")
        request.setValue("text/html; charset=utf-8", forHTTPHeaderField: "Content-Type")
        
        let sessionConfig = URLSessionConfiguration.ephemeral
        let session = URLSession(configuration: sessionConfig)
        
        session.dataTask(with: request) { data, response, error in
            guard let data = data, error == nil else {
                print("Failed to fetch token:", error?.localizedDescription ?? "Unknown error")
                completion(nil)
                return
            }
            
            let tokenResponse = try? JSONDecoder().decode(SpotifyTokenResponse.self, from: data)
            if let accessToken = tokenResponse?.accessToken {
                completion(accessToken)
            } else {
                print("Access token is missing or invalid")
                completion(nil)
            }
        }.resume()
    }
    
    private func fetchTrackId(song: String, artist: String, accessToken: String, completion: @escaping (TrackItem?) -> Void) {
        let query = "track:\(song) artist:\(artist)".addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? ""
        let urlStr = "https://api.spotify.com/v1/search?q=\(query)&type=track&limit=1"
        
        guard let url = URL(string: urlStr) else {
            print("Invalid URL")
            completion(nil)
            return
        }
        
        var request = URLRequest(url: url)
        request.setValue("Bearer \(accessToken)", forHTTPHeaderField: "Authorization")
        request.httpMethod = "GET"
        
        let task = URLSession.shared.dataTask(with: request) { data, response, error in
            guard let data = data, error == nil else {
                print("Failed to fetch track ID: \(error?.localizedDescription ?? "Unknown error")")
                completion(nil)
                return
            }
            
            if let json = try? JSONDecoder().decode(SpotifySearchResponse.self, from: data),
               let trackItem = json.tracks.items.first {
                completion(trackItem)
            } else {
                print("No track found or failed to parse response")
                completion(nil)
            }
        }
        task.resume()
    }
    
    private func fetchLyrics(trackId: String, accessToken: String, completion: @escaping ([String: Any]?, Error?) -> Void) {
        let lyricsUrl = "https://spclient.wg.spotify.com/color-lyrics/v2/track/\(trackId)?format=json&market=from_token"
        guard let url = URL(string: lyricsUrl) else {
            completion(nil, NSError(domain: "URL Error", code: -1, userInfo: [NSLocalizedDescriptionKey: "Invalid lyrics URL"]))
            return
        }
        
        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        request.setValue("Mozilla/5.0 (X11; Linux x86_64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/101.0.0.0 Safari/537.36", forHTTPHeaderField: "User-Agent")
        request.setValue("WebPlayer", forHTTPHeaderField: "App-platform")
        request.setValue("Bearer \(accessToken)", forHTTPHeaderField: "Authorization")
        request.setValue("text/html; charset=utf-8", forHTTPHeaderField: "Content-Type")
        
        let session = URLSession(configuration: .ephemeral)
        session.dataTask(with: request) { data, response, error in
            if let error = error {
                print("Error fetching lyrics: \(error.localizedDescription)")
                completion(nil, error)
                return
            }
            
            guard let httpResponse = response as? HTTPURLResponse else {
                print("Invalid response object")
                completion(nil, NSError(domain: "Invalid Response", code: -1, userInfo: [NSLocalizedDescriptionKey: "Failed to get HTTP response"]))
                return
            }
            
            guard (200...299).contains(httpResponse.statusCode) else {
                print("HTTP Error: \(httpResponse.statusCode)")
                completion(nil, NSError(domain: "HTTP Error", code: httpResponse.statusCode, userInfo: [NSLocalizedDescriptionKey: "HTTP status code: \(httpResponse.statusCode)"]))
                return
            }
            
            guard let data = data else {
                print("No data received")
                completion(nil, NSError(domain: "No Data", code: -1, userInfo: [NSLocalizedDescriptionKey: "No data received from server"]))
                return
            }
            
            do {
                if let jsonObject = try JSONSerialization.jsonObject(with: data) as? [String: Any] {
                    print("Lyrics JSON: \(jsonObject)")
                    completion(jsonObject, nil)
                } else {
                    print("Failed to parse JSON")
                    completion(nil, NSError(domain: "JSON Parsing Error", code: -1, userInfo: [NSLocalizedDescriptionKey: "Failed to parse JSON response"]))
                }
            } catch {
                print("Error parsing JSON: \(error.localizedDescription)")
                completion(nil, error)
            }
        }.resume()
    }
    
    
}
