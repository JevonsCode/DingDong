import Foundation
import Testing
@testable import DingDong

struct DingRequestTests {
    @Test func emptyBodyUsesDefaults() throws {
        let request = try DingRequestParser.parse(nil)

        #expect(request == DingRequest())
    }

    @Test func jsonBodyOverridesDefaults() throws {
        let data = """
        {"message":"Build finished","source":"Codex","sound":"random","flashCount":12}
        """.data(using: .utf8)

        let request = try DingRequestParser.parse(data)

        #expect(request.message == "Build finished")
        #expect(request.source == "Codex")
        #expect(request.sound == .random)
        #expect(request.flashCount == 12)
    }

    @Test func soundAPIValuesIncludeBuiltInThemes() {
        #expect(DingSound.apiValues == ["default", "joy", "levelUp", "taDa", "bubble", "coin", "fanfare", "arcade", "bloom", "sunrise", "popcorn", "glimmer", "rocket", "confetti", "marimba", "candy", "sparkle", "success", "celebrate", "random", "custom", "system", "muted"])
    }

    @Test func cheerfulChimeBuildsPlayableWAVData() throws {
        let data = try #require(CheerfulChime.data(for: .joy))
        let header = try #require(String(data: data.prefix(4), encoding: .ascii))
        let wave = try #require(String(data: data.dropFirst(8).prefix(4), encoding: .ascii))

        #expect(header == "RIFF")
        #expect(wave == "WAVE")
        #expect(data.count > CheerfulChime.sampleRate / 2)
        #expect(CheerfulChime.data(for: .default) == nil)
    }

    @Test func newHappyChimesBuildPlayableWAVData() throws {
        for sound in [DingSound.taDa, .bubble, .coin, .fanfare, .arcade, .bloom, .sunrise, .popcorn, .glimmer, .rocket, .confetti, .marimba, .candy] {
            let data = try #require(CheerfulChime.data(for: sound))
            let header = try #require(String(data: data.prefix(4), encoding: .ascii))
            let wave = try #require(String(data: data.dropFirst(8).prefix(4), encoding: .ascii))

            #expect(header == "RIFF")
            #expect(wave == "WAVE")
            #expect(data.count > CheerfulChime.sampleRate / 4)
        }
    }

    @Test func flashCountIsClamped() throws {
        let data = """
        {"flashCount":99}
        """.data(using: .utf8)

        let request = try DingRequestParser.parse(data)

        #expect(request.flashCount == 30)
    }

    @Test func blankMessageFallsBackToDefault() throws {
        let data = """
        {"message":"   "}
        """.data(using: .utf8)

        let request = try DingRequestParser.parse(data)

        #expect(request.message == "Task complete")
    }
}
