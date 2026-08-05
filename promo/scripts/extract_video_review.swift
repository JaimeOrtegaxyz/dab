import AVFoundation
import AppKit
import Foundation

enum ReviewError: Error, CustomStringConvertible {
    case usage
    case image(String)

    var description: String {
        switch self {
        case .usage:
            return "usage: swift extract_video_review.swift <input.mp4> <output-dir> <sample-count>"
        case .image(let detail):
            return detail
        }
    }
}

func writeJPEG(_ image: CGImage, to url: URL) throws {
    let bitmap = NSBitmapImageRep(cgImage: image)
    guard let data = bitmap.representation(using: .jpeg, properties: [.compressionFactor: 0.9]) else {
        throw ReviewError.image("could not encode \(url.lastPathComponent)")
    }
    try data.write(to: url, options: .atomic)
}

func run() throws {
    guard CommandLine.arguments.count == 4,
          let sampleCount = Int(CommandLine.arguments[3]),
          sampleCount >= 2 else {
        throw ReviewError.usage
    }

    let input = URL(fileURLWithPath: CommandLine.arguments[1])
    let output = URL(fileURLWithPath: CommandLine.arguments[2], isDirectory: true)
    try FileManager.default.createDirectory(at: output, withIntermediateDirectories: true)

    let asset = AVURLAsset(url: input)
    let seconds = CMTimeGetSeconds(asset.duration)
    let videoTrack = asset.tracks(withMediaType: .video).first
    let audioTrack = asset.tracks(withMediaType: .audio).first
    let size = videoTrack?.naturalSize ?? .zero
    let fps = videoTrack?.nominalFrameRate ?? 0
    let audioDescription = audioTrack == nil ? "none" : "present"
    print(
        "\(input.lastPathComponent): duration=\(String(format: "%.3f", seconds)) " +
        "size=\(Int(abs(size.width)))x\(Int(abs(size.height))) fps=\(String(format: "%.3f", fps)) " +
        "audio=\(audioDescription)"
    )

    let generator = AVAssetImageGenerator(asset: asset)
    generator.appliesPreferredTrackTransform = true
    generator.requestedTimeToleranceBefore = CMTime(seconds: 0.1, preferredTimescale: 600)
    generator.requestedTimeToleranceAfter = CMTime(seconds: 0.1, preferredTimescale: 600)

    for index in 0..<sampleCount {
        let fraction = Double(index) / Double(sampleCount - 1)
        let sampleSeconds = min(max(0.04, seconds * fraction), max(0.04, seconds - 0.04))
        let time = CMTime(seconds: sampleSeconds, preferredTimescale: 600)
        var actual = CMTime.zero
        let image = try generator.copyCGImage(at: time, actualTime: &actual)
        let filename = String(format: "frame_%02d_%05.2fs.jpg", index, CMTimeGetSeconds(actual))
        try writeJPEG(image, to: output.appendingPathComponent(filename))
    }
}

do {
    try run()
} catch {
    FileHandle.standardError.write(Data("\(error)\n".utf8))
    exit(1)
}
