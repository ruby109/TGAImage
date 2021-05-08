import Foundation

public struct TGADecoder {
    
    func decode(data: Data) -> Data {
        return Data()
    }
    
    public init() {
        
    }
    
    
    public func getTGAHeader(by data: Data) -> TGAFile.Header? {
        return TGAFile.Header(data: data[0...17])
    }
}
