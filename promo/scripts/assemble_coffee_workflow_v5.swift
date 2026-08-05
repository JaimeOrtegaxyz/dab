import AVFoundation
import Foundation

enum AssemblyError: Error, CustomStringConvertible {
    case usage
    case missingTrack(String, String)
    case export(String)

    var description: String {
        switch self {
        case .usage:
            return "usage: swift assemble_coffee_workflow_v5.swift <project-root> <output.mp4>"
        case .missingTrack(let kind, let path):
            return "missing \(kind) track in \(path)"
        case .export(let detail):
            return "export failed: \(detail)"
        }
    }
}

struct Segment {
    let videoPath: String
    let audioPath: String?
    let sourceStart: Double
    let sourceDuration: Double
    let editDuration: Double
}

func time(_ seconds: Double) -> CMTime {
    CMTime(seconds: seconds, preferredTimescale: 6000)
}

func firstTrack(_ asset: AVAsset, type: AVMediaType, path: String) throws -> AVAssetTrack {
    guard let track = asset.tracks(withMediaType: type).first else {
        throw AssemblyError.missingTrack(type.rawValue, path)
    }
    return track
}

func insertSegment(
    _ segment: Segment,
    root: URL,
    videoTrack: AVMutableCompositionTrack,
    audioTrack: AVMutableCompositionTrack?,
    at cursor: CMTime
) throws {
    let videoAsset = AVURLAsset(url: root.appendingPathComponent(segment.videoPath))
    let sourceRange = CMTimeRange(start: time(segment.sourceStart), duration: time(segment.sourceDuration))
    let sourceVideo = try firstTrack(videoAsset, type: .video, path: segment.videoPath)
    try videoTrack.insertTimeRange(sourceRange, of: sourceVideo, at: cursor)
    if let audioPath = segment.audioPath, let audioTrack {
        let audioAsset = AVURLAsset(url: root.appendingPathComponent(audioPath))
        let sourceAudio = try firstTrack(audioAsset, type: .audio, path: audioPath)
        try audioTrack.insertTimeRange(sourceRange, of: sourceAudio, at: cursor)
    }
    if abs(segment.sourceDuration - segment.editDuration) > 0.0001 {
        let inserted = CMTimeRange(start: cursor, duration: time(segment.sourceDuration))
        videoTrack.scaleTimeRange(inserted, toDuration: time(segment.editDuration))
        audioTrack?.scaleTimeRange(inserted, toDuration: time(segment.editDuration))
    }
}

func insertAudio(
    path: String,
    sourceStart: Double,
    duration: Double,
    root: URL,
    track: AVMutableCompositionTrack,
    at cursor: Double
) throws {
    let asset = AVURLAsset(url: root.appendingPathComponent(path))
    let source = try firstTrack(asset, type: .audio, path: path)
    try track.insertTimeRange(
        CMTimeRange(start: time(sourceStart), duration: time(duration)),
        of: source,
        at: time(cursor)
    )
}

