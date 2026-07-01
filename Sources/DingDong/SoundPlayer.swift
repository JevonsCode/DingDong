import AppKit
import AVFoundation
import Combine
import Foundation

@MainActor
final class SoundPlayer: ObservableObject {
    @Published private(set) var customSoundPath: String?

    private var player: AVAudioPlayer?
    private var chimePlayer: AVAudioPlayer?
    private let customSoundPathKey = "dingdong.customSoundPath"

    init() {
        customSoundPath = UserDefaults.standard.string(forKey: customSoundPathKey)
    }

    func play(_ sound: DingSound) {
        switch sound {
        case .random:
            play(randomCheerfulSound())
        case .muted:
            return
        case .custom:
            if !playCustomSound() {
                playSystemSound()
            }
        case .system:
            playSystemSound()
        case .joy, .levelUp, .taDa, .bubble, .coin, .fanfare, .arcade, .bloom, .sunrise, .popcorn, .glimmer, .rocket, .confetti, .marimba, .candy:
            if !playGeneratedChime(sound) {
                playSequence(.sparkle)
            }
        case .default:
            playSequence(.default)
        case .sparkle:
            playSequence(.sparkle)
        case .success:
            playSequence(.success)
        case .celebrate:
            playSequence(.celebrate)
        }
    }

    func chooseCustomSound() {
        let panel = NSOpenPanel()
        panel.allowedContentTypes = [.audio]
        panel.canChooseDirectories = false
        panel.canChooseFiles = true
        panel.allowsMultipleSelection = false

        if panel.runModal() == .OK, let url = panel.url {
            customSoundPath = url.path
            UserDefaults.standard.set(url.path, forKey: customSoundPathKey)
        }
    }

    func clearCustomSound() {
        customSoundPath = nil
        UserDefaults.standard.removeObject(forKey: customSoundPathKey)
    }

    @discardableResult
    private func playCustomSound() -> Bool {
        guard let customSoundPath else {
            return false
        }

        let url = URL(fileURLWithPath: customSoundPath)
        guard FileManager.default.fileExists(atPath: url.path) else {
            return false
        }

        do {
            player = try AVAudioPlayer(contentsOf: url)
            player?.prepareToPlay()
            return player?.play() == true
        } catch {
            return false
        }
    }

    @discardableResult
    private func playSystemSound() -> Bool {
        NSSound(named: "Glass")?.play() == true
    }

    @discardableResult
    private func playGeneratedChime(_ sound: DingSound) -> Bool {
        guard let data = CheerfulChime.data(for: sound) else {
            return false
        }

        do {
            chimePlayer = try AVAudioPlayer(data: data)
            chimePlayer?.prepareToPlay()
            return chimePlayer?.play() == true
        } catch {
            return false
        }
    }

    private func playSequence(_ sound: DingSound) {
        let sequence: [(String, TimeInterval)] = switch sound {
        case .default:
            [
                ("Pop", 0),
                ("Ping", 0.16),
                ("Glass", 0.34)
            ]
        case .sparkle:
            [
                ("Tink", 0),
                ("Pop", 0.11),
                ("Ping", 0.23),
                ("Glass", 0.38)
            ]
        case .success:
            [
                ("Hero", 0),
                ("Ping", 0.2),
                ("Glass", 0.36)
            ]
        case .celebrate:
            [
                ("Pop", 0),
                ("Tink", 0.1),
                ("Ping", 0.2),
                ("Pop", 0.31),
                ("Glass", 0.46)
            ]
        case .joy, .levelUp, .taDa, .bubble, .coin, .fanfare, .arcade, .bloom, .sunrise, .popcorn, .glimmer, .rocket, .confetti, .marimba, .candy, .random, .custom, .system, .muted:
            []
        }

        let fallbackSequence = sequence.isEmpty ? [
            ("Pop", 0),
            ("Ping", 0.16),
            ("Glass", 0.34)
        ] : sequence

        for (name, delay) in fallbackSequence {
            DispatchQueue.main.asyncAfter(deadline: .now() + delay) {
                NSSound(named: name)?.play()
            }
        }
    }

    private func randomCheerfulSound() -> DingSound {
        [
            .sparkle,
            .success,
            .celebrate
        ].randomElement() ?? .sparkle
    }
}
