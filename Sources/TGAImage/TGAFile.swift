import Foundation
import Bitter

/// TGA FILE
///
/// [Specification](http://www.dca.fee.unicamp.br/~martino/disciplinas/ea978/tgaffs.pdf)
///
/// This object takes care of providing the (raw) `Data` representation for a given `TGAImage` to be able to store the
/// image data as a "Targa Image File" (`.tga`) following the file specification (v2) from January 1991.
///
/// ## Implementation Details
///
/// This object only takes care of providing the minimal needed information for a valid `.tga` file. Relying on default
/// values wherever possible. Additionally, fields like the `ImageID` or the `Software ID` / `Software Name` aren't set.
public struct TGAFile {

    /// The "TGA File Header" of the wrapped `TGAImage`.
    private let header: Header

    /// The "TGA Image Data" of the wrapped `TGAImage`.
    private let image: ImageData

    /// The "TGA File Footer" of the wrapped `TGAImage`.
    private let footer: Footer

    /// Creates a new "TGA File" wrapping the given image.
    ///
    /// - Parameters:
    ///     - image: The `TGAImage` which should be stored as a `.tga` file.
    init(_ image: TGAImage) {
        self.header = Header(width: image.width, height: image.height)
        self.image = ImageData(pixels: image.pixels)
        self.footer = Footer()
    }

    /// Returns the (raw) `Data` representation of the wrapped `TGAImage` following the TGA file specification(s).
    func data() -> Data {
        header.data() + image.data() + footer.data()
    }

}

// MARK: - TGAFile.Header

public extension TGAFile {

    /// TGA FILE HEADER
    ///
    /// [Specification](http://www.dca.fee.unicamp.br/~martino/disciplinas/ea978/tgaffs.pdf) Page 6 ff.
    struct Header {
        
        public let imageIDLength: UInt8
        /// 0 indicates no color-map, 1 indicates that a color-map is included
        public let colorMapType: UInt8

        /// Image Type - Field 3 (1 byte)
        public enum ImageType: UInt8 {
            /// No image data included.
            case noImageData = 0
            /// Uncompressed, color-mapped images.
            case uncompressedColorMapped = 1
            /// Uncompressed, True-color Image
            case uncompressedTrueColor = 2
            /// Uncompressed, black and white images.
            case uncompressedBlackAndWhite = 3
            /// Runlength encoded color-mapped images.
            case runlengthColorMapped = 9
            /// Runlength encoded RGB images.
            case runlengthEncodedRGB = 10
            /// Compressed, black and white images. Runlength
            case compressedBlackAndWhite = 11
        }
        /// Image Specification - Field 5 (10 bytes)
        public struct ImageSpecification {
            ///X Origin of Image. Integer ( lo-hi ) X coordinate of the lower left corner of the image.
            public let imageOriginX: UInt16
            ///Y Origin of Image. Integer ( lo-hi ) Y coordinate of the lower left corner of the image.
            public let imageOriginY: UInt16
            /// This field specifies the width of the image in pixels (2 bytes).
            public let imageWidth: UInt16
            /// This field specifies the height of the image in pixels (2 bytes).
            public let imageHeight: UInt16
            /// This field indicates the number of bits per pixel (1 byte).
            public let pixelDepth: UInt8 // 8 * 3
            /// These bits specify the number of attribute bits perpixel (1 byte).
            public let imageDescriptor: UInt8 // 8 * 4
            
            init(imageOriginX: UInt16 = 0, imageOriginY: UInt16 = 0, imageWidth: UInt16, imageHeight: UInt16, pixelDepth: UInt8 = 24, imageDescriptor: UInt8 = 32) {
                self.imageOriginX = imageOriginX
                self.imageOriginY = imageOriginY
                self.imageWidth = imageWidth
                self.imageHeight = imageHeight
                self.pixelDepth = pixelDepth
                self.imageDescriptor = imageDescriptor
            }
            
            
        }

        /// The image type of the pixel data stored in the `ImageData` section of the `TGAFile`.
        public let imageType: ImageType

        /// The image specification of the corresponding `TGAImage`.
        public let imageSpecification: ImageSpecification
        
        /// The TGA format defines three methods of arranging image data: psuedocolor, direct-color, and truecolor.
        private let colorMap: ColorMap

        /// Creates a "TGA File Header" for an uncompressed, true-color TGA image with the given dimensions.
        ///
        /// - Parameters:
        ///     - width:    The width of the image stored as the `TGAFile`.
        ///     - height:   The height of the image stored as the `TGAFile`.
        ///     - type:     The image type of the pixel data stored in the `ImageData` section of the `TGAFile`.
        init(width: Int, height: Int, type: ImageType = .uncompressedTrueColor) {
            imageIDLength = 0
            colorMapType = 0
            imageType = type
            imageSpecification = ImageSpecification(imageWidth: UInt16(width), imageHeight: UInt16(height))
            colorMap = ColorMap(data: Data())
        }

