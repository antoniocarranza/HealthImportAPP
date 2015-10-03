//
//  MasterViewController.swift
//  Health Importer
//
//  Created by Antonio Carranza López on 26/9/15.
//  Copyright © 2015 Antonio Carranza López. All rights reserved.
//

import UIKit
import CoreData
import HealthKit

// MARK: - Extension

extension String {
    
    func stringByAppendingPathComponent(path: String) -> String {
        
        let nsSt = self as NSString
        return nsSt.stringByAppendingPathComponent(path)
    }
}

// MARK: - Class

class MasterViewController: UITableViewController, NSFetchedResultsControllerDelegate, XMLParserDelegate {

    // MARK: - Variables and Propoerties
    
    var detailViewController: DetailTableViewController? = nil
    var managedObjectContext: NSManagedObjectContext? = nil
    let healthStore = HKHealthStore()
    
    // MARK: - Application live cicle
    
    override func viewDidLoad() {
        super.viewDidLoad()
        // Do any additional setup after loading the view, typically from a nib.
        //self.navigationItem.leftBarButtonItem = self.editButtonItem()

        //let addButton = UIBarButtonItem(barButtonSystemItem: .Add, target: self, action: "insertNewObject:")
        //self.navigationItem.rightBarButtonItem = addButton
        
        let refreshButton = UIBarButtonItem(barButtonSystemItem: .Refresh, target: self, action: "refreshDocumentsFolderFileList:")
        self.navigationItem.rightBarButtonItem = refreshButton
        
        if let split = self.splitViewController {
            let controllers = split.viewControllers
            self.detailViewController = (controllers[controllers.count-1] as! UINavigationController).topViewController as? DetailTableViewController
        }
        
        refreshDocumentsFolderFileList(self)
        
    }

    override func viewWillAppear(animated: Bool) {
        self.clearsSelectionOnViewWillAppear = self.splitViewController!.collapsed
        super.viewWillAppear(animated)
    }

    override func didReceiveMemoryWarning() {
        super.didReceiveMemoryWarning()
        // Dispose of any resources that can be recreated.
    }

    // MARK: - Documents and Parsing
    
    func refreshDocumentsFolderFileList(sender: AnyObject) {
        print("refreshDocumentsFolderFileList:")
        let context = self.fetchedResultsController.managedObjectContext
        //let entity = self.fetchedResultsController.fetchRequest.entity!
        
        //Eliminamos los elementos actuales
        let request = NSFetchRequest(entityName: "BackupFile")
        
        do {
            var myList = try context.executeFetchRequest(request)
            for item: AnyObject in myList
            {
                context.deleteObject(item as! NSManagedObject)
            }
            myList.removeAll(keepCapacity: false)
            try context.save()
            self.tableView.reloadData()

        } catch {
            print("Error")
        }
        
        //Mandamos al parser leer los ficheros del document Directory
        var paths = NSSearchPathForDirectoriesInDomains(.DocumentDirectory, .UserDomainMask, true)
        var documentsDirectory : String;
        documentsDirectory = paths[0] as String
        let fileManager: NSFileManager = NSFileManager()
        do {
            let fileList = try fileManager.contentsOfDirectoryAtPath(documentsDirectory)
            for name in fileList {
                let xmlParser: XMLParser = XMLParser()
                let fileURLWithPath: String = documentsDirectory.stringByAppendingPathComponent(name)
                print("Realizando el parsing a \(fileURLWithPath)")
                xmlParser.delegate = self
                xmlParser.startParsingWithContentsOfURL(NSURL(fileURLWithPath: fileURLWithPath), fileName: name)
            }
        } catch {
            print("Error Cargando el listado de ficheros!")
        }
    }

