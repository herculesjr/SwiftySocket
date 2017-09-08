//
//  SwiftySocket.swift
//  SwiftySocket
//
//  Created by Hercules Cunha on 20/08/17.
//  Copyright © 2017 Hercules Jr. All rights reserved.
//

import Foundation

public class SwiftySocket: NSObject {
    
    fileprivate let bufferSize = 1024
    fileprivate var readDataQueue = NSMutableData()
    fileprivate var writeDataQueue = NSMutableData()
    fileprivate var timeoutTimer: Timer?
    var readStream: InputStream?
    var writeStream: OutputStream?
    public var connectHandler: ConnectCompletionBlock?
    public var disconnectHandler: ConnectCompletionBlock?
    public var readHandler: ReadCompletionBlock?
    
    public typealias ConnectCompletionBlock = (SwiftySocketError?) -> Void
    public typealias ReadCompletionBlock = (Data) -> Void
    
    public init(connectHandler: ConnectCompletionBlock? = nil, disconnectHandler: ConnectCompletionBlock? = nil, readHandler: ReadCompletionBlock? = nil) {
        self.connectHandler = connectHandler
        self.disconnectHandler = disconnectHandler
        self.readHandler = readHandler
        super.init()
    }
    
    public func connect(to host: String, port: UInt32, timeout: TimeInterval) {
        if self.readStream == nil || self.writeStream == nil {
            var readStream:  Unmanaged<CFReadStream>?
            var writeStream: Unmanaged<CFWriteStream>?
            CFStreamCreatePairWithSocketToHost(nil, host as CFString, port, &readStream, &writeStream)
            self.readStream = readStream?.takeRetainedValue()
            self.writeStream = writeStream?.takeRetainedValue()
            self.readStream?.delegate = self
            self.writeStream?.delegate = self
            self.readStream?.schedule(in: .current, forMode: .commonModes)
            self.writeStream?.schedule(in: .current, forMode: .commonModes)
        }
        self.timeoutTimer = Timer.scheduledTimer(timeInterval: timeout, target: self, selector: #selector(SwiftySocket.timeoutTriggered), userInfo: nil, repeats: false)
        self.readStream?.open()
    }
    
    public func send(_ data: Data) {
        guard data.count > 0 else { return }
        guard writeStream?.hasSpaceAvailable == true else {
            writeDataQueue.append(data)
            return
        }
        data.withUnsafeBytes { (bytes: UnsafePointer<UInt8>) -> Void in
            guard let writeStream = self.writeStream else { return }
            let bytesWritten = writeStream.write(bytes, maxLength: data.count)
            guard bytesWritten >= 0 else {
                writeDataQueue.append(data)
                return
            }
            if bytesWritten < data.count {
                let dataleft = data.subdata(in: bytesWritten..<data.count)
                writeDataQueue.append(dataleft)
            }
        }
    }
    
    public func disconnect() {
        timeoutTimer?.invalidate()
        timeoutTimer = nil
        readStream?.close()
        writeStream?.close()
        readStream = nil
        writeStream = nil
        readDataQueue.length = 0
        writeDataQueue.length = 0
    }
    
    func timeoutTriggered() {
        connectHandler?(.timeout)
        disconnect()
    }
}

extension SwiftySocket: StreamDelegate {
    
    public func stream(_ aStream: Stream, handle eventCode: Stream.Event) {
        switch eventCode {
        case Stream.Event.openCompleted:
            connectHandler?(nil)
            connectHandler = nil
            timeoutTimer?.invalidate()
            timeoutTimer = nil
        case Stream.Event.hasBytesAvailable:
            guard let readStream = readStream else { return }
            let buffer = UnsafeMutablePointer<UInt8>.allocate(capacity: bufferSize)
            while readStream.hasBytesAvailable {
                let read = readStream.read(buffer, maxLength: bufferSize)
                guard read > 0 else { break }
                readDataQueue.append(buffer, length: read)
            }
            buffer.deallocate(capacity: bufferSize)
            guard readDataQueue.length > 0 else { return }
            readHandler?(readDataQueue as Data)
            readDataQueue.setData(Data())
        case Stream.Event.hasSpaceAvailable:
            send(writeDataQueue as Data)
        case Stream.Event.errorOccurred:
            connectHandler?(SwiftySocketError.buildError(given: aStream.streamError))
        case Stream.Event.endEncountered:
            disconnectHandler?(nil)
            break
        default:
            break
        }
    }
}
