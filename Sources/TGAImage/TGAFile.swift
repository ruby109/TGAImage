import Foundation

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
        
        let imageIDLength: UInt8
        /// 0 indicates no color-map, 1 indicates that a color-map is included
        let colorMapType: UInt8

        /// Image Type - Field 3 (1 byte)
        enum ImageType: UInt8 {
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
            /// Compressed, black and white images.
            case compressedBlackAndWhite = 11
        }
        /// Image Specification - Field 5 (10 bytes)
        struct ImageSpecification {
            ///X Origin of Image. Integer ( lo-hi ) X coordinate of the lower left corner of the image.
            let imageOriginX: UInt16
            ///Y Origin of Image. Integer ( lo-hi ) Y coordinate of the lower left corner of the image.
            let imageOriginY: UInt16
            /// This field specifies the width of the image in pixels (2 bytes).
            let imageWidth: UInt16
            /// This field specifies the height of the image in pixels (2 bytes).
            let imageHeight: UInt16
            /// This field indicates the number of bits per pixel (1 byte).
            let pixelDepth: UInt8 // 8 * 3
            /// These bits specify the number of attribute bits perpixel (1 byte).
            let imageDescriptor: UInt8 // 8 * 4
            
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
        private let imageType: ImageType

        /// The image specification of the corresponding `TGAImage`.
        private let imageSpecification: ImageSpecification
        
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
        private let pixels: [TGAColor]

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

    }

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
                self.entryIndex = data[3...4].withUnsafeBytes{ $0.bindMemory(to: UInt16.self) }[0]
                self.length = data[5...6].withUnsafeBytes{ $0.bindMemory(to: UInt16.self) }[0]
                self.entrySize = data[7]
            } else {
                self.entryIndex = 0
                self.length = 0
                self.entrySize = 0
            }
        }
    }
}
