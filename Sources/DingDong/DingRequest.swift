import Foundation

enum DingSound: String, Codable, Equatable, CaseIterable {
    case `default`
    case joy
    case levelUp
    case taDa
    case bubble
    case coin
    case fanfare
    case arcade
    case bloom
    case sunrise
    case popcorn
    case glimmer
    case rocket
    case confetti
    case marimba
    case candy
    case sparkle
    case success
    case celebrate
    case random
    case custom
    case system
    case muted

    static var apiValues: [String] {
        allCases.map(\.rawValue)
    }
}

struct DingRequest: Codable, Equatable {
    var message: String
    var source: String?
    var sound: DingSound
    var flashCount: Int

    init(message: String = "Task complete", source: String? = nil, sound: DingSound = .default, flashCount: Int = 8) {
        self.message = message
        self.source = source
        self.sound = sound
        self.flashCount = flashCount
    }
}

enum DingRequestParser {
    static func parse(_ data: Data?) throws -> DingRequest {
        guard let data, !data.isEmpty else {
            return DingRequest()
        }

        let decoder = JSONDecoder()
        let payload = try decoder.decode(PartialDingRequest.self, from: data)

        return DingRequest(
            message: payload.message?.trimmingCharacters(in: .whitespacesAndNewlines).nilIfEmpty ?? "Task complete",
            source: payload.source?.trimmingCharacters(in: .whitespacesAndNewlines).nilIfEmpty,
            sound: payload.sound ?? .default,
            flashCount: min(max(payload.flashCount ?? 8, 2), 30)
        )
    }
}

private struct PartialDingRequest: Codable {
    var message: String?
    var source: String?
    var sound: DingSound?
    var flashCount: Int?
}

private extension String {
    var nilIfEmpty: String? {
        isEmpty ? nil : self
    }
}