        /// Returns the (raw) `Data` representation of the "TGA File Header".
        func data() -> Data {
            var data = Data(repeating: 0, count: 18)
            data[02] = imageType.rawValue
            data[12] = UInt8(truncatingIfNeeded: imageSpecification.imageWidth)
            data[13] = UInt8(truncatingIfNeeded: imageSpecification.imageWidth >> 8)
            data[14] = UInt8(truncatingIfNeeded: imageSpecification.imageHeight)
            data[15] = UInt8(truncatingIfNeeded: imageSpecification.imageHeight >> 8)
            data[16] = imageSpecification.pixelDepth
            data[17] = imageSpecification.imageDescriptor
            return data
        }
        
        init?(data: Data) {
            guard data.count == 18 else {
                return nil
            }
            self.imageIDLength = data[0]
            self.colorMapType = data[1]
            self.imageType = ImageType(rawValue: data[2]) ?? ImageType.noImageData
            self.colorMap = ColorMap(data: data[3...7])
            self.imageSpecification = ImageSpecification(imageOriginX:data[8...9].withUnsafeBytes{ $0.bindMemory(to: UInt16.self) }[0],
                                                         imageOriginY: data[10...11].withUnsafeBytes{ $0.bindMemory(to: UInt16.self) }[0],
                                                         imageWidth: data[12...13].withUnsafeBytes{ $0.bindMemory(to: UInt16.self) }[0],
                                                         imageHeight: data[14...15].withUnsafeBytes{ $0.bindMemory(to: UInt16.self) }[0],
                                                         pixelDepth: UInt8(data[16]),
                                                         imageDescriptor: UInt8(data[17]))
            
            
        }

    }

}

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
            case .uncompressedTrueColor:
                switch (imageSpec.imageOriginX, imageSpec.imageOriginY) {
                case (0, 0): //lower left
                    for i in 0..<height {
                        for j in 0..<width {
                            let index = offset + count * width * i + count * j
                            let b = data[index + 0]
                            let r = data[index + 1]
                            let g = data[index + 2]
                            pixels[width * (height - i - 1) + j] = TGAColor(r: r, g: g, b: b)
                        }
                    }
                case (0, _): //upper left
                    for i in 0..<height {
                        for j in 0..<width {
                            let index = offset + count * width * i + count * j
                            let b = data[index + 0]
                            let r = data[index + 1]
                            let g = data[index + 2]
                            pixels[width * i + j] = TGAColor(r: r, g: g, b: b)
                        }
                    }
                case (_, 0): //lower right
                    for i in 0..<height {
                        for j in 0..<width {
                            let index = offset + count * width * i + count * j
                            let b = data[index + 0]
                            let r = data[index + 1]
                            let g = data[index + 2]
                            pixels[(height - i - 1) + (width - j - 1)] = TGAColor(r: r, g: g, b: b)
                        }
                    }
                case (_, _): //upper right
                    for i in 0..<height {
                        for j in 0..<width {
                            let index = offset + count * width * i + count * j
                            let b = data[index + 0]
                            let r = data[index + 1]
                            let g = data[index + 2]
                            pixels[width * (height - i - 1) + (width - j - 1)] = TGAColor(r: r, g: g, b: b)
                        }
                    }
                }
                self.pixels = pixels
            case .uncompressedBlackAndWhite:
                switch (imageSpec.imageOriginX, imageSpec.imageOriginY) {
                case (0, 0): //lower left
                    for i in 0..<height {
                        for j in 0..<width {
                            let index = offset + count * width * i + count * j
                            let e = data[index + 0]
                            pixels[width * (height - i - 1) + j] = TGAColor(r: e, g: e, b: e)
                        }
                    }
                case (0, _): //upper left
                    for i in 0..<height {
                        for j in 0..<width {
                            let index = offset + count * width * i + count * j
                            let e = data[index + 0]
                            pixels[width * i + j] = TGAColor(r: e, g: e, b: e)
                        }
                    }
                case (_, 0): //lower right
                    for i in 0..<height {
                        for j in 0..<width {
                            let index = offset + count * width * i + count * j
                            let e = data[index + 0]
                            pixels[(height - i - 1) + (width - j - 1)] = TGAColor(r: e, g: e, b: e)
                        }
                    }
                case (_, _): // upper right
                    for i in 0..<height {
                        for j in 0..<width {
                            let index = offset + count * width * i + count * j
                            let e = data[index + 0]
                            pixels[width * (height - i - 1) + (width - j - 1)] = TGAColor(r: e, g: e, b: e)
                        }
                    }
                }
                self.pixels = pixels
            case .runlengthEncodedRGB:
                let decodedData = decodeRunLengthData(width: width, height: height, depth: Int(imageSpec.pixelDepth), data: data, offset: offset)
                switch (imageSpec.imageOriginX, imageSpec.imageOriginY) {
                case (0, 0): //lower left
                    for i in 0..<height {
                        for j in 0..<width {
                            let index = 0 + count * width * i + count * j
                            let b = decodedData[index + 0]
                            let r = decodedData[index + 1]
                            let g = decodedData[index + 2]
                            pixels[width * (height - i - 1) + j] = TGAColor(r: r, g: g, b: b)
                        }
                    }
                case (0, _): //upper left
                    for i in 0..<height {
                        for j in 0..<width {
                            let index = 0 + count * width * i + count * j
                            let b = decodedData[index + 0]
                            let r = decodedData[index + 1]
                            let g = decodedData[index + 2]
                            pixels[width * i + j] = TGAColor(r: r, g: g, b: b)
                        }
                    }
                case (_, 0): //lower right
                    for i in 0..<height {
                        for j in 0..<width {
                            let index = 0 + count * width * i + count * j
                            let b = decodedData[index + 0]
                            let r = decodedData[index + 1]
                            let g = decodedData[index + 2]
                            pixels[(height - i - 1) + (width - j - 1)] = TGAColor(r: r, g: g, b: b)
                        }
                    }
                case (_, _): // upper right
                    for i in 0..<height {
                        for j in 0..<width {
                            let index = 0 + count * width * i + count * j
                            let b = decodedData[index + 0]
                            let r = decodedData[index + 1]
                            let g = decodedData[index + 2]
                            pixels[width * (height - i - 1) + (width - j - 1)] = TGAColor(r: r, g: g, b: b)
                        }
                    }
                }
                self.pixels = pixels
            case .compressedBlackAndWhite:
                let decodedData = decodeRunLengthData(width: width, height: height, depth: Int(imageSpec.pixelDepth), data: data, offset: offset)
                switch (imageSpec.imageOriginX, imageSpec.imageOriginY) {
                case (0, 0): //lower left
                    for i in 0..<height {
                        for j in 0..<width {
                            let index = 0 + count * width * i + count * j
                            let e = decodedData[index + 0]
                            pixels[width * (height - i - 1) + j] = TGAColor(r: e, g: e, b: e)
                        }
                    }
                case (0, _): //upper left
                    for i in 0..<height {
                        for j in 0..<width {
                            let index = 0 + count * width * i + count * j
                            let e = decodedData[index + 0]
                            pixels[width * i + j] = TGAColor(r: e, g: e, b: e)
                        }
                    }
                case (_, 0): //lower right
                    for i in 0..<height {
                        for j in 0..<width {
                            let index = 0 + count * width * i + count * j
                            let e = decodedData[index + 0]
                            pixels[width * (height - i - 1) + (width - j - 1)] = TGAColor(r: e, g: e, b: e)
                        }
                    }
                case (_, _): //upper right
                    for i in 0..<height {
                        for j in 0..<width {
                            let index = 0 + count * width * i + count * j
                            let e = decodedData[index + 0]
                            pixels[width * (height - i - 1) + (width - j - 1)] = TGAColor(r: e, g: e, b: e)
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
            
//            self.pixels = []
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

// MARK: - TGAFile.Footer

public extension TGAFile {

    /// TGA FILE FOOTER
    ///
    /// [Specification](http://www.dca.fee.unicamp.br/~martino/disciplinas/ea978/tgaffs.pdf) Page 19 ff.
    struct Footer {

        /// Returns the (raw) `Data` representation of the "TGA File Footer".
        func data() -> Data {
            var data = Data(repeating: 0, count: 26)
            data[8...23] = Data("TRUEVISION-XFILE".utf8)
            data[24] = UInt8(ascii: ".")
            data[25] = 0x00
            return data
        }

    }

}

// MARK: - TGAFile.ColorMap

public extension TGAFile {
    struct ColorMap {
        /// Color Map Origin. Integer ( lo-hi ) index of first color map entry. 2 byte
        let entryIndex: UInt16
        /// Color Map Length. Integer ( lo-hi ) count of color map entries. 2 byte
        let length: UInt16
        /// Color Map Entry Size. Number of bits in each color map entry.  16 for the Targa 16, 24 for the Targa 24, 32 for the Targa 32. 1 byte
        let entrySize: UInt8
        
        
        init(data: Data) {
            if data.count == 5 {
                let data = Array(data)
                self.entryIndex = data[0...1].withUnsafeBytes{ $0.bindMemory(to: UInt16.self) }[0]
                self.length = data[2...3].withUnsafeBytes{ $0.bindMemory(to: UInt16.self) }[0]
                self.entrySize = data[4]
            } else {
                self.entryIndex = 0
                self.length = 0
                self.entrySize = 0
            }
        }
    }
}
