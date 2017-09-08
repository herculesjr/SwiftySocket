//
//  SwiftySocket.swift
//  SwiftySocket
//
//  Created by Hercules Cunha on 20/08/17.
//  Copyright © 2017 Hercules Jr. All rights reserved.
//

import Foundation

public enum SwiftySocketError: Error {
    
    case timeout
    case unknown
    
    static func buildError(given error: Error?) -> SwiftySocketError {
        return unknown
    }
}