    func parsingWasFinished(xmlParser: XMLParser) {
        //Cuando el Parser va terminando de leer los documentos los carga en la tabla y avisa a la vista
        
        print("parsingWasFinished:")
        let context = self.fetchedResultsController.managedObjectContext
        let entity = self.fetchedResultsController.fetchRequest.entity!

        let newBackupFile = NSEntityDescription.insertNewObjectForEntityForName(entity.name!, inManagedObjectContext: context) as! BackupFile
        //newManagedObject.setValue(xmlParser.fileName, forKey: "name")        
        newBackupFile.fileURLWithPath = xmlParser.fileURLWithPath!.description
        newBackupFile.fileName = xmlParser.fileName
        newBackupFile.exportDate = xmlParser.exportDate
        newBackupFile.lastImportDate = nil
        
        let formateador = NSDateFormatter()
        formateador.dateFormat = "yyyyMMddHHmmssZ"
        
        for sample in xmlParser.samples {
            if sample["type"] == "HKQuantityTypeIdentifierBodyMass" {
                let newSample = NSEntityDescription.insertNewObjectForEntityForName("QuantitySample", inManagedObjectContext: context) as! QuantitySample
                newSample.source = sample["source"]
                newSample.startDate = formateador.dateFromString(sample["startDate"]!)
                newSample.endDate = formateador.dateFromString(sample["endDate"]!)
                newSample.quantityType = sample["unit"]
                newSample.quantity = NSString(string: sample["value"]!).doubleValue
                newSample.backupFile = newBackupFile
                newSample.foundInHealthKit = findSampleInHealthKit(newSample)

                //Cabria preguntarse si dicha muestra existe ya en la base de datos de HealthKit, si existe una identica no tiene sentido importar
                //Podriamos marcarla como ya importada
                
                let type = HKObjectType.quantityTypeForIdentifier("HKQuantityTypeIdentifierBodyMass")
                
                //Query por fecha exacta
                let explicitTimeInterval = NSPredicate(format: "%K = %@ AND %K = %@",
                    HKPredicateKeyPathEndDate, newSample.startDate!,
                    HKPredicateKeyPathStartDate, newSample.endDate!)
                
                //Query por cantidad y unidades kg...
                let unit = HKUnit(fromString: newSample.quantityType!)
                let value = newSample.quantity?.doubleValue
                let quantity = HKQuantity(unit: unit, doubleValue: value!)

                //let explicitValue = NSPredicate(format: "%K = %@", HKPredicateKeyPathQuantity, quantity)
                let explicitValue = HKQuery.predicateForQuantitySamplesWithOperatorType(.EqualToPredicateOperatorType, quantity: quantity)
                
                //Query por intervalo de fechas (no vale)
                //let predicateByDate = HKQuery.predicateForSamplesWithStartDate(newSample.startDate, endDate: newSample.endDate, options: .None)
                
                //Query por dos predicados
                let compoundQuery = NSCompoundPredicate(andPredicateWithSubpredicates: [explicitTimeInterval,explicitValue])
                
                //print("Sample buscado:\r\r\(newSample)\r\r")
                //print(predicateByDate)
                
                let hkQuery = HKSampleQuery(sampleType: type!, predicate: compoundQuery, limit: 10, sortDescriptors: nil, resultsHandler: { (hkSampleQuery, querySamples, error) -> Void in
                    if (error != nil) {
                        print(error)
                        return
                    }
                    //print("Consulta finalizada para \(hkSampleQuery.predicate!) encontradas \( querySamples!.count) coincidencias")
                    
                    newSample.foundInHealthKit = true

                })
                self.healthStore.executeQuery(hkQuery)
                
            }
            
            
            
            //let unit = HKUnit(fromString: sample["unit"]!)
            //let value = (sample["value"]! as NSString).doubleValue
            //let quantity = HKQuantity(unit: unit, doubleValue: value)
            //let sample = HKQuantitySample(type: quantityType!, quantity: quantity, startDate: startDate!, endDate: endDate!, metadata: metadata)
            
        }
        
        // Intentamos guardar los nuevos datos en tabla.
        do {
            try context.save()
            self.tableView.reloadData()
            print("Recargando los datos de la tabla")
        } catch {
            // Replace this implementation with code to handle the error appropriately.
            // abort() causes the application to generate a crash log and terminate. You should not use this function in a shipping application, although it may be useful during development.
            print("Unresolved error \(error)")
            abort()
        }
    }

