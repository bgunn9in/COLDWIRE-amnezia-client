import CoreGraphics
import Foundation
import Vision

if CommandLine.arguments[1] == "--click" {
    let coordinates = CommandLine.arguments.dropFirst(2).compactMap { Double($0) }
    guard CGPreflightPostEventAccess(), coordinates.count == 2 else {
        FileHandle.standardError.write(Data("The runner lacks permission to post mouse events.\n".utf8))
        exit(1)
    }
    let point = CGPoint(x: coordinates[0], y: coordinates[1])
    guard CGDisplayBounds(CGMainDisplayID()).contains(point) else { exit(1) }
    guard CGWarpMouseCursorPosition(point) == .success else { exit(1) }
    let mouseEvents: [CGEventType] = [.mouseMoved, .leftMouseDown, .leftMouseUp]
    for type in mouseEvents {
        CGEvent(mouseEventSource: nil, mouseType: type, mouseCursorPosition: point, mouseButton: .left)?.post(tap: .cghidEventTap)
        Thread.sleep(forTimeInterval: 0.12)
    }
    print("Clicked at \(point)")
    exit(0)
}

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
