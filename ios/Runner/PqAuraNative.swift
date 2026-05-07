import Foundation

class PqAuraNative {
    static func decrypt(
        statePtr: OpaquePointer,
        header: Data,
        payload: Data,
        ad: Data
    ) -> Data? {
        var outLen: Int = 0
        
        let headerPtr = header.withUnsafeBytes { $0.baseAddress?.assumingMemoryBound(to: UInt8.self) }
        let payloadPtr = payload.withUnsafeBytes { $0.baseAddress?.assumingMemoryBound(to: UInt8.self) }
        let adPtr = ad.withUnsafeBytes { $0.baseAddress?.assumingMemoryBound(to: UInt8.self) }
        
        guard let resultPtr = pqa_decrypt(
            statePtr,
            headerPtr,
            header.count,
            payloadPtr,
            payload.count,
            adPtr,
            ad.count,
            &outLen
        ) else {
            return nil
        }
        
        let data = Data(bytes: resultPtr, count: outLen)
        pqa_free_buffer(resultPtr, outLen)
        return data
    }
    
    static func initState(serializedState: Data) -> OpaquePointer? {
        let bytesPtr = serializedState.withUnsafeBytes { $0.baseAddress?.assumingMemoryBound(to: UInt8.self) }
        return pqa_deserialize_state(bytesPtr, serializedState.count)
    }
    
    static func loadAtomic(path: String, key: Data) -> OpaquePointer? {
        let keyPtr = key.withUnsafeBytes { $0.baseAddress?.assumingMemoryBound(to: UInt8.self) }
        return pqa_load_atomic(path.cString(using: .utf8), keyPtr)
    }
    
    static func saveAtomic(statePtr: OpaquePointer, path: String, key: Data) -> Bool {
        let keyPtr = key.withUnsafeBytes { $0.baseAddress?.assumingMemoryBound(to: UInt8.self) }
        return pqa_save_atomic(statePtr, path.cString(using: .utf8), keyPtr)
    }
    
    static func freeState(statePtr: OpaquePointer) {
        pqa_free_state(statePtr)
    }
}
