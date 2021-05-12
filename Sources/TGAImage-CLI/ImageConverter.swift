//
//  File.swift
//  
//
//  Created by ruby109 on 2021/5/11.
//

import Foundation
import TGAImage
public struct PixelData {
    var a: UInt8
    var r: UInt8
    var g: UInt8
    var b: UInt8
    
    init(tgaColor: TGAColor) {
        self.a = tgaColor.a
        self.r = tgaColor.r
        self.g = tgaColor.g
        self.b = tgaColor.b
    }
}



func generateCGImage(from pixels: [TGAColor], width: Int, height: Int) -> CGImage? {
    
    
    guard pixels.count == width * height else { return nil }
    
    let rgbColorSpace = CGColorSpaceCreateDeviceRGB()
    let bitmapInfo = CGBitmapInfo(rawValue: CGImageAlphaInfo.premultipliedFirst.rawValue)
    let bitsPerComponent = 8
    let bitsPerPixel = 32
    
    var data = pixels.map{ PixelData(tgaColor: $0) } // Copy to mutable []
    guard let providerRef = CGDataProvider(data: NSData(bytes: &data,
                                                        length: data.count * MemoryLayout<PixelData>.size)
    )
    else { return nil }
    
    guard let image = CGImage(
        width: width,
        height: height,
        bitsPerComponent: bitsPerComponent,
        bitsPerPixel: bitsPerPixel,
        bytesPerRow: width * MemoryLayout<PixelData>.size,
        space: rgbColorSpace,
        bitmapInfo: bitmapInfo,
        provider: providerRef,
        decode: nil,
        shouldInterpolate: true,
        intent: .defaultIntent
    )
    else { return nil }
    
    return image
}
