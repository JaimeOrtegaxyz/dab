import AppKit
import AVFoundation
import CoreVideo
import Foundation

enum EncodeError: Error, CustomStringConvertible {
    case usage
    case noFrames
    case imageLoad(String)
    case pixelBuffer
    case context
    case append(Int, String)

    var description: String {
        switch self {
        case .usage:
            return "usage: swift encode_image_sequence.swift <frame-dir> <fps> <output.mp4>"
        case .noFrames:
            return "no frame_*.jpg images found"
        case .imageLoad(let path):
            return "could not load frame: \(path)"
        case .pixelBuffer:
            return "could not create a video pixel buffer"
        case .context:
            return "could not create a drawing context"
        case .append(let index, let detail):
            return "could not append frame \(index): \(detail)"
        }
    }
}

func cgImage(at url: URL) throws -> CGImage {
    guard let image = NSImage(contentsOf: url) else {
        throw EncodeError.imageLoad(url.path)
    }
    var rect = NSRect(origin: .zero, size: image.size)
    guard let result = image.cgImage(forProposedRect: &rect, context: nil, hints: nil) else {
        throw EncodeError.imageLoad(url.path)
    }
    return result
}

func pixelBuffer(from image: CGImage, width: Int, height: Int, pool: CVPixelBufferPool) throws -> CVPixelBuffer {
    var maybeBuffer: CVPixelBuffer?
    guard CVPixelBufferPoolCreatePixelBuffer(nil, pool, &maybeBuffer) == kCVReturnSuccess,
          let buffer = maybeBuffer else {
        throw EncodeError.pixelBuffer
    }

    CVPixelBufferLockBaseAddress(buffer, [])
    defer { CVPixelBufferUnlockBaseAddress(buffer, []) }

    guard let base = CVPixelBufferGetBaseAddress(buffer) else {
        throw EncodeError.pixelBuffer
    }

    let colorSpace = CGColorSpaceCreateDeviceRGB()
    let bitmapInfo = CGBitmapInfo.byteOrder32Little.rawValue |
        CGImageAlphaInfo.premultipliedFirst.rawValue
    guard let context = CGContext(
        data: base,
        width: width,
        height: height,
        bitsPerComponent: 8,
        bytesPerRow: CVPixelBufferGetBytesPerRow(buffer),
        space: colorSpace,
        bitmapInfo: bitmapInfo
    ) else {
        throw EncodeError.context
    }

    context.setFillColor(CGColor.black)
    context.fill(CGRect(x: 0, y: 0, width: width, height: height))
    context.draw(image, in: CGRect(x: 0, y: 0, width: width, height: height))
    return buffer
}

func encode() throws {
    guard CommandLine.arguments.count == 4,
          let fps = Int32(CommandLine.arguments[2]),
          fps > 0 else {
        throw EncodeError.usage
    }

    let frameDirectory = URL(fileURLWithPath: CommandLine.arguments[1], isDirectory: true)
    let outputURL = URL(fileURLWithPath: CommandLine.arguments[3])
    let files = try FileManager.default.contentsOfDirectory(
        at: frameDirectory,
        includingPropertiesForKeys: nil,
        options: [.skipsHiddenFiles]
    ).filter { $0.lastPathComponent.hasPrefix("frame_") && $0.pathExtension.lowercased() == "jpg" }
     .sorted { $0.lastPathComponent < $1.lastPathComponent }

    guard !files.isEmpty else { throw EncodeError.noFrames }

    let width = 720
    let height = 1280
    try? FileManager.default.removeItem(at: outputURL)

    let writer = try AVAssetWriter(outputURL: outputURL, fileType: .mp4)
    let settings: [String: Any] = [
        AVVideoCodecKey: AVVideoCodecType.h264,
        AVVideoWidthKey: width,
        AVVideoHeightKey: height,
        AVVideoCompressionPropertiesKey: [
            AVVideoAverageBitRateKey: 4_000_000,
            AVVideoProfileLevelKey: AVVideoProfileLevelH264HighAutoLevel
        ]
    ]
    let input = AVAssetWriterInput(mediaType: .video, outputSettings: settings)
    input.expectsMediaDataInRealTime = false

    let attributes: [String: Any] = [
        kCVPixelBufferPixelFormatTypeKey as String: kCVPixelFormatType_32BGRA,
        kCVPixelBufferWidthKey as String: width,
        kCVPixelBufferHeightKey as String: height,
        kCVPixelBufferCGImageCompatibilityKey as String: true,
        kCVPixelBufferCGBitmapContextCompatibilityKey as String: true
    ]
    let adaptor = AVAssetWriterInputPixelBufferAdaptor(
        assetWriterInput: input,
        sourcePixelBufferAttributes: attributes
    )

    guard writer.canAdd(input) else {
        throw EncodeError.append(0, "writer rejected the video input")
    }
    writer.add(input)
    writer.startWriting()
    writer.startSession(atSourceTime: .zero)

    guard let pool = adaptor.pixelBufferPool else {
        throw EncodeError.pixelBuffer
    }

    for (index, file) in files.enumerated() {
        while !input.isReadyForMoreMediaData {
            Thread.sleep(forTimeInterval: 0.002)
        }
        let image = try cgImage(at: file)
        let buffer = try pixelBuffer(from: image, width: width, height: height, pool: pool)
        let time = CMTime(value: CMTimeValue(index), timescale: fps)
        if !adaptor.append(buffer, withPresentationTime: time) {
            throw EncodeError.append(index, writer.error?.localizedDescription ?? "unknown writer error")
        }
    }

    input.markAsFinished()
    let semaphore = DispatchSemaphore(value: 0)
    writer.finishWriting { semaphore.signal() }
    semaphore.wait()

    if writer.status != .completed {
        throw EncodeError.append(files.count, writer.error?.localizedDescription ?? "writer did not complete")
    }
}

do {
    try encode()
} catch {
    FileHandle.standardError.write(Data("\(error)\n".utf8))
    exit(1)
}
