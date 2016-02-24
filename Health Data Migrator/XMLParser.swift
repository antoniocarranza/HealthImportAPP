//
//  XMLParser.swift
//  HealthDataMigrator
//
//  Created by Antonio Carranza López on 20/7/15.
//  Copyright © 2015 Antonio Carranza López. All rights reserved.
//

import UIKit
import CoreData
import HealthKit

protocol XMLParserDelegate{
    func parsingWasFinished(xmlParser: XMLParser)
    func saveElementsParsed(xmlParser: XMLParser)
    func createBackupFileRegister(XMLParser: XMLParser) -> BackupFile?
}

class XMLParser: NSObject, NSXMLParserDelegate {

    var fileName: String?
    var exportDate: NSDate?
    var fileURLWithPath: NSURL?
    var delegate: XMLParserDelegate?
    var isValidBackupFile: Bool = false
    var samples:[Dictionary<String,String>] = []
    var processOnlyHeader: Bool = false
    var startTime: NSDate = NSDate()
    var endTime: NSDate = NSDate()
    var coredataBackupFile: BackupFile?
    
    let formateador: NSDateFormatter = {
        var formateadorInterno = NSDateFormatter()
        formateadorInterno.dateFormat = "yyyyMMddHHmmssZ"
        return formateadorInterno
    }()
    
    
    
    
    func startParsingWithContentsOfURL(rssURL: NSURL, fileName: String) {
        let parser = NSXMLParser(contentsOfURL: rssURL)
        self.fileName = fileName
        self.fileURLWithPath = rssURL
        parser?.delegate = self
        parser!.parse()
    }
    
    func parser(parser: NSXMLParser, didEndElement elementName: String, namespaceURI: String?, qualifiedName qName: String?) {
        if samples.count > 50000 {
            delegate?.saveElementsParsed(self)
            samples.removeAll()
        }
    }
    
    func parser(parser: NSXMLParser, didStartElement elementName: String, namespaceURI: String?, qualifiedName qName: String?, var attributes attributeDict: [String : String]) {

        if coredataBackupFile != nil {
            if elementName == "Record" {
                if !self.processOnlyHeader {
                    samples.append(attributeDict)
                } else {
                    delegate?.parsingWasFinished(self)
                    parser.abortParsing()
                }
            }
        }
        
        if elementName == "HealthData" {
            self.isValidBackupFile = true
        }
        if elementName == "ExportDate" {
            self.exportDate = formateador.dateFromString(attributeDict["value"]!)
            if self.exportDate == nil {
                formateador.dateFormat = "yyyy-MM-dd HH:mm:ss Z"
                self.exportDate = formateador.dateFromString(attributeDict["value"]!)
            }
            //TODO : Ver que pasa con la fecha en el simulador

        }
        
        if coredataBackupFile == nil {
            if (self.exportDate != nil) && (self.isValidBackupFile)  {
                coredataBackupFile = delegate?.createBackupFileRegister(self)
            }
        }
        
    }
    
    func parserDidEndDocument(parser: NSXMLParser) {
        if (self.exportDate != nil) && (self.isValidBackupFile)  {
            print("Fichero Valido")
        } else {
            print("El fichero no es valido")
        }
        delegate?.parsingWasFinished(self)
        delegate?.saveElementsParsed(self)
    }
    
    func parser(parser: NSXMLParser, parseErrorOccurred parseError: NSError) {
        print(parseError.description)
    }
    
    func parser(parser: NSXMLParser, validationErrorOccurred validationError: NSError) {
        print(validationError.description)
    }
    
}
