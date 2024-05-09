//
//  LyricLine.swift
//  koffie
//
//  Created by charles thompson on 5/9/24.
//

import Foundation

class LyricLine {
    let startTimeMs: Int
    let words: String
    
    init(startTimeMs: String, words: String) {
        self.startTimeMs = Int(startTimeMs) ?? 0
        self.words = words
    }
}
