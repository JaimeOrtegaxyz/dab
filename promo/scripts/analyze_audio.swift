import AVFoundation
import Foundation

enum AudioAnalysisError: Error, CustomStringConvertible {
    case usage
    case buffer

    var description: String {
        switch self {
        case .usage:
            return "usage: swift analyze_audio.swift <audio-file> [audio-file ...]"
        case .buffer:
            return "could not allocate audio buffer"
        }
    }
}

func analyze(_ path: String) throws {
    let file = try AVAudioFile(forReading: URL(fileURLWithPath: path))
    let format = file.processingFormat
    guard let buffer = AVAudioPCMBuffer(
        pcmFormat: format,
        frameCapacity: AVAudioFrameCount(file.length)
    ) else {
        throw AudioAnalysisError.buffer
    }
    try file.read(into: buffer)
    guard let channels = buffer.floatChannelData else {
        throw AudioAnalysisError.buffer
    }

    var sum: Double = 0
    var peak: Float = 0
    let channelCount = Int(format.channelCount)
    let frameCount = Int(buffer.frameLength)
    for channel in 0..<channelCount {
        for frame in 0..<frameCount {
            let value = channels[channel][frame]
            sum += Double(value * value)
            peak = max(peak, abs(value))
        }
    }
    let sampleCount = max(1, channelCount * frameCount)
    let rms = sqrt(sum / Double(sampleCount))
    let rmsDB = 20.0 * log10(max(rms, 0.0000001))
    let peakDB = 20.0 * log10(max(Double(peak), 0.0000001))
    let duration = Double(frameCount) / format.sampleRate
    print(
        "\(URL(fileURLWithPath: path).lastPathComponent) " +
        "duration=\(String(format: "%.3f", duration))s " +
        "rms=\(String(format: "%.1f", rmsDB))dBFS " +
        "peak=\(String(format: "%.1f", peakDB))dBFS"
    )
}

do {
    guard CommandLine.arguments.count >= 2 else { throw AudioAnalysisError.usage }
    for path in CommandLine.arguments.dropFirst() {
        try analyze(path)
    }
} catch {
    FileHandle.standardError.write(Data("\(error)\n".utf8))
    exit(1)
}
