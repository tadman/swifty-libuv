//
//  PipeWrap.swift
//  SwiftyLibuv
//
//  Created by Yuki Takei on 6/12/16.
//
//

import CLibUv

/**
 Pipe handle type
 */
public class PipeWrap: StreamWrap {
    
    public init(pipe: UnsafeMutablePointer<uv_pipe_t>){
        super.init(UnsafeMutablePointer<uv_stream_t>(pipe))
    }
    
    public init(loop: Loop = Loop.defaultLoop, ipcEnable: Bool = false){
        let pipe = UnsafeMutablePointer<uv_pipe_t>(allocatingCapacity: sizeof(uv_pipe_t))
        uv_pipe_init(loop.loopPtr, pipe, ipcEnable ? 1 : 0)
        super.init(UnsafeMutablePointer<uv_stream_t>(pipe))
    }
    
    /**
     Open an existing file descriptor or HANDLE as a pipe
     
     - parameter stdio: Number of fd to open (Int32)
     */
    public func open(_ stdio: Int) -> Self {
        uv_pipe_open(pipePtr, Int32(stdio))
        return self
    }
    
    public func bind(_ sockName: String) throws {
        let r = uv_pipe_bind(pipePtr, sockName)
        
        if r < 0 {
            throw Error.uvError(code: r)
        }
    }
    
    public func listen(_ backlog: UInt = 128, onConnection: ((Void) throws -> Void) -> Void) throws {
        streamPtr.pointee.data = retainedVoidPointer(onConnection)
        
        let result = uv_listen(streamPtr, Int32(backlog)) { stream, status in
            guard let stream = stream else {
                return
            }
            
            let onConnection: ((Void) throws -> Void) -> Void = releaseVoidPointer(stream.pointee.data)!
            guard status >= 0 else {
                return onConnection {
                    throw Error.uvError(code: status)
                }
            }
            
            onConnection {}
        }
        
        if result < 0 {
            onConnection {
                throw Error.uvError(code: result)
            }
        }
    }
    
    /**
     Connect to the Unix domain socket or the named pipe.
     
     - parameter sockName: Socket name to connect
     - parameter onConnect: Will be called when the connection is succeeded or failed
     */
    public func connect(_ sockName: String, onConnect: ((Void) throws -> StreamWrap) -> Void){
        let req = UnsafeMutablePointer<uv_connect_t>(allocatingCapacity: sizeof(uv_connect_t))
        
        req.pointee.data = retainedVoidPointer(onConnect)
        
        uv_pipe_connect(req, pipePtr, sockName) { req, status in
            guard let req = req else {
                return
            }
            let onConnect: ((Void) throws -> StreamWrap) -> Void = releaseVoidPointer(req.pointee.data)!
            if status < 0 {
                onConnect {
                    throw Error.uvError(code: status)
                }
            }
            
            onConnect {
                StreamWrap(UnsafeMutablePointer<uv_stream_t>(req))
            }
        }
    }
}
