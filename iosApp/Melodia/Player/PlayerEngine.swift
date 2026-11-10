import AVFoundation
import Combine
import MediaPlayer

enum PlaybackMode: String, CaseIterable, Identifiable {
    case sequence
    case repeatAll
    case repeatOne
    case shuffle

    var id: String { rawValue }

    var title: String {
        switch self {
        case .sequence: return "顺序播放"
        case .repeatAll: return "列表循环"
        case .repeatOne: return "单曲循环"
        case .shuffle: return "随机播放"
        }
    }

    var icon: String {
        switch self {
        case .sequence: return "arrow.right"
        case .repeatAll: return "repeat"
        case .repeatOne: return "repeat.1"
        case .shuffle: return "shuffle"
        }
    }

    var next: PlaybackMode {
        switch self {
        case .sequence: return .repeatAll
        case .repeatAll: return .repeatOne
        case .repeatOne: return .shuffle
        case .shuffle: return .sequence
        }
    }
}

enum AudioQuality: String, CaseIterable, Identifiable {
    case standard
    case higher
    case exhigh
    case lossless

    var id: String { rawValue }

    var title: String {
        switch self {
        case .standard: return "标准"
        case .higher: return "较高"
        case .exhigh: return "极高"
        case .lossless: return "无损"
        }
    }
}

@MainActor
final class PlayerEngine: ObservableObject {
    @Published private(set) var currentTrack: Track?
    @Published private(set) var queue: [Track] = []
    @Published private(set) var currentIndex = 0
    @Published private(set) var isPlaying = false
    @Published private(set) var isLoading = false
    @Published private(set) var currentTime: Double = 0
    @Published private(set) var duration: Double = 0
    @Published private(set) var lyrics: [LyricLine] = []
    @Published private(set) var currentLyricIndex = -1
    @Published private(set) var lyricsLoading = false
    @Published private(set) var lyricsError: String?
    @Published private(set) var playbackMode: PlaybackMode
    @Published private(set) var audioQuality: AudioQuality
    @Published var errorMessage: String?

    private let player = AVPlayer()
    private let client = NeteaseClient.shared
    private var timeObserver: Any?
    private var endObserver: NSObjectProtocol?
    private var interruptionObserver: NSObjectProtocol?
    private var wasPlayingBeforeInterruption = false
    private var loadTask: Task<Void, Never>?
    private let modeKey = "melodia.player.mode"
    private let qualityKey = "melodia.player.quality"

    init() {
        playbackMode = PlaybackMode(rawValue: UserDefaults.standard.string(forKey: modeKey) ?? "") ?? .sequence
        audioQuality = AudioQuality(rawValue: UserDefaults.standard.string(forKey: qualityKey) ?? "") ?? .exhigh
        configureAudioSession()
        configureRemoteCommands()
        installObservers()
        player.actionAtItemEnd = .pause
    }

    var hasNext: Bool { queue.count > 1 }
    var hasPrevious: Bool { queue.count > 1 }

    var currentLyric: LyricLine? {
        guard lyrics.indices.contains(currentLyricIndex) else { return nil }
        return lyrics[currentLyricIndex]
    }

    func play(_ track: Track, queue: [Track]? = nil) {
        let resolvedQueue = (queue?.isEmpty == false ? queue! : [track])
        self.queue = resolvedQueue.contains(where: { $0.id == track.id }) ? resolvedQueue : [track] + resolvedQueue
        currentIndex = self.queue.firstIndex(where: { $0.id == track.id }) ?? 0
        start(track: track)
    }

    func playAll(_ tracks: [Track], startAt index: Int = 0) {
        guard !tracks.isEmpty, tracks.indices.contains(index) else { return }
        queue = tracks
        currentIndex = index
        start(track: tracks[index])
    }

    func playQueue(at index: Int) {
        guard queue.indices.contains(index) else { return }
        currentIndex = index
        start(track: queue[index])
    }

    func togglePlayPause() {
        if isPlaying {
            pause()
        } else {
            resume()
        }
    }

    func resume() {
        guard player.currentItem != nil else { return }
        activateAudioSession()
        player.play()
        isPlaying = true
        updateNowPlayingInfo()
    }

    func pause() {
        player.pause()
        isPlaying = false
        updateNowPlayingInfo()
    }

    func next() {
        advance(automatic: false)
    }

    func previous() {
        if currentTime > 4 {
            seek(to: 0)
            return
        }
        guard !queue.isEmpty else { return }
        if playbackMode == .shuffle, queue.count > 1 {
            var index = currentIndex
            while index == currentIndex {
                index = Int.random(in: 0..<queue.count)
            }
            currentIndex = index
        } else {
            currentIndex = (currentIndex - 1 + queue.count) % queue.count
        }
        start(track: queue[currentIndex])
    }

