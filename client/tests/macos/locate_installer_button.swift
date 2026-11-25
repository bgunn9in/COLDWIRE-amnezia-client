import CoreGraphics
import Foundation
import Vision

let path = URL(fileURLWithPath: CommandLine.arguments[1])
let label = CommandLine.arguments[2]
let request = VNRecognizeTextRequest()
request.recognitionLevel = .accurate
try VNImageRequestHandler(url: path).perform([request])
let matches = (request.results ?? []).filter {
    $0.topCandidates(1).first?.string == label
}
guard matches.count == 1, let match = matches.first else {
    FileHandle.standardError.write(Data("Expected one visible button named \(label)\n".utf8))
    exit(1)
}
let display = CGDisplayBounds(CGMainDisplayID())
print(Int(display.minX + display.width * match.boundingBox.midX))
print(Int(display.minY + display.height * (1 - match.boundingBox.midY)))
