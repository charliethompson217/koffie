//
//  Song.swift
//  koffie
//
//  Created by charles thompson on 5/11/24.
//

import Foundation

class Song {
    var title: String
    var artist: String
    var album: String?
    var lyricsLines: [LyricLine]

    init(title: String, artist: String, album: String? = nil, lyricsLines: [LyricLine]) {
        self.title = title
        self.artist = artist
        self.album = album
        self.lyricsLines = lyricsLines
    }
}