    func seek(to seconds: Double) {
        guard seconds.isFinite else { return }
        let target = CMTime(seconds: max(0, seconds), preferredTimescale: 600)
        player.seek(to: target, toleranceBefore: .zero, toleranceAfter: .zero)
        currentTime = max(0, seconds)
        updateCurrentLyric()
        updateNowPlayingInfo()
    }

    func togglePlaybackMode() {
        setPlaybackMode(playbackMode.next)
    }

    func setPlaybackMode(_ mode: PlaybackMode) {
        playbackMode = mode
        UserDefaults.standard.set(mode.rawValue, forKey: modeKey)
    }

    func toggleShuffle() {
        setPlaybackMode(playbackMode == .shuffle ? .sequence : .shuffle)
    }

    func toggleRepeat() {
        switch playbackMode {
        case .repeatAll:
            setPlaybackMode(.repeatOne)
        case .repeatOne:
            setPlaybackMode(.repeatAll)
        case .sequence, .shuffle:
            setPlaybackMode(.repeatAll)
        }
    }

    func selectQuality(_ quality: AudioQuality) {
        guard quality != audioQuality else { return }
        audioQuality = quality
        UserDefaults.standard.set(quality.rawValue, forKey: qualityKey)
        if let track = currentTrack {
            start(track: track)
        }
    }

    func refreshAudioSession() {
        configureAudioSession()
        if isPlaying {
            activateAudioSession()
        }
    }

    func clearError() {
        errorMessage = nil
    }

    private func advance(automatic: Bool) {
        guard !queue.isEmpty else { return }

        if automatic, playbackMode == .repeatOne {
            player.seek(to: .zero)
            activateAudioSession()
            player.play()
            isPlaying = true
            currentTime = 0
            updateCurrentLyric()
            return
        }

        let nextIndex: Int
        if playbackMode == .shuffle, queue.count > 1 {
            var index = currentIndex
            while index == currentIndex {
                index = Int.random(in: 0..<queue.count)
            }
            nextIndex = index
        } else if currentIndex + 1 < queue.count {
            nextIndex = currentIndex + 1
        } else if automatic, playbackMode == .sequence {
            pause()
            return
        } else {
            nextIndex = 0
        }

        currentIndex = nextIndex
        start(track: queue[nextIndex])
    }

    private func start(track: Track) {
        loadTask?.cancel()
        currentTrack = track
        currentTime = 0
        duration = Double(track.durationMs) / 1000
        lyrics = []
        currentLyricIndex = -1
        lyricsLoading = true
        lyricsError = nil
        isLoading = true
        errorMessage = nil

        loadTask = Task { [weak self] in
            guard let self else { return }
            await self.load(track: track)
        }
    }

    private func load(track: Track) async {
        do {
            let url = try await client.songURL(id: track.id, level: audioQuality.rawValue)
            guard !Task.isCancelled, currentTrack?.id == track.id else { return }
            let item = AVPlayerItem(url: url)
            player.replaceCurrentItem(with: item)
            activateAudioSession()
            player.play()
            isPlaying = true
            isLoading = false
            updateNowPlayingInfo()
            Task { [weak self] in
                guard let self else { return }
                await self.loadLyrics(songID: track.id)
            }
        } catch {
            guard currentTrack?.id == track.id else { return }
            isLoading = false
            isPlaying = false
            errorMessage = (error as? LocalizedError)?.errorDescription ?? error.localizedDescription
            updateNowPlayingInfo()
        }
    }

    private func loadLyrics(songID: Int64) async {
        do {
            let response = try await client.lyrics(songID: songID)
            guard currentTrack?.id == songID else { return }
            lyrics = LyricParser.parse(response: response)
            lyricsLoading = false
            lyricsError = lyrics.isEmpty ? "暂无可用歌词" : nil
            updateCurrentLyric()
        } catch {
            guard currentTrack?.id == songID else { return }
            lyrics = []
            currentLyricIndex = -1
            lyricsLoading = false
            lyricsError = (error as? LocalizedError)?.errorDescription ?? error.localizedDescription
        }
    }

