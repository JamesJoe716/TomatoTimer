import AVFoundation
import XCTest
@testable import TomatoTimer

final class AudioResourceTests: XCTestCase {
    func testBundledVoiceClipsExistAndArePlayable() throws {
        let bundle = try XCTUnwrap(Self.hostAppBundle)

        for gender in VoiceGender.allCases {
            for resourceName in Self.requiredClipNames {
                let url = try XCTUnwrap(
                    bundle.url(
                        forResource: resourceName,
                        withExtension: "mp3",
                        subdirectory: gender.clipSubdirectory
                    ),
                    "\(gender.rawValue) is missing \(gender.clipSubdirectory)/\(resourceName).mp3"
                )

                let player = try AVAudioPlayer(contentsOf: url)
                XCTAssertGreaterThan(player.duration, 0, "\(url.path) is not a playable audio clip")
            }
        }
    }

    private static var hostAppBundle: Bundle? {
        let probeSubdirectory = VoiceGender.male.clipSubdirectory
        return Bundle.allBundles.first { bundle in
            bundle.url(forResource: "start", withExtension: "mp3", subdirectory: probeSubdirectory) != nil
        }
    }

    private static var requiredClipNames: [String] {
        ["intro", "start", "rest", "resume", "final_minute"]
            + (1...8).map { "enc_\($0)" }
            + stride(from: 5, through: 120, by: 5).map { "effort_\($0)" }
    }
}
