//
//  Protocols.swift
//  Health Import
//
//  Created by Antonio Carranza López on 14/4/16.
//  Copyright © 2016 Antonio Carranza López. All rights reserved.
//

import Foundation

// MARK: Protocolo para XML Parser
protocol XMLParserDelegate{
    func parsingWasFinished(xmlParser: XMLParser)
    func saveElementsParsed(xmlParser: XMLParser)
    func createBackupFileRegister(XMLParser: XMLParser) -> BackupFile?
    func errorParsing(xmlParser: XMLParser, error: NSError)
}