    func findSampleInHealthKit(sample: QuantitySample) -> Bool {
        
        
            return false

        // we create a predicate to filter our data
//        let bodyMassType = HKObjectType.quantityTypeForIdentifier(HKQuantityTypeIdentifierBodyMass)
//        let predicate = HKQuery.predicateForSamplesWithStartDate(sample.startDate ,endDate: sample.endDate ,options: .None)
//        
//        let unit = HKUnit(fromString: "Kg")
//        let value = (sample.quantity as! Double)
//        let quantity = HKQuantity(unit: unit, doubleValue: value)
//        let predicate2 = HKQuery.predicateForQuantitySamplesWithOperatorType(NSPredicateOperatorType.EqualToPredicateOperatorType, quantity: quantity)
//        
//        let compPredicate = NSCompoundPredicate(andPredicateWithSubpredicates: [predicate, predicate2])
//        
//        // I had a sortDescriptor to get the recent data first
//        
//        let sortDescriptor = NSSortDescriptor(key: HKSampleSortIdentifierEndDate, ascending: false)
//        
//        // we create our query with a block completion to execute
//        
//        let query = HKSampleQuery(sampleType: bodyMassType!, predicate: compPredicate, limit: 30, sortDescriptors: [sortDescriptor]) { (query, tmpResult, error) -> Void in
//            
//            if error != nil {
//                
//                // something happened
//                print("Error")
//                return
//                
//                
//            }
//            
//            if let result = tmpResult {
//                
//                print("Resultados")
//                // do something with my data
//                for item in result {
//                    if let sample = item as? HKQuantitySample {
//                        
//                        //let value = (sample.value == HKCategoryValueSleepAnalysis.InBed.rawValue) ? "InBed" : "Asleep"
//                        
//                        print("Healthkit Peso: \(sample.startDate) \(sample.endDate) - source: \(sample.sourceRevision.source.name) - value: \(sample.quantity)")
//                    }
//                }
//            }
//        }
//        
//        
//        // finally, we execute our query
//        healthStore.executeQuery(query)
//        return true
    }

    
    // MARK: - Segues

    override func prepareForSegue(segue: UIStoryboardSegue, sender: AnyObject?) {
        if segue.identifier == "showDetail" {
            if let indexPath = self.tableView.indexPathForSelectedRow {
            let SelectedBackupFile = self.fetchedResultsController.objectAtIndexPath(indexPath)
                let controller = (segue.destinationViewController as! UINavigationController).topViewController as! DetailTableViewController
                controller.detailItem = (SelectedBackupFile as! BackupFile)
                controller.navigationItem.leftBarButtonItem = self.splitViewController?.displayModeButtonItem()
                controller.navigationItem.leftItemsSupplementBackButton = true
            }
        }
    }

    // MARK: - Table View

    override func numberOfSectionsInTableView(tableView: UITableView) -> Int {
        return self.fetchedResultsController.sections?.count ?? 0
    }

    override func tableView(tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        let sectionInfo = self.fetchedResultsController.sections![section]
        return sectionInfo.numberOfObjects

    }

    override func tableView(tableView: UITableView, cellForRowAtIndexPath indexPath: NSIndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCellWithIdentifier("Cell", forIndexPath: indexPath)
        self.configureCell(cell, atIndexPath: indexPath)
        return cell
    }

    override func tableView(tableView: UITableView, canEditRowAtIndexPath indexPath: NSIndexPath) -> Bool {
        // Return false if you do not want the specified item to be editable.
        return true
    }

    override func tableView(tableView: UITableView, commitEditingStyle editingStyle: UITableViewCellEditingStyle, forRowAtIndexPath indexPath: NSIndexPath) {
        if editingStyle == .Delete {
            let context = self.fetchedResultsController.managedObjectContext
            context.deleteObject(self.fetchedResultsController.objectAtIndexPath(indexPath) as! NSManagedObject)
                
            do {
                try context.save()
            } catch {
                // Replace this implementation with code to handle the error appropriately.
                // abort() causes the application to generate a crash log and terminate. You should not use this function in a shipping application, although it may be useful during development.
                //print("Unresolved error \(error), \(error.userInfo)")
                abort()
            }
        }
    }

