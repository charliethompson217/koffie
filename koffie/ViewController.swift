//
//  ViewController.swift
//  koffie
//
//  Created by charles thompson on 5/8/24.
//

import UIKit
import ShazamKit
import AVFoundation

class ViewController: UIViewController, SHSessionDelegate, UITableViewDataSource, UITableViewDelegate {
    var session: SHSession!
    var audioEngine = AVAudioEngine()
    var lyricsLines: [LyricLine] = []
    var tableView: UITableView!
    var currentLineIndex: Int = 0
    var timer: Timer?
    var songStartTime: Date?
    var matchOffset: TimeInterval = 0
    
    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = .black
        session = SHSession()
        session.delegate = self
        setupTableView()
        startAudioEngine()
    }
    
    func setupTableView() {
        tableView = UITableView()
        tableView.frame = view.bounds
        tableView.dataSource = self
        tableView.delegate = self
        tableView.register(UITableViewCell.self, forCellReuseIdentifier: "LyricCell")
        view.addSubview(tableView)
    }
    
    func startAudioEngine() {
        let audioInput = audioEngine.inputNode
        let recordingFormat = audioInput.outputFormat(forBus: 0)
        let sampleRate = recordingFormat.sampleRate
        let bufferSize = AVAudioFrameCount(sampleRate * 3) // 3 seconds of audio
        audioInput.installTap(onBus: 0, bufferSize: bufferSize, format: recordingFormat) { (buffer, when) in
            self.session.matchStreamingBuffer(buffer, at: when)
        }
        audioEngine.prepare()
        do {
            try audioEngine.start()
        } catch {
            print("Audio Engine didn't start due to: \(error.localizedDescription)")
        }
    }
    
    func stopAudioEngine() {
        audioEngine.stop()
        audioEngine.inputNode.removeTap(onBus: 0)
    }
    
    func session(_ session: SHSession, didFind match: SHMatch) {
        guard let matchData = match.mediaItems.first else {
            print("No match")
            return
        }
        stopAudioEngine()
        
        SpotifyLyricsManager.shared.fetchLyricsForSong(song: matchData.title ?? "", artist: matchData.artist ?? "") { lyricsLines, error in
            guard let lyricsLines = lyricsLines else {
                return
            }
            self.lyricsLines = lyricsLines
            self.matchOffset = matchData.predictedCurrentMatchOffset
            self.songStartTime = Date()
            DispatchQueue.main.async {
                self.tableView.reloadData()
                self.startTimer()
            }
        }
    }
    
    func session(_ session: SHSession, didNotFindMatchFor signature: SHSignature, error: Error?) {
        print("No match found: \(error?.localizedDescription ?? "Unknown error")")
    }
    
    func startTimer() {
        timer?.invalidate()
        timer = Timer.scheduledTimer(withTimeInterval: 0.5, repeats: true) { _ in
            self.updateCurrentLine()
        }
    }
    
    func updateCurrentLine() {
        guard let startTime = songStartTime else { return }
        let elapsedTime = Date().timeIntervalSince(startTime) + matchOffset
        for (index, line) in lyricsLines.enumerated() {
            if elapsedTime >= TimeInterval(line.startTimeMs) / 1000 {
                currentLineIndex = index
            } else {
                break
            }
        }
        DispatchQueue.main.async {
            self.tableView.reloadData()
            if self.currentLineIndex < self.lyricsLines.count {
                self.tableView.scrollToRow(at: IndexPath(row: self.currentLineIndex, section: 0), at: .middle, animated: true)
            }
        }
    }
    
    // UITableViewDataSource
    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return lyricsLines.count
    }
    
    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(withIdentifier: "LyricCell", for: indexPath)
        let lyricLine = lyricsLines[indexPath.row]
        cell.textLabel?.text = lyricLine.words
        if indexPath.row == currentLineIndex {
            cell.textLabel?.textColor = .yellow
        } else if indexPath.row < currentLineIndex {
            cell.textLabel?.textColor = .white
        } else {
            cell.textLabel?.textColor = .gray
        }
        cell.backgroundColor = .black
        return cell
    }
    
    deinit {
        timer?.invalidate()
    }
}
