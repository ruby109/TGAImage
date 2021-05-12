//
//  File.swift
//  
//
//  Created by ruby109 on 2021/5/12.
//

import Foundation
import Bitter

// MARK: - TGAFile.ImageData

public extension TGAFile {

    /// IMAGE DATA
    ///
    /// [Specification](http://www.dca.fee.unicamp.br/~martino/disciplinas/ea978/tgaffs.pdf) Page 10 ff.
    struct ImageData {

        /// The pixels of the (wrapped) `TGAImage`.
        public let pixels: [TGAColor]

        /// Creates the "TGA IMAGE DATA" from the given pixel data.
        ///
        /// - Parameters:
        ///     - pixels: The pixels of the (wrapped) `TGAImage`.
        init(pixels: [TGAColor]) {
            self.pixels = pixels
        }

        /// Returns the (raw) `Data` representation of the "TGA IMAGE DATA".
        func data() -> Data {
            Data(bytes: pixels, count: MemoryLayout<TGAColor>.size * pixels.count)
        }
        
        
        init(data: Data, header: TGAFile.Header) {
            let imageSpec = header.imageSpecification
            let width = Int(imageSpec.imageWidth)
            let height = Int(imageSpec.imageHeight)
            let count = Int(header.imageSpecification.pixelDepth / 8)
            let offset = Int(18 + header.imageIDLength)
            var pixels = [TGAColor](repeating: TGAColor(r: 0, g: 0, b: 0), count: Int(width * height))
            switch header.imageType {
            case .noImageData:
                self.pixels = []
            case .uncompressedTrueColor, .uncompressedBlackAndWhite:
                for i in 0..<height {
                    for j in 0..<width {
                        let index = offset + count * width * i + count * j
                        let color = getColor(by: Int(header.imageSpecification.pixelDepth), data: data[index...index+count-1])
                        switch (imageSpec.imageOriginX, imageSpec.imageOriginY) {
                        case (0, 0): //lower left
                            pixels[width * (height - i - 1) + j] = color
                        case (0, _): //upper left
                            pixels[width * i + j] = color
                        case (_, 0): //lower right
                            pixels[(height - i - 1) + (width - j - 1)] = color
                        case (_, _): //upper right
                            pixels[width * (height - i - 1) + (width - j - 1)] = color
                        }
                    }
                }
                self.pixels = pixels
            case .runlengthEncodedRGB, .compressedBlackAndWhite:
                let decodedData = decodeRunLengthData(width: width, height: height, depth: Int(imageSpec.pixelDepth), data: data, offset: offset)
                for i in 0..<height {
                    for j in 0..<width {
                        let index = 0 + count * width * i + count * j
                        let color = getColor(by: Int(header.imageSpecification.pixelDepth), data: decodedData[index...index+count-1])
                        switch (imageSpec.imageOriginX, imageSpec.imageOriginY) {
                        case (0, 0): //lower left
                            pixels[width * (height - i - 1) + j] = color
                        case (0, _): //upper left
                            pixels[width * i + j] = color
                        case (_, 0): //lower right
                            pixels[(height - i - 1) + (width - j - 1)] = color
                        case (_, _): //upper right
                            pixels[width * (height - i - 1) + (width - j - 1)] = color
                            
                        }
                    }
                }
                self.pixels = pixels
            case .uncompressedColorMapped:
                self.pixels = []
                break
            case .runlengthColorMapped:
                self.pixels = []
                break
            }
        }
        
        // https://github.com/npedotnet/TGAReader/blob/master/src/c/tga_reader.c

    }

}

fileprivate func decodeRunLengthData(width: Int, height: Int, depth: Int, data originalData: Data, offset: Int) -> Data {
    var offset = offset
    let elementCount = depth / 8
    var elements = Data(repeating: 0, count: elementCount)
    let decodedDataLength = elementCount * width * height
    var decodedData = Data(repeating: 0, count: decodedDataLength)
    var decodedLength = 0
    while decodedLength < decodedDataLength {
        let packet = originalData[offset]
        offset += 1
        if packet.b7 == 1 { // RunLength Packet
            let count = (packet & 0x7F) + 1
            for i in 0..<elementCount {
                elements[i] = originalData[offset]
                offset += 1
            }
            for _ in 0..<count {
                for j in 0..<elementCount {
                    decodedData[decodedLength] = elements[j]
                    decodedLength += 1
                }
            }
        } else { //RAW
            let count = (Int(packet) + 1) * elementCount
            for _ in 0..<count {
                decodedData[decodedLength] = originalData[offset]
                decodedLength += 1
                offset += 1
            }
            
        }
    }
    return decodedData
}

fileprivate func getColor(by pixelDepth: Int, data: Data) -> TGAColor {
    
    let data = Array(data)
    switch pixelDepth {
    case 8:
        let e = data[0]
        return TGAColor(r: e, g: e, b: e)
    case 16:
        let hexData = data.withUnsafeBytes{ $0.bindMemory(to: UInt16.self) }[0]
        let b = (hexData & 0x1F)
        let r = (hexData & 0xF800) >> 11
        let g = (hexData & 0x7E0) >> 5
        return TGAColor(r: UInt8(truncatingIfNeeded: r), g: UInt8(truncatingIfNeeded: g), b: UInt8(truncatingIfNeeded: b))
    case 24:
        let b = data[0]
        let r = data[1]
        let g = data[2]
        return TGAColor(r: r, g: g, b: b)
    case 32:
        let b = data[0]
        let r = data[1]
        let g = data[2]
        let a = data[3]
        return TGAColor(r: r, g: g, b: b, a: a)
    default:
        return TGAColor(r: 0, g: 0, b: 0)
    }
}
