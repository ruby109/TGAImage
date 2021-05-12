//
//  File.swift
//  
//
//  Created by ruby109 on 2021/5/7.
//

import Foundation
import ArgumentParser
import TGAImage

struct TGA: ParsableCommand {
    @Flag(name: .shortAndLong, help: "Decode Mode")
    var decoding: Bool = false
    
    @Flag(name: .shortAndLong, help: "Encode Mode")
    var encoding: Bool = false
    
    @Argument(help: "Input file path.")
    var inputFilePath: String
    
    @Argument(help: "Output file path.")
    var outputFilePath: String
    
    mutating func run() throws {
        guard self.decoding != self.encoding else {
            throw ValidationError("Please choose decode mode or encode mode.")
        }
        
        print(self.inputFilePath)
        
        guard FileManager.default.fileExists(atPath: self.inputFilePath), let data = FileManager.default.contents(atPath: self.inputFilePath) else {
            throw ValidationError("Please check your input file path.")
        }
        
        if self.decoding {
            let decoder = TGADecoder()
            if let header = decoder.getTGAHeader(by: data[0...17]) {
                print(header)
                let imageData = decoder.getTGAImageData(by: data, header: header)
                let image = generateCGImage(from: imageData.pixels, width: Int(header.imageSpecification.imageWidth), height: Int(header.imageSpecification.imageHeight))
                
                print(writeCGImage(image!, to: URL(string: "file://" + outputFilePath)!))
                
                
            }
            
            
            
        } else if self.encoding {
            fatalError("sorry, encode is not supported at now")
        }
    }
}

@discardableResult func writeCGImage(_ image: CGImage, to destinationURL: URL) -> Bool {
    let type: CFString
    if destinationURL.absoluteString.contains("png") {
        type = kUTTypePNG
    } else {
        type = kUTTypeJPEG
    }
    guard let destination = CGImageDestinationCreateWithURL(destinationURL as CFURL, type, 1, nil) else { return false }
    CGImageDestinationAddImage(destination, image, nil)
    return CGImageDestinationFinalize(destination)
}

