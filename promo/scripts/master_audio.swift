import AVFoundation
import Foundation

enum MasterError: Error, CustomStringConvertible {
    case usage
    case unsupported(String)

    var description: String {
        switch self {
        case .usage:
            return "usage: swift master_audio.swift <input-audio> <output.wav> <target-rms-dbfs> [ceiling-dbfs]"
        case .unsupported(let detail):
            return detail
        }
    }
}

func db(_ amplitude: Double) -> Double {
    20.0 * log10(max(amplitude, 0.0000001))
}

func amplitude(_ decibels: Double) -> Double {
    pow(10.0, decibels / 20.0)
}

func run() throws {
    guard (4...5).contains(CommandLine.arguments.count),
          let targetRMSDB = Double(CommandLine.arguments[3]) else {
        throw MasterError.usage
    }
    let ceilingDB = CommandLine.arguments.count == 5
        ? Double(CommandLine.arguments[4]) ?? -1.0
        : -1.0

    let inputURL = URL(fileURLWithPath: CommandLine.arguments[1])
    let outputURL = URL(fileURLWithPath: CommandLine.arguments[2])
    let input = try AVAudioFile(forReading: inputURL)
    let format = input.processingFormat
    guard format.channelCount > 0 else {
        throw MasterError.unsupported("input has no audio channels")
    }

    let frameCount = AVAudioFrameCount(input.length)
    guard let buffer = AVAudioPCMBuffer(pcmFormat: format, frameCapacity: frameCount) else {
        throw MasterError.unsupported("could not allocate PCM buffer")
    }
    try input.read(into: buffer)
    guard let channels = buffer.floatChannelData else {
        throw MasterError.unsupported("could not decode input as float PCM")
    }

    let count = Int(buffer.frameLength)
    let channelCount = Int(format.channelCount)
    var sumSquares = 0.0
    var inputPeak = 0.0
    for channel in 0..<channelCount {
        for index in 0..<count {
            let sample = Double(channels[channel][index])
            sumSquares += sample * sample
            inputPeak = max(inputPeak, abs(sample))
        }
    }
    let inputRMS = sqrt(sumSquares / Double(max(1, count * channelCount)))
    let requestedGain = amplitude(targetRMSDB) / max(inputRMS, 0.000001)
    // A generous ceiling keeps the operation from turning near-silence into pure codec noise.
    let gain = min(requestedGain, amplitude(18.0))
    let knee = 0.68
    let ceiling = amplitude(ceilingDB)

    var outputPeak = 0.0
    var outputSquares = 0.0
    for channel in 0..<channelCount {
        for index in 0..<count {
            var value = Double(channels[channel][index]) * gain
            let sign = value < 0 ? -1.0 : 1.0
            let magnitude = abs(value)
            if magnitude > knee {
                let compressed = knee + (1.0 - knee) * tanh((magnitude - knee) / (1.0 - knee))
                value = sign * compressed
            }
            value = max(-ceiling, min(ceiling, value))
            channels[channel][index] = Float(value)
            outputPeak = max(outputPeak, abs(value))
            outputSquares += value * value
        }
    }

    let outputRMS = sqrt(outputSquares / Double(max(1, count * channelCount)))
    try FileManager.default.createDirectory(
        at: outputURL.deletingLastPathComponent(),
        withIntermediateDirectories: true
    )
    let output = try AVAudioFile(
        forWriting: outputURL,
        settings: format.settings,
        commonFormat: .pcmFormatFloat32,
        interleaved: false
    )
    try output.write(from: buffer)

    print(String(format: "input rms=%.1f dBFS peak=%.1f dBFS", db(inputRMS), db(inputPeak)))
    print(String(format: "gain=%.1f dB target=%.1f dBFS", db(gain), targetRMSDB))
    print(String(format: "output rms=%.1f dBFS peak=%.1f dBFS ceiling=%.1f dBFS", db(outputRMS), db(outputPeak), ceilingDB))
    print(outputURL.path)
}

do {
    try run()
} catch {
    FileHandle.standardError.write(Data("\(error)\n".utf8))
    exit(1)
}
