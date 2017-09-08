import UIKit
import XCTest
@testable import SwiftySocket

class Tests: XCTestCase {
    
    var socket: SwiftySocket!
        
    func testConnectionTimeout() {
        let expectation = self.expectation(description: "testConnectionTimeout")
        socket = SwiftySocket(connectHandler: { (error: SwiftySocketError?) in
            XCTAssertEqual(error, .timeout)
            expectation.fulfill()
        }, disconnectHandler: { (error: SwiftySocketError?) in
            XCTFail()
        }, readHandler: { (data: Data) in
            XCTFail()
        })
        socket.readStream = InputStreamMock()
        socket.writeStream = OutputStreamMock()
        socket.connect(to: "somehost", port: 1, timeout: 2)
        waitForExpectations(timeout: 2, handler: nil)
    }
    
    func testConnectionSuccess() {
        let expectation = self.expectation(description: "testConnectionSuccess")
        socket = SwiftySocket(connectHandler: { (error: SwiftySocketError?) in
            XCTAssertNil(error)
            expectation.fulfill()
        }, disconnectHandler: { (error: SwiftySocketError?) in
            XCTFail()
        }, readHandler: { (data: Data) in
            XCTFail()
        })
        let inputMock = InputStreamMock()
        inputMock.mockDelegate = socket
        inputMock.openEvent = Stream.Event.openCompleted
        socket.readStream = inputMock
        socket.writeStream = OutputStreamMock()
        socket.connect(to: "somehost", port: 1, timeout: 2)
        
        waitForExpectations(timeout: 2, handler: nil)
    }
    
    func testConnectionReadOnConnect() {
        let expectation = self.expectation(description: "testConnectionReadOnConnect")
        
        let outputMock = OutputStreamMock()
        let inputMock = InputStreamMock()
        
        socket = SwiftySocket(connectHandler: { (error: SwiftySocketError?) in
            XCTAssertNil(error)
            outputMock.changeEvent(Stream.Event.hasBytesAvailable)
        }, disconnectHandler: { (error: SwiftySocketError?) in
            XCTFail()
        }, readHandler: { (data: Data) in
            XCTAssertEqual(data, Data([0xF0, 0x0D]))
            expectation.fulfill()
        })
        
        inputMock.mockDelegate = socket
        inputMock.openEvent = Stream.Event.openCompleted
        inputMock.dataToBeRead = Data([0xF0, 0x0D])
        socket.readStream = inputMock
        
        outputMock.mockDelegate = socket
        socket.writeStream = outputMock
        socket.connect(to: "somehost", port: 1, timeout: 2)
        
        waitForExpectations(timeout: 2, handler: nil)
    }
    
    func testConnectionSendOnConnect() {
        let expectation = self.expectation(description: "testConnectionReadOnConnect")
        
        let outputMock = OutputStreamMock()
        let inputMock = InputStreamMock()
        
        socket = SwiftySocket(connectHandler: { (error: SwiftySocketError?) in
            XCTAssertNil(error)
            self.socket.send(Data([0xF0, 0x0D]))
            expectation.fulfill()
        }, disconnectHandler: { (error: SwiftySocketError?) in
            XCTFail()
        }, readHandler: { (data: Data) in
            XCTFail()
        })
        
        inputMock.mockDelegate = socket
        inputMock.openEvent = Stream.Event.openCompleted
        socket.readStream = inputMock
        
        outputMock.mockDelegate = socket
        socket.writeStream = outputMock
        socket.connect(to: "somehost", port: 1, timeout: 2)
        
        waitForExpectations(timeout: 2, handler: nil)
        
        XCTAssertEqual(outputMock.dataSent, Data([0xF0, 0x0D]))
    }
}

class InputStreamMock: InputStream {
    
    var openEvent: Stream.Event!
    var mockDelegate: StreamDelegate?
    var dataToBeRead: Data!
    
    override func read(_ buffer: UnsafeMutablePointer<UInt8>, maxLength len: Int) -> Int {
        dataToBeRead.withUnsafeBytes({ buffer.assign(from: $0, count: dataToBeRead.count)})
        let len = dataToBeRead.count
        dataToBeRead = nil
        return len
    }
    
    override func close() {
    }
    
    override func open() {
        mockDelegate?.stream?(self, handle: openEvent)
    }
    
    override var hasBytesAvailable: Bool {
        return dataToBeRead != nil
    }
}

class OutputStreamMock: OutputStream {
    
    var mockDelegate: StreamDelegate?
    var dataSent: Data!
    
    func changeEvent(_ event: Stream.Event) {
        mockDelegate?.stream?(self, handle: event)
    }
    
    override func write(_ buffer: UnsafePointer<UInt8>, maxLength len: Int) -> Int {
        dataSent = Data(bytes: buffer, count: len)
        return len
    }
    
    override var hasSpaceAvailable: Bool {
        return true
    }
    
    override func close() {
    }
    
    override func open() {
    }
}