func run() throws {
    guard CommandLine.arguments.count == 3 else { throw AssemblyError.usage }
    let root = URL(fileURLWithPath: CommandLine.arguments[1], isDirectory: true)
    let output = URL(fileURLWithPath: CommandLine.arguments[2])

    let segments = [
        Segment(videoPath: "videos/v1-p01-left-hand-wide-captioned-v5.mp4", audioPath: "audio/mastered/v4-left-hand-wide.wav", sourceStart: 0.0, sourceDuration: 4.0, editDuration: 4.0),
        Segment(videoPath: "videos/v1-p02-with-pixels-captioned-v2.mp4", audioPath: "audio/mastered/v2-pass-02.wav", sourceStart: 0.0, sourceDuration: 2.6, editDuration: 2.6),
        Segment(videoPath: "videos/v1-p03-pressure-clerk-smoothed-v1.mp4", audioPath: "audio/mastered/v2-pass-03.wav", sourceStart: 0.0, sourceDuration: 4.0, editDuration: 4.0),
        Segment(videoPath: "videos/runs/cgt-20260805053809-tks5r/video.mp4", audioPath: "audio/mastered/v2-pass-04.wav", sourceStart: 0.0, sourceDuration: 3.2, editDuration: 3.2),
        Segment(videoPath: "videos/runs/cgt-20260805054332-r8r2j/video.mp4", audioPath: "audio/mastered/v2-pass-05.wav", sourceStart: 0.45, sourceDuration: 0.7, editDuration: 0.7),
        Segment(videoPath: "videos/runs/cgt-20260805062958-d69l7/video.mp4", audioPath: "audio/mastered/v3-clean-brick-rain.wav", sourceStart: 0.0, sourceDuration: 3.2, editDuration: 3.2),
        Segment(videoPath: "videos/v1-coffee-shop-pixel-away-v2.mp4", audioPath: nil, sourceStart: 0.0, sourceDuration: 0.7, editDuration: 0.7),
        Segment(videoPath: "videos/dab-brand-outro-v1.mp4", audioPath: nil, sourceStart: 0.0, sourceDuration: 3.2, editDuration: 3.2),
        Segment(videoPath: "videos/dab-brand-outro-hold-v2.mp4", audioPath: nil, sourceStart: 0.0, sourceDuration: 4.4, editDuration: 4.4),
    ]

    let composition = AVMutableComposition()
    guard let videoTrack = composition.addMutableTrack(withMediaType: .video, preferredTrackID: kCMPersistentTrackID_Invalid),
          let contentAudio = composition.addMutableTrack(withMediaType: .audio, preferredTrackID: kCMPersistentTrackID_Invalid),
          let transitionAudio = composition.addMutableTrack(withMediaType: .audio, preferredTrackID: kCMPersistentTrackID_Invalid),
          let outroAudio = composition.addMutableTrack(withMediaType: .audio, preferredTrackID: kCMPersistentTrackID_Invalid),
          let musicAudio = composition.addMutableTrack(withMediaType: .audio, preferredTrackID: kCMPersistentTrackID_Invalid),
          let voiceAudio = composition.addMutableTrack(withMediaType: .audio, preferredTrackID: kCMPersistentTrackID_Invalid) else {
        throw AssemblyError.export("could not create composition tracks")
    }

    var cursor = CMTime.zero
    for (index, segment) in segments.enumerated() {
        try insertSegment(segment, root: root, videoTrack: videoTrack, audioTrack: index < 6 ? contentAudio : nil, at: cursor)
        cursor = CMTimeAdd(cursor, time(segment.editDuration))
    }

    try insertAudio(path: "audio/mastered/v3-clean-brick-rain.wav", sourceStart: 3.2, duration: 0.7, root: root, track: contentAudio, at: 17.7)
    try insertAudio(path: "audio/mastered/v2-transition.wav", sourceStart: 0.0, duration: 0.7, root: root, track: transitionAudio, at: 17.7)
    try insertAudio(path: "audio/mastered/v2-outro.wav", sourceStart: 0.0, duration: 3.2, root: root, track: outroAudio, at: 18.4)
    // Source 19.5 seconds lands exactly on the yellow reveal at video time 18.4.
    try insertAudio(path: "audio/source-user/OHMYGAWD.mp3", sourceStart: 1.1, duration: 26.0, root: root, track: musicAudio, at: 0.0)
    try insertAudio(path: "audio/mastered/v3-fuckyeahpixels.wav", sourceStart: 0.0, duration: 1.88, root: root, track: voiceAudio, at: 19.5)

    let contentParams = AVMutableAudioMixInputParameters(track: contentAudio)
    contentParams.setVolume(0.88, at: .zero)
    let transitionParams = AVMutableAudioMixInputParameters(track: transitionAudio)
    transitionParams.setVolume(0.75, at: time(17.7))
    let outroParams = AVMutableAudioMixInputParameters(track: outroAudio)
    outroParams.setVolume(0.55, at: time(18.4))
    let musicParams = AVMutableAudioMixInputParameters(track: musicAudio)
    musicParams.setVolume(0.30, at: .zero)
    musicParams.setVolumeRamp(fromStartVolume: 0.30, toEndVolume: 0.33, timeRange: CMTimeRange(start: .zero, duration: time(17.7)))
    musicParams.setVolumeRamp(fromStartVolume: 0.33, toEndVolume: 0.48, timeRange: CMTimeRange(start: time(17.7), duration: time(0.7)))
    musicParams.setVolume(0.48, at: time(18.4))
    let voiceParams = AVMutableAudioMixInputParameters(track: voiceAudio)
    voiceParams.setVolume(1.0, at: time(19.5))

    let audioMix = AVMutableAudioMix()
    audioMix.inputParameters = [contentParams, transitionParams, outroParams, musicParams, voiceParams]

    let instruction = AVMutableVideoCompositionInstruction()
    instruction.timeRange = CMTimeRange(start: .zero, duration: cursor)
    let layer = AVMutableVideoCompositionLayerInstruction(assetTrack: videoTrack)
    layer.setTransform(.identity, at: .zero)
    instruction.layerInstructions = [layer]
    let videoComposition = AVMutableVideoComposition()
    videoComposition.renderSize = CGSize(width: 720, height: 1280)
    videoComposition.frameDuration = CMTime(value: 1, timescale: 24)
    videoComposition.instructions = [instruction]

    guard let exporter = AVAssetExportSession(asset: composition, presetName: AVAssetExportPresetHighestQuality) else {
        throw AssemblyError.export("could not create export session")
    }
    exporter.outputURL = output
    exporter.outputFileType = .mp4
    exporter.videoComposition = videoComposition
    exporter.audioMix = audioMix
    exporter.shouldOptimizeForNetworkUse = true
    let semaphore = DispatchSemaphore(value: 0)
    exporter.exportAsynchronously { semaphore.signal() }
    semaphore.wait()
    guard exporter.status == .completed else {
        throw AssemblyError.export(exporter.error?.localizedDescription ?? "unknown export error")
    }
    print(output.path)
    print(String(format: "duration=%.3f", CMTimeGetSeconds(cursor)))
}

do {
    try run()
} catch {
    FileHandle.standardError.write(Data("\(error)\n".utf8))
    exit(1)
}
