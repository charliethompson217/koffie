//
//  ViewController.swift
//  koffie
//
//  Created by charles thompson on 5/8/24.
//

import UIKit
import ShazamKit
import AVFoundation

class ViewController: UIViewController, SHSessionDelegate, UITableViewDataSource, UITableViewDelegate, UIScrollViewDelegate {
    var session: SHSession!
    var audioEngine = AVAudioEngine()
    var lyricsLines: [LyricLine] = []
    var tableView: UITableView!
    var currentLineIndex: Int = 0
    var timer: Timer?
    var songStartTime: Date?
    var matchOffset: TimeInterval = 0
    
    var songTitle: String?
    var songArtist: String?
    var songAlbum: String?
    var albumArt: UIImage?
    var loadingIndicator: UIView!
    var albumArtImageView: UIImageView!
    
    override func viewDidLoad() {
        super.viewDidLoad()
        setNeedsStatusBarAppearanceUpdate()
        setNeedsUpdateOfHomeIndicatorAutoHidden()
        view.backgroundColor = .black
        session = SHSession()
        session.delegate = self
        setupTableView()
        setupLoadingIndicator()
        setupTableHeaderView()
        startAudioEngine()
    }
    
    override var prefersStatusBarHidden: Bool {
        return true
    }
    
    override var preferredScreenEdgesDeferringSystemGestures: UIRectEdge {
        return [.bottom]
    }
    
    override var prefersHomeIndicatorAutoHidden: Bool {
        return true
    }
    
    func setupTableView() {
        tableView = UITableView()
        tableView.frame = view.bounds
        tableView.dataSource = self
        tableView.delegate = self
        tableView.register(UITableViewCell.self, forCellReuseIdentifier: "LyricCell")
        tableView.rowHeight = UITableView.automaticDimension
        tableView.estimatedRowHeight = 44
        tableView.alwaysBounceVertical = true
        tableView.separatorStyle = .none
        view.addSubview(tableView)
    }
    
    func setupLoadingIndicator() {
        loadingIndicator = UIView(frame: CGRect(x: 0, y: 0, width: 100, height: 100))
        loadingIndicator.backgroundColor = .clear
        loadingIndicator.center = view.center
        
        let animation = CABasicAnimation(keyPath: "transform.rotation")
        animation.toValue = NSNumber(value: Double.pi * 2)
        animation.duration = 1
        animation.isCumulative = true
        animation.repeatCount = Float.greatestFiniteMagnitude
        
        let spinningLayer = CALayer()
        spinningLayer.frame = loadingIndicator.bounds
        spinningLayer.contents = UIImage(named: "spinner")?.cgImage
        spinningLayer.add(animation, forKey: "rotationAnimation")
        
        loadingIndicator.layer.addSublayer(spinningLayer)
        view.addSubview(loadingIndicator)
    }
    
    func setupTableHeaderView() {
        albumArtImageView = UIImageView()
        albumArtImageView.frame = CGRect(x: 0, y: 0, width: view.bounds.width, height: 300)
        albumArtImageView.contentMode = .scaleAspectFit
        let headerView = UIView(frame: albumArtImageView.bounds)
        headerView.addSubview(albumArtImageView)
        tableView.tableHeaderView = headerView
    }
    
    func scrollViewDidScroll(_ scrollView: UIScrollView) {
        let scrollThreshold: CGFloat = -200
        if scrollView.contentOffset.y <= scrollThreshold {
            reScan()
        }
    }
    
