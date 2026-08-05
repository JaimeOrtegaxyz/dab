import AVFoundation
import Foundation

enum ReplaceError: Error, CustomStringConvertible {
    case usage
    case missing(String)
    case export(String)

    var description: String {
        switch self {
        case .usage:
            return "usage: swift replace_video_audio.swift <source-video.mp4> <mastered-audio.wav> <output.mp4>"
        case .missing(let detail):
            return detail
        case .export(let detail):
            return "export failed: \(detail)"
        }
    }
}

func run() throws {
    guard CommandLine.arguments.count == 4 else { throw ReplaceError.usage }
    let sourceURL = URL(fileURLWithPath: CommandLine.arguments[1])
    let audioURL = URL(fileURLWithPath: CommandLine.arguments[2])
    let outputURL = URL(fileURLWithPath: CommandLine.arguments[3])
    let videoAsset = AVURLAsset(url: sourceURL)
    let audioAsset = AVURLAsset(url: audioURL)
    guard let sourceVideo = videoAsset.tracks(withMediaType: .video).first else {
        throw ReplaceError.missing("source has no video track")
    }
    guard let sourceAudio = audioAsset.tracks(withMediaType: .audio).first else {
        throw ReplaceError.missing("master has no audio track")
    }

    let duration = min(videoAsset.duration, audioAsset.duration)
    let range = CMTimeRange(start: .zero, duration: duration)
    let composition = AVMutableComposition()
    guard let videoTrack = composition.addMutableTrack(withMediaType: .video, preferredTrackID: kCMPersistentTrackID_Invalid),
          let audioTrack = composition.addMutableTrack(withMediaType: .audio, preferredTrackID: kCMPersistentTrackID_Invalid) else {
        throw ReplaceError.export("could not create composition tracks")
    }
    try videoTrack.insertTimeRange(range, of: sourceVideo, at: .zero)
    try audioTrack.insertTimeRange(range, of: sourceAudio, at: .zero)
    videoTrack.preferredTransform = sourceVideo.preferredTransform

    guard let exporter = AVAssetExportSession(asset: composition, presetName: AVAssetExportPresetHighestQuality) else {
        throw ReplaceError.export("could not create export session")
    }
    exporter.outputURL = outputURL
    exporter.outputFileType = .mp4
    exporter.shouldOptimizeForNetworkUse = true
    let semaphore = DispatchSemaphore(value: 0)
    exporter.exportAsynchronously { semaphore.signal() }
    semaphore.wait()
    guard exporter.status == .completed else {
        throw ReplaceError.export(exporter.error?.localizedDescription ?? "unknown export error")
    }
    print(outputURL.path)
    print(String(format: "duration=%.3f", CMTimeGetSeconds(duration)))
}

do {
    try run()
} catch {
    FileHandle.standardError.write(Data("\(error)\n".utf8))
    exit(1)
}