    func configureCell(cell: UITableViewCell, atIndexPath indexPath: NSIndexPath) {
        let object = self.fetchedResultsController.objectAtIndexPath(indexPath)
        cell.textLabel!.text = object.valueForKey("fileName")!.description
        let formateador = NSDateFormatter()
        formateador.dateStyle = .LongStyle
        formateador.timeStyle = .ShortStyle
        cell.detailTextLabel!.text = formateador.stringFromDate(object.valueForKey("exportDate") as! NSDate)
    }

    // MARK: - Fetched results controller

    var fetchedResultsController: NSFetchedResultsController {
        if _fetchedResultsController != nil {
            return _fetchedResultsController!
        }
        
        let fetchRequest = NSFetchRequest()
        // Edit the entity name as appropriate.
        let entity = NSEntityDescription.entityForName("BackupFile", inManagedObjectContext: self.managedObjectContext!)
        fetchRequest.entity = entity
        
        // Set the batch size to a suitable number.
        fetchRequest.fetchBatchSize = 20
        
        // Edit the sort key as appropriate.
        let sortDescriptor = NSSortDescriptor(key: "fileName", ascending: false)
        
        fetchRequest.sortDescriptors = [sortDescriptor]
        
        // Edit the section name key path and cache name if appropriate.
        // nil for section name key path means "no sections".
        let aFetchedResultsController = NSFetchedResultsController(fetchRequest: fetchRequest, managedObjectContext: self.managedObjectContext!, sectionNameKeyPath: nil, cacheName: "Master")
        aFetchedResultsController.delegate = self
        _fetchedResultsController = aFetchedResultsController
        
        do {
            try _fetchedResultsController!.performFetch()
        } catch {
             // Replace this implementation with code to handle the error appropriately.
             // abort() causes the application to generate a crash log and terminate. You should not use this function in a shipping application, although it may be useful during development. 
             //print("Unresolved error \(error), \(error.userInfo)")
             abort()
        }
        
        return _fetchedResultsController!
    }    
    var _fetchedResultsController: NSFetchedResultsController? = nil

    func controllerWillChangeContent(controller: NSFetchedResultsController) {
        self.tableView.beginUpdates()
    }

    func controller(controller: NSFetchedResultsController, didChangeSection sectionInfo: NSFetchedResultsSectionInfo, atIndex sectionIndex: Int, forChangeType type: NSFetchedResultsChangeType) {
        switch type {
            case .Insert:
                self.tableView.insertSections(NSIndexSet(index: sectionIndex), withRowAnimation: .Fade)
            case .Delete:
                self.tableView.deleteSections(NSIndexSet(index: sectionIndex), withRowAnimation: .Fade)
            default:
                return
        }
    }

    func controller(controller: NSFetchedResultsController, didChangeObject anObject: AnyObject, atIndexPath indexPath: NSIndexPath?, forChangeType type: NSFetchedResultsChangeType, newIndexPath: NSIndexPath?) {
        switch type {
            case .Insert:
                tableView.insertRowsAtIndexPaths([newIndexPath!], withRowAnimation: .Fade)
            case .Delete:
                tableView.deleteRowsAtIndexPaths([indexPath!], withRowAnimation: .Fade)
            case .Update:
                self.configureCell(tableView.cellForRowAtIndexPath(indexPath!)!, atIndexPath: indexPath!)
            case .Move:
                tableView.deleteRowsAtIndexPaths([indexPath!], withRowAnimation: .Fade)
                tableView.insertRowsAtIndexPaths([newIndexPath!], withRowAnimation: .Fade)
        }
    }

    func controllerDidChangeContent(controller: NSFetchedResultsController) {
        self.tableView.endUpdates()
    }

    /*
     // Implementing the above methods to update the table view in response to individual changes may have performance implications if a large number of changes are made simultaneously. If this proves to be an issue, you can instead just implement controllerDidChangeContent: which notifies the delegate that all section and object changes have been processed.
     
     func controllerDidChangeContent(controller: NSFetchedResultsController) {
         // In the simplest, most efficient, case, reload the table view.
         self.tableView.reloadData()
     }
     */

}