    func startAudioEngine() {
        loadingIndicator.isHidden = false
        albumArtImageView.image =  UIImage(systemName: "cup.and.saucer.fill")
        albumArtImageView.tintColor = .white
        
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
    
    func reScan() {
        stopAudioEngine()
        lyricsLines.removeAll()
        songTitle = nil
        songArtist = nil
        songAlbum = nil
        albumArtImageView.image = UIImage(systemName: "cup.and.saucer.fill")
        tableView.reloadData()
        startAudioEngine()
    }
    
    func session(_ session: SHSession, didFind match: SHMatch) {
        guard let matchData = match.mediaItems.first else {
            print("No match")
            return
        }
        stopAudioEngine()
        
        songTitle = matchData.title
        songArtist = matchData.artist
        if let imageUrl = matchData.artworkURL {
            DispatchQueue.global().async {
                if let data = try? Data(contentsOf: imageUrl), let image = UIImage(data: data) {
                    DispatchQueue.main.async {
                        self.albumArtImageView.image = image
                    }
                }
            }
        }
        
        SpotifyLyricsManager.shared.fetchSong(song: matchData.title ?? "", artist: matchData.artist ?? "") { song, error in
            DispatchQueue.main.async {
                self.loadingIndicator.isHidden = true
            }
            guard let song = song else {
                print("Failed to fetch song: \(error?.localizedDescription ?? "Unknown error")")
                return
            }
            self.lyricsLines = song.lyricsLines
            self.songAlbum = song.album
            self.matchOffset = matchData.predictedCurrentMatchOffset
            self.songStartTime = Date()
            DispatchQueue.main.async {
                self.tableView.reloadData()
                self.startTimer()
            }
        }
    }
    
    func session(_ session: SHSession, didNotFindMatchFor signature: SHSignature, error: Error?) {
        DispatchQueue.main.async {
            self.loadingIndicator.isHidden = true
        }
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
        }
    }
    
    
    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return lyricsLines.count + 3
    }
    
    

    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(withIdentifier: "LyricCell", for: indexPath)
        cell.contentView.subviews.forEach { $0.removeFromSuperview() } // Remove old subviews

        let iconSize: CGFloat = 24
        let spacing: CGFloat = 8
        let label = UILabel()
        label.textColor = .white
        label.textAlignment = .center
        label.translatesAutoresizingMaskIntoConstraints = false
        
        let iconImageView = UIImageView()
        iconImageView.contentMode = .scaleAspectFit
        iconImageView.tintColor = .white
        iconImageView.translatesAutoresizingMaskIntoConstraints = false

        if indexPath.row == 0 {
            label.text = songTitle ?? ""
            iconImageView.image = UIImage(systemName: "music.note")
            iconImageView.tintColor = .white
            if songTitle != nil{
                iconImageView.tintColor = .systemBlue
            }
        } else if indexPath.row == 1 {
            label.text = songArtist ?? ""
            iconImageView.image = UIImage(systemName: "person")
            iconImageView.tintColor = .white
            if songArtist != nil{
                iconImageView.tintColor = .systemBlue
            }
        } else if indexPath.row == 2 {
            label.text = songAlbum ?? ""
            iconImageView.image = UIImage(systemName: "opticaldisc.fill")
            iconImageView.tintColor = .white
            if songAlbum != nil{
                iconImageView.tintColor = .systemBlue
            }
        
        } else {
            let lyricLine = lyricsLines[indexPath.row - 3]
            label.text = lyricLine.words
            label.textAlignment = .left
            label.numberOfLines = 0
            label.lineBreakMode = .byWordWrapping
            if indexPath.row - 3 == currentLineIndex {
                label.textColor = .yellow
            } else if indexPath.row - 3 < currentLineIndex {
                label.textColor = .white
            } else {
                label.textColor = .gray
            }
            cell.contentView.addSubview(label)
            NSLayoutConstraint.activate([
                label.leadingAnchor.constraint(equalTo: cell.contentView.leadingAnchor, constant: 16),
                label.trailingAnchor.constraint(equalTo: cell.contentView.trailingAnchor, constant: -16),
                label.topAnchor.constraint(equalTo: cell.contentView.topAnchor, constant: 8),
                label.bottomAnchor.constraint(equalTo: cell.contentView.bottomAnchor, constant: -8)
            ])
            cell.backgroundColor = .black
            return cell
        }
        
        let stackView = UIStackView(arrangedSubviews: [iconImageView, label])
        stackView.axis = .horizontal
        stackView.spacing = spacing
        stackView.alignment = .center
        stackView.translatesAutoresizingMaskIntoConstraints = false
        cell.contentView.addSubview(stackView)
        
        NSLayoutConstraint.activate([
            stackView.centerXAnchor.constraint(equalTo: cell.contentView.centerXAnchor),
            stackView.centerYAnchor.constraint(equalTo: cell.contentView.centerYAnchor),
            iconImageView.widthAnchor.constraint(equalToConstant: iconSize),
            iconImageView.heightAnchor.constraint(equalToConstant: iconSize)
        ])
        
        cell.backgroundColor = .black
        return cell
    }


    
    func tableView(_ tableView: UITableView, heightForRowAt indexPath: IndexPath) -> CGFloat {
        return UITableView.automaticDimension
    }
    
    deinit {
        timer?.invalidate()
    }
}
