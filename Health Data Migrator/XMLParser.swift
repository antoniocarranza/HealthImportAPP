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
    func errorParsing(xmlParser: XMLParser, error: NSError)
}

class XMLParser: NSObject, NSXMLParserDelegate {

    var fileName: String = ""
    var exportDate: NSDate?
    var fileURLWithPath: NSURL?
    var delegate: XMLParserDelegate?
    var isValidBackupFile: Bool = false
    var samples:[Dictionary<String,String>] = []
    var processOnlyHeader: Bool = false
    var startTime: NSDate = NSDate()
    var endTime: NSDate = NSDate()
    var coredataBackupFile: BackupFile?
    var coredataBackupFileId: NSManagedObjectID?
    var quantitySamplesCount: Double = 0
    var permissionsList = Set<String>()

    
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
        if samples.count == 25000 {
            delegate?.saveElementsParsed(self)
            samples.removeAll()
        }
    }
    
    func parser(parser: NSXMLParser, didStartElement elementName: String, namespaceURI: String?, qualifiedName qName: String?, var attributes attributeDict: [String : String]) {

        if coredataBackupFile != nil {
            if elementName == "Record" {
                quantitySamplesCount += 1
                if !self.processOnlyHeader {
                    if attributeDict["type"] != "HKQuantityTypeIdentifierNikeFuel" && attributeDict["type"] != "HKQuantityTypeIdentifierAppleExerciseTime" {
                        samples.append(attributeDict)
                        permissionsList.insert(attributeDict["type"]!)
                    }
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
                coredataBackupFileId = coredataBackupFile!.objectID
            }
        }
        
    }
    
    func parserDidEndDocument(parser: NSXMLParser) {
        if (self.exportDate != nil) && (self.isValidBackupFile)  {
            log.debug("Fichero Valido")
        } else {
            log.debug("El fichero no es valido")
        }
        delegate?.saveElementsParsed(self)
        delegate?.parsingWasFinished(self)
    }
    
    func parser(parser: NSXMLParser, parseErrorOccurred parseError: NSError) {
        log.error("Error de proceso en xmlParser: \(parseError.description)")
        log.error(parseError.description)
        delegate?.saveElementsParsed(self)
        delegate?.parsingWasFinished(self)
        delegate?.errorParsing(self, error: parseError)
        
    }
    
    func parser(parser: NSXMLParser, validationErrorOccurred validationError: NSError) {
        log.error("Error de validación en xmlParser \(validationError.description)")
        delegate?.errorParsing(self, error: validationError)
    }
    

    
}
