//
//  FileReader.swift
//  SwiftyLibuv
//
//  Created by Yuki Takei on 6/12/16.
//
//

#if os(Linux)
    import Glibc
#else
    import Darwin.C
#endif

import CLibUv

public enum FsReadResult {
    case data(Buffer)
    case end(Int)
    case error(ErrorProtocol)
}

private class FileReaderContext {
    var onRead: (FsReadResult) -> Void = {_ in }
    
    var bytesRead: Int64 = 0
    
    var buf: uv_buf_t? = nil
    
    let loop: Loop
    
    var fd: Int32
    
    /**
     an integer specifying the number of bytes to read
     */
    var length: Int?
    
    /**
     an integer specifying where to begi1n reading from in the file.
     If position is null, data will be read from the current file position
     */
    var position: Int
    
    init(loop: Loop = Loop.defaultLoop, fd: Int32, length: Int? = nil, position: Int, completion: (FsReadResult) -> Void){
        self.loop = loop
        self.fd = fd
        self.position = position
        self.length = length
        self.onRead = completion
    }
}

public class FileReader {
    
    // TODO should be variable depends on resource availability
    public static var upTo = 1024
    
    private let context: FileReaderContext
    
    public init(loop: Loop = Loop.defaultLoop, fd: Int32, offset: Int = 0, length: Int? = nil, position: Int, completion: (FsReadResult) -> Void){
        context = FileReaderContext(
            loop: loop,
            fd: fd,
            length: length,
            position: position,
            completion: completion
        )
        
    }
    
    public func start(){
        readNext(context)
    }
}


private func readNext(_ context: FileReaderContext){
    let readReq = UnsafeMutablePointer<uv_fs_t>(allocatingCapacity: sizeof(uv_fs_t))
    context.buf = uv_buf_init(UnsafeMutablePointer(allocatingCapacity: FileReader.upTo), UInt32(FileReader.upTo))
    
    readReq.pointee.data = retainedVoidPointer(context)
    let r = uv_fs_read(context.loop.loopPtr, readReq, uv_file(context.fd), &context.buf!, 1, context.bytesRead, onReadEach)
    
    
    if r < 0 {
        fs_req_cleanup(readReq)
        context.onRead(.error(Error.uvError(code: r)))
    }
}

private func onReadEach(_ req: UnsafeMutablePointer<uv_fs_t>?) {
    guard let req = req else {
        return
    }
    
    let context: FileReaderContext = releaseVoidPointer(req.pointee.data)!
    defer {
        fs_req_cleanup(req)
    }
    
    if(req.pointee.result < 0) {
        let e = Error.uvError(code: Int32(req.pointee.result))
        return context.onRead(.error(e))
    }
    
    var buf = Buffer()
    for i in stride(from: 0, to: req.pointee.result, by: 1) {
        buf.append(context.buf!.base[i])
    }
    context.onRead(.data(buf))
    context.bytesRead += req.pointee.result
    
    if(req.pointee.result < FileReader.upTo) {
        return context.onRead(.end(Int(context.bytesRead)))
    }
    
    readNext(context)
}
