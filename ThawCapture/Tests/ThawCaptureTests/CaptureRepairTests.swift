//
//  CaptureRepairTests.swift
//  Project: Thaw
//
//  Copyright (Thaw) © 2026 Toni Förster
//  Licensed under the GNU GPLv3
//

import CoreGraphics
import Foundation
import Testing
@testable import ThawCapture

@Suite("Capture repairs")
struct CaptureRepairTests {
    private actor Gate {
        var released = false
        var continuation: CheckedContinuation<Void, Never>?

        func wait() async {
            guard !released else { return }
            await withCheckedContinuation { continuation = $0 }
        }

        func release() {
            released = true
            continuation?.resume()
            continuation = nil
        }
    }

    private static func image(width: Int = 8, height: Int = 4) throws -> CGImage {
        let colorSpace = try #require(CGColorSpace(name: CGColorSpace.sRGB))
        let context = try #require(CGContext(
            data: nil,
            width: width,
            height: height,
            bitsPerComponent: 8,
            bytesPerRow: 0,
            space: colorSpace,
            bitmapInfo: CGImageAlphaInfo.premultipliedFirst.rawValue | CGBitmapInfo.byteOrder32Little.rawValue
        ))
        context.setFillColor(CGColor(red: 0.2, green: 0.4, blue: 0.6, alpha: 1))
        context.fill(CGRect(x: 0, y: 0, width: width, height: height))
        return try #require(context.makeImage())
    }

    @Test
    func windowCaptureFallbackTimesOutWhenShareableContentNeverCompletes() async {
        let enumeration = Gate()
        let start = ContinuousClock.now
        let image = await ScreenCapture.captureWindowsFallback(timeout: .milliseconds(50)) {
            await enumeration.wait()
            return try Self.image()
        }
        await enumeration.release()
        #expect(image == nil)
        #expect(ContinuousClock.now - start < .seconds(5))
    }

    @Test
    func windowCaptureFallbackTimesOutWhenScreenshotNeverCompletes() async {
        let screenshot = Gate()
        let start = ContinuousClock.now
        let image = await ScreenCapture.captureWindowsFallback(timeout: .milliseconds(50)) {
            // Enumeration has returned; the next suspended phase is the screenshot.
            let enumeratedWindowIDs = [CGWindowID(1)]
            guard !enumeratedWindowIDs.isEmpty else { return nil }
            await screenshot.wait()
            return try Self.image()
        }
        await screenshot.release()
        #expect(image == nil)
        #expect(ContinuousClock.now - start < .seconds(5))
    }

    @Test
    func windowCaptureFallbackReturnsFrameBeforeDeadline() async {
        let image = await ScreenCapture.captureWindowsFallback(timeout: .seconds(5)) {
            try Self.image()
        }
        #expect(image?.width == 8)
        #expect(image?.height == 4)
    }

    private let display = CGRect(x: 0, y: 0, width: 1512, height: 982)

    @Test
    func tallNotchedPointFrameMultipliesHostingCaptureSizeByScale() {
        let size = ScreenCapture.hostingCapturePixelSize(
            windowFrame: CGRect(x: 0, y: 0, width: 1512, height: 49),
            displayFrame: display,
            reportedScale: 2
        )
        #expect(size.width == 3024)
        #expect(size.height == 98)
    }

    @Test
    func pixelBackedNotchedFrameDoesNotDoubleScaleHostingCaptureSize() {
        let size = ScreenCapture.hostingCapturePixelSize(
            windowFrame: CGRect(x: 0, y: 0, width: 3024, height: 98),
            displayFrame: display,
            reportedScale: 2
        )
        #expect(size.width == 3024)
        #expect(size.height == 98)
    }

    @Test
    func normalizedHostingCaptureAcceptsTallPointSpaceMenuBar() throws {
        let frame = CGRect(x: 0, y: 0, width: 1512, height: 49)
        let capture = try #require(ScreenCapture.normalizedHostingCapture(
            image: Self.image(width: 3024, height: 98),
            windowFrame: frame,
            displayFrame: display,
            reportedScale: 2
        ))
        #expect(capture.windowFrame == frame)
        #expect(capture.scale == 2)
    }

    @Test
    func captureServiceFrameConvertsDisplayP3PixelsToSRGB() throws {
        let space = try #require(CGColorSpace(name: CGColorSpace.displayP3))
        let sourceBytes = Data([51, 128, 204, 255])
        let provider = try #require(CGDataProvider(data: sourceBytes as CFData))
        let source = try #require(CGImage(
            width: 1,
            height: 1,
            bitsPerComponent: 8,
            bitsPerPixel: 32,
            bytesPerRow: 4,
            space: space,
            bitmapInfo: CGBitmapInfo(rawValue: CGImageAlphaInfo.premultipliedFirst.rawValue | CGBitmapInfo.byteOrder32Little.rawValue),
            provider: provider,
            decode: nil,
            shouldInterpolate: false,
            intent: .defaultIntent
        ))
        let frame = try #require(CaptureServiceFrame(image: source, windowFrame: .zero, scale: 1))
        let color = try #require(CGColor(colorSpace: space, components: [0.8, 128.0 / 255, 0.2, 1]))
        let destinationSpace = try #require(CGColorSpace(name: CGColorSpace.sRGB))
        let converted = try #require(color.converted(to: destinationSpace, intent: .defaultIntent, options: nil))
        let components = try #require(converted.components)
        let bytes = [UInt8](frame.pixelData)
        for (index, component) in [components[2], components[1], components[0]].enumerated() {
            #expect(abs(Int(bytes[index]) - Int((component * 255).rounded())) <= 2)
        }
        #expect(Array(bytes.prefix(3)) != Array(sourceBytes.prefix(3)))
        #expect(try #require(frame.makeImage()).colorSpace?.name == CGColorSpace.sRGB)
    }

    @Test
    func captureServiceFrameRoundTripPreservesSRGBPixelBytes() throws {
        let source = try Self.image()
        let frame = try #require(CaptureServiceFrame(image: source, windowFrame: .zero, scale: 1))
        let decoded = try #require(frame.makeImage())
        let roundTrip = try #require(CaptureServiceFrame(image: decoded, windowFrame: .zero, scale: 1))
        for row in 0 ..< frame.pixelHeight {
            let start = row * frame.bytesPerRow
            let nextStart = row * roundTrip.bytesPerRow
            #expect(frame.pixelData[start ..< (start + frame.pixelWidth * 4)] == roundTrip.pixelData[nextStart ..< (nextStart + frame.pixelWidth * 4)])
        }
    }

    @Test
    func captureServiceFrameRoundTripPreservesPaddedRowStride() throws {
        let bytes = Data([3, 2, 1, 255, 0, 0, 0, 0, 6, 5, 4, 255, 0, 0, 0, 0])
        let frame = CaptureServiceFrame(
            pixelData: bytes,
            pixelWidth: 1,
            pixelHeight: 2,
            bytesPerRow: 8,
            windowFrame: CGRect(x: 10, y: 20, width: 1, height: 2),
            scale: 1
        )
        let decoded = try #require(frame.makeImage())
        #expect(decoded.bytesPerRow == 8)
        #expect(try #require(decoded.dataProvider?.data) as Data == bytes)
        let encoded = try #require(CaptureServiceFrame(image: decoded, windowFrame: frame.windowFrame, scale: 1))
        #expect(Array(encoded.pixelData.prefix(4)) == [3, 2, 1, 255])
        #expect(Array(encoded.pixelData.dropFirst(encoded.bytesPerRow).prefix(4)) == [6, 5, 4, 255])
        #expect(encoded.windowFrame == frame.windowFrame)
    }
}
