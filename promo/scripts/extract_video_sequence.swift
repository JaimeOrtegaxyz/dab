import AVFoundation
import AppKit
import Foundation

enum SequenceError: Error, CustomStringConvertible {
    case usage
    case image(String)

    var description: String {
        switch self {
        case .usage:
            return "usage: swift extract_video_sequence.swift <input.mp4> <output-dir> <start-seconds> <duration-seconds> <fps>"
        case .image(let detail):
            return detail
        }
    }
}

func writeJPEG(_ image: CGImage, to url: URL) throws {
    let bitmap = NSBitmapImageRep(cgImage: image)
    guard let data = bitmap.representation(using: .jpeg, properties: [.compressionFactor: 0.94]) else {
        throw SequenceError.image("could not encode \(url.lastPathComponent)")
    }
    try data.write(to: url, options: .atomic)
}

func run() throws {
    guard CommandLine.arguments.count == 6,
          let start = Double(CommandLine.arguments[3]),
          let duration = Double(CommandLine.arguments[4]),
          let fps = Int(CommandLine.arguments[5]),
          start >= 0,
          duration > 0,
          fps > 0 else {
        throw SequenceError.usage
    }

    let input = URL(fileURLWithPath: CommandLine.arguments[1])
    let output = URL(fileURLWithPath: CommandLine.arguments[2], isDirectory: true)
    try FileManager.default.createDirectory(at: output, withIntermediateDirectories: true)

    let asset = AVURLAsset(url: input)
    let generator = AVAssetImageGenerator(asset: asset)
    generator.appliesPreferredTrackTransform = true
    let tolerance = CMTime(seconds: 1.0 / Double(fps * 3), preferredTimescale: 6000)
    generator.requestedTimeToleranceBefore = tolerance
    generator.requestedTimeToleranceAfter = tolerance

    let frameCount = Int((duration * Double(fps)).rounded())
    for index in 0..<frameCount {
        let seconds = start + Double(index) / Double(fps)
        let time = CMTime(seconds: seconds, preferredTimescale: 6000)
        var actual = CMTime.zero
        let image = try generator.copyCGImage(at: time, actualTime: &actual)
        let filename = String(format: "frame_%05d.jpg", index)
        try writeJPEG(image, to: output.appendingPathComponent(filename))
    }
}

do {
    try run()
} catch {
    FileHandle.standardError.write(Data("\(error)\n".utf8))
    exit(1)
}