    private func installObservers() {
        let interval = CMTime(seconds: 0.25, preferredTimescale: 600)
        timeObserver = player.addPeriodicTimeObserver(forInterval: interval, queue: .main) { [weak self] time in
            Task { @MainActor in
                guard let self else { return }
                self.currentTime = max(0, time.seconds)
                if let item = self.player.currentItem {
                    let itemDuration = item.duration.seconds
                    if itemDuration.isFinite, itemDuration > 0 {
                        self.duration = itemDuration
                    }
                }
                self.updateCurrentLyric()
            }
        }

        endObserver = NotificationCenter.default.addObserver(
            forName: .AVPlayerItemDidPlayToEndTime,
            object: nil,
            queue: .main
        ) { [weak self] notification in
            Task { @MainActor in
                guard let self,
                      let item = notification.object as? AVPlayerItem,
                      item === self.player.currentItem else { return }
                self.advance(automatic: true)
            }
        }

        interruptionObserver = NotificationCenter.default.addObserver(
            forName: AVAudioSession.interruptionNotification,
            object: nil,
            queue: .main
        ) { [weak self] notification in
            Task { @MainActor in
                self?.handleAudioInterruption(notification)
            }
        }
    }

    private func updateCurrentLyric() {
        guard !lyrics.isEmpty else {
            currentLyricIndex = -1
            return
        }
        var index = 0
        for (offset, line) in lyrics.enumerated() {
            if line.time <= currentTime + 0.18 {
                index = offset
            } else {
                break
            }
        }
        currentLyricIndex = index
    }

    private func configureAudioSession() {
        let session = AVAudioSession.sharedInstance()
        let mixesWithOthers = UserDefaults.standard.bool(forKey: MelodiaSettings.mixWithOthersKey)
        var options: AVAudioSession.CategoryOptions = [.allowAirPlay, .allowBluetoothA2DP]
        if mixesWithOthers {
            options.insert(.mixWithOthers)
        }
        try? session.setCategory(.playback, mode: .default, options: options)
    }

    private func handleAudioInterruption(_ notification: Notification) {
        guard let info = notification.userInfo,
              let rawType = info[AVAudioSessionInterruptionTypeKey] as? UInt,
              let type = AVAudioSession.InterruptionType(rawValue: rawType) else { return }

        switch type {
        case .began:
            wasPlayingBeforeInterruption = isPlaying
            if isPlaying {
                pause()
            }
        case .ended:
            let rawOption = info[AVAudioSessionInterruptionOptionKey] as? UInt ?? 0
            let shouldResume = AVAudioSession.InterruptionOptions(rawValue: rawOption).contains(.shouldResume)
            let autoResume = UserDefaults.standard.object(forKey: MelodiaSettings.autoResumeKey) == nil
                ? true
                : UserDefaults.standard.bool(forKey: MelodiaSettings.autoResumeKey)
            if shouldResume && autoResume && wasPlayingBeforeInterruption {
                resume()
            }
            wasPlayingBeforeInterruption = false
        @unknown default:
            break
        }
    }

    private func activateAudioSession() {
        try? AVAudioSession.sharedInstance().setActive(true)
    }

    private func updateNowPlayingInfo() {
        guard let track = currentTrack else {
            MPNowPlayingInfoCenter.default().nowPlayingInfo = nil
            return
        }
        var info = [String: Any]()
        info[MPMediaItemPropertyTitle] = track.name
        info[MPMediaItemPropertyArtist] = track.artistText
        info[MPMediaItemPropertyAlbumTitle] = track.albumName
        info[MPMediaItemPropertyPlaybackDuration] = duration
        info[MPNowPlayingInfoPropertyElapsedPlaybackTime] = currentTime
        info[MPNowPlayingInfoPropertyPlaybackRate] = isPlaying ? 1.0 : 0.0
        MPNowPlayingInfoCenter.default().nowPlayingInfo = info
    }

    private func configureRemoteCommands() {
        let center = MPRemoteCommandCenter.shared()
        center.playCommand.isEnabled = true
        center.pauseCommand.isEnabled = true
        center.nextTrackCommand.isEnabled = true
        center.previousTrackCommand.isEnabled = true

        center.playCommand.addTarget { [weak self] _ in
            Task { @MainActor in
                self?.resume()
            }
            return .success
        }
        center.pauseCommand.addTarget { [weak self] _ in
            Task { @MainActor in
                self?.pause()
            }
            return .success
        }
        center.nextTrackCommand.addTarget { [weak self] _ in
            Task { @MainActor in
                self?.next()
            }
            return .success
        }
        center.previousTrackCommand.addTarget { [weak self] _ in
            Task { @MainActor in
                self?.previous()
            }
            return .success
        }
        center.changePlaybackPositionCommand.addTarget { [weak self] event in
            guard let event = event as? MPChangePlaybackPositionCommandEvent else {
                return .commandFailed
            }
            Task { @MainActor in
                self?.seek(to: event.positionTime)
            }
            return .success
        }
    }
}