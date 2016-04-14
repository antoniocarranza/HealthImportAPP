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

// MARK: Parseador
class XMLParser: NSObject, NSXMLParserDelegate {

    // MARK: Propiedades
    var delegate: XMLParserDelegate?
    var fileName: String = ""                       // Nombre del archivo que se mostrará al usuario
    var exportDate: NSDate?                         // Fecha de exportación del XML
    var fileURLWithPath: NSURL?                     // Ubicación en disco del XML
    
    var isValidBackupFile: Bool = false             // Si tengo un elemento llamado HealthData y tengo una fecha de exportación valida es un fichero valido
    var samples:[Dictionary<String,String>] = []    // Samples encontrados, un array de diccionario, esto podría ser un struc
    var permissionsList = Set<String>()             // Lista de permisos necesarios para importar este XML
    
    let startTime: NSDate = NSDate()                // Fecha y hora en la que se inicia el procesamiento del documento
    var endTime: NSDate = NSDate()                  // Fecha y hora en la que se termina el procesamiento del documento
    
    var coredataBackupFile: BackupFile?             // Nombre del fichero de copia en coredata
    var coredataBackupFileId: NSManagedObjectID?    // Identificador del fichero de copia en coredata
    var quantitySamplesCount: Double = 0            // Contador de Samples
    
    // MARK: Formateador de fechas
    let formateador: NSDateFormatter = {
        var formateadorInterno = NSDateFormatter()
        formateadorInterno.dateFormat = "yyyyMMddHHmmssZ"
        return formateadorInterno
    }()
    
    // MARK: Detección de elementos
    
    func startParsingWithContentsOfURL(fileURLWithPath: NSURL, fileName: String) {
        let parser = NSXMLParser(contentsOfURL: fileURLWithPath)
        self.fileName = fileName
        self.fileURLWithPath = fileURLWithPath
        parser?.delegate = self
        parser!.parse()
    }
    
    func parser(parser: NSXMLParser, didStartElement elementName: String, namespaceURI: String?, qualifiedName qName: String?, var attributes attributeDict: [String : String]) {
        
        if coredataBackupFile != nil {
            if elementName == "Record" {
                quantitySamplesCount += 1
                if attributeDict["type"] != "HKQuantityTypeIdentifierNikeFuel" && attributeDict["type"] != "HKQuantityTypeIdentifierAppleExerciseTime" {
                    samples.append(attributeDict)
                    permissionsList.insert(attributeDict["type"]!)
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
    
    func parser(parser: NSXMLParser, didEndElement elementName: String, namespaceURI: String?, qualifiedName qName: String?) {
        if samples.count == 25000 {
            delegate?.saveElementsParsed(self)
            samples.removeAll()
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
    
    // MARK: Control de Errores
    func parser(parser: NSXMLParser, validationErrorOccurred validationError: NSError) {
        log.error("Error de validación en xmlParser \(validationError.description)")
        delegate?.errorParsing(self, error: validationError)
    }

    func parser(parser: NSXMLParser, parseErrorOccurred parseError: NSError) {
        log.error("Error de proceso en xmlParser: \(parseError.description)")
        log.error(parseError.description)
        delegate?.saveElementsParsed(self)
        delegate?.parsingWasFinished(self)
        delegate?.errorParsing(self, error: parseError)
        
    }
}

// TODO: Debiese tener un inicializador y constantes en fileName, fileURLWithPath, startTime.
// TODO: isValidBackupFile debiese contamplar fecha de exportación y que haya existido un elemento llamado HealthData y que tenga registros

