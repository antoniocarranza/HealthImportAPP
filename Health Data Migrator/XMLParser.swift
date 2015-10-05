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
}

class XMLParser: NSObject, NSXMLParserDelegate {

    var fileName: String?
    var exportDate: NSDate?
    var fileURLWithPath: NSURL?
    var delegate: XMLParserDelegate?
    var isValidBackupFile: Bool = false
    var samples:[Dictionary<String,String>] = []
    var processOnlyHeader: Bool = false
    
    func startParsingWithContentsOfURL(rssURL: NSURL, fileName: String) {
        let parser = NSXMLParser(contentsOfURL: rssURL)
        self.fileName = fileName
        self.fileURLWithPath = rssURL
        parser?.delegate = self
        parser!.parse()
    }
    
    func parser(parser: NSXMLParser, didStartElement elementName: String, namespaceURI: String?, qualifiedName qName: String?, var attributes attributeDict: [String : String]) {

        if elementName == "Record" {
            if !self.processOnlyHeader {
                samples.append(attributeDict)
            }
        }
        if elementName == "HealthData" {
            self.isValidBackupFile = true
        }
        if elementName == "ExportDate" {
            let formateador = NSDateFormatter()
            formateador.dateFormat = "yyyyMMddHHmmssZ"
            self.exportDate = formateador.dateFromString(attributeDict["value"]!)
            //TODO : Ver que pasa con la fecha en el simulador
            //self.exportDate = NSDate()
        }
    }
    
    func parserDidEndDocument(parser: NSXMLParser) {
        if (self.exportDate != nil) && (self.isValidBackupFile)  {
            delegate?.parsingWasFinished(self)
        } else {
            print("El fichero no es valido")
        }
    }
    
    func parser(parser: NSXMLParser, parseErrorOccurred parseError: NSError) {
        print(parseError.description)
    }
    
    func parser(parser: NSXMLParser, validationErrorOccurred validationError: NSError) {
        print(validationError.description)
    }
    
}
