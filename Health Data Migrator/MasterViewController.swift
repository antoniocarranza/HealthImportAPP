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
    
    @IBOutlet weak var progressBar: UIProgressView!
    
    // MARK: - Application live cicle
    
    override func viewDidLoad() {
        super.viewDidLoad()
        // Do any additional setup after loading the view, typically from a nib.
        //self.navigationItem.leftBarButtonItem = self.editButtonItem()

        //let addButton = UIBarButtonItem(barButtonSystemItem: .Add, target: self, action: "insertNewObject:")
        //self.navigationItem.rightBarButtonItem = addButton
        
        progressBar.hidden = true
        
        let refreshButton = UIBarButtonItem(barButtonSystemItem: .Refresh, target: self, action: "refreshDocumentsFolderFileList:")
        self.navigationItem.rightBarButtonItem = refreshButton
        
        if let split = self.splitViewController {
            let controllers = split.viewControllers
            self.detailViewController = (controllers[controllers.count-1] as! UINavigationController).topViewController as? DetailTableViewController
        }
        
    }

    override func viewWillAppear(animated: Bool) {
        self.clearsSelectionOnViewWillAppear = self.splitViewController!.collapsed
        super.viewWillAppear(animated)

        //Asignamos función al pull to refresh y cambiamos el titulo
        self.refreshControl?.addTarget(self, action: "refreshDocumentsFolderFileList:", forControlEvents: UIControlEvents.ValueChanged)
        self.refreshControl?.attributedTitle = NSAttributedString(string: NSLocalizedString("PullToRefresh", comment: "Pull to Refresh"))
        //Actualizamos la lista de documentos
        //refreshDocumentsFolderFileList(self)


    }

    override func didReceiveMemoryWarning() {
        super.didReceiveMemoryWarning()
        // Dispose of any resources that can be recreated.
    }

    // MARK: - Documents and Parsing
    
    func refreshDocumentsFolderFileList(sender: AnyObject) {
        
        print("refreshDocumentsFolderFileList:")
        
        self.refreshControl?.attributedTitle = NSAttributedString(string: NSLocalizedString("Refreshing", comment: "Refreshing"))
        //var progreso: Float = 0
        //progressBar.setProgress(0, animated: false)
        //progressBar.hidden = false
        
        //let backgroundQueue = dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_BACKGROUND, 0)
        let mainQueue = dispatch_get_main_queue()
        
        dispatch_async(mainQueue) { () -> Void in
            
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
                //self.tableView.reloadData()
                
            } catch {
                print("Unresolved error \(error)")
            }
            
            var paths = NSSearchPathForDirectoriesInDomains(.DocumentDirectory, .UserDomainMask, true)
            var documentsDirectory : String;
            documentsDirectory = paths[0] as String
            let fileManager: NSFileManager = NSFileManager()
            do {
                let fileList = try fileManager.contentsOfDirectoryAtPath(documentsDirectory)
                print(documentsDirectory)
                //let incremento: Float = 1.0 / Float(fileList.count)
                for name in fileList {
                    //progreso +=  incremento
                    if name.hasSuffix(".xml") {
                        let xmlParser: XMLParser = XMLParser()
                        let fileURLWithPath: String = documentsDirectory.stringByAppendingPathComponent(name)
                        print("Realizando el parsing a \(fileURLWithPath)")
                        xmlParser.delegate = self
                        xmlParser.processOnlyHeader = false
                        xmlParser.startParsingWithContentsOfURL(NSURL(fileURLWithPath: fileURLWithPath), fileName: name)
                    }
//                    dispatch_async(dispatch_get_main_queue(), { () -> Void in
//                        self.progressBar.setProgress(progreso, animated: true)
//                    })
                }
            } catch {
                print("Error Cargando el listado de ficheros!")
            }
            dispatch_async(dispatch_get_main_queue(), { () -> Void in
                self.refreshControl?.endRefreshing()
                self.refreshControl?.attributedTitle = NSAttributedString(string: NSLocalizedString("PullToRefresh", comment: "Pull to Refresh"))
                self.tableView.reloadData()
            })

        }
        
        //Mandamos al parser leer los ficheros del document Directory
        //progressBar.setProgress(0, animated: false)
        //progressBar.hidden = true
        
    }
    
    func parsingWasFinished(xmlParser: XMLParser) {
        
        //Cuando el Parser va terminando de leer los documentos los carga en la tabla y avisa a la vista
        
        print("parsingWasFinished:")
        
        tableView.beginUpdates()
        
        let context = self.fetchedResultsController.managedObjectContext
        let entity = self.fetchedResultsController.fetchRequest.entity!

        let newBackupFile = NSEntityDescription.insertNewObjectForEntityForName(entity.name!, inManagedObjectContext: context) as! BackupFile
        //newManagedObject.setValue(xmlParser.fileName, forKey: "name")        
        newBackupFile.fileURLWithPath = xmlParser.fileURLWithPath!.description
        newBackupFile.fileName = xmlParser.fileName
        newBackupFile.exportDate = xmlParser.exportDate
        newBackupFile.lastImportDate = nil
        
        //pedirPermisos(newBackupFile)
        
        let formateador = NSDateFormatter()
        formateador.dateFormat = "yyyyMMddHHmmssZ"
        
        for sample in xmlParser.samples {
            let sampleType = sample["type"]
            
            if sampleType?.hasPrefix("HKQuantityType") == true {
                
                let newSample = NSEntityDescription.insertNewObjectForEntityForName("QuantitySample", inManagedObjectContext: context) as! QuantitySample
                if sample["source"] != nil {
                    newSample.source = sample["source"]!
                }
                if sample["startDate"] != nil {
                    newSample.startDate = formateador.dateFromString(sample["startDate"]!)!
                }
                if sample["endDate"] != nil {
                    newSample.endDate = formateador.dateFromString(sample["endDate"]!)!
                }
                if let tmpUnit = sample["unit"]  {
                    newSample.quantityType = tmpUnit
                }
                if sample["value"] != nil {
                    newSample.quantity = NSString(string: sample["value"]!).doubleValue
                }
                
                newSample.backupFile = newBackupFile
                newSample.typeIdentifier = sampleType!
                
                
            } else {
                print("SampleType not implemented \(sampleType!)")
            }
        }
        
//        //Solicitamos autorización para los tipos detectados en el fichero
//        healthStore.requestAuthorizationToShareTypes(hkSampleTypes, readTypes: hkSampleTypes, completion: {
//            (success, error) -> Void in
//            print("Autorización solicitada: \(success), Error: \(error)")
//        })
      
        // Intentamos guardar los nuevos datos en tabla.
        do {
            try context.save()
            print("context saved")
            print("Recargando los datos de la tabla")
        } catch {
            // Replace this implementation with code to handle the error appropriately.
            // abort() causes the application to generate a crash log and terminate. You should not use this function in a shipping application, although it may be useful during development.
            print("Unresolved error \(error)")
            //abort()
        }
        tableView.endUpdates()
        tableView.reloadData()
    }
    
    // MARK: - Segues
    
    override func prepareForSegue(segue: UIStoryboardSegue, sender: AnyObject?) {
        if segue.identifier == "showDetail" {
            if let indexPath = self.tableView.indexPathForSelectedRow {
                
                let selectedBackupFile = (self.fetchedResultsController.objectAtIndexPath(indexPath) as! BackupFile)
                self.pedirPermisos(selectedBackupFile)
                
                let controller = (segue.destinationViewController as! UINavigationController).topViewController as! DetailTableViewController
                controller.detailItem = selectedBackupFile
                controller.navigationItem.leftBarButtonItem = self.splitViewController?.displayModeButtonItem()
                controller.navigationItem.leftItemsSupplementBackButton = true
            }
        }
    }
    
    // Actualizacción de permisos
    func pedirPermisos(backupFile: BackupFile) {
        
        if HKHealthStore.isHealthDataAvailable() {
            print("HealhtKit esta disponible. Solicitando permisos...")
            //TODO : Sería conveniente trasladarlo a los tipos detectados en el fichero a importar
            //Autorización para leer/Escribir ciertos tipos
            
            if backupFile.quantitySamples?.count > 0 {
                var hkQuantitySampleTypes: Set<HKSampleType> = []
                for quantitySample in backupFile.quantitySamples! {
                    let hkQuantitySampleType = (quantitySample as! QuantitySample)
                    hkQuantitySampleTypes.insert(HKObjectType.quantityTypeForIdentifier(hkQuantitySampleType.typeIdentifier)!)
                }
                if hkQuantitySampleTypes.count > 0 {
                    self.healthStore.requestAuthorizationToShareTypes(hkQuantitySampleTypes, readTypes: hkQuantitySampleTypes, completion: {
                        (success, error) -> Void in
                        print("Petición de permisos para \(hkQuantitySampleTypes)\r con resultado de \(success), Error: \(error)")

                    })
                }
            }
        } else {
            print("HealthKit no esta disponible")
        }
    }
    
    // MARK: - Table View

    override func numberOfSectionsInTableView(tableView: UITableView) -> Int {
        //return self.fetchedResultsController.sections?.count ?? 0
        if (self.fetchedResultsController.fetchedObjects?.count != 0) {
            self.tableView.separatorStyle = .SingleLine
            self.tableView.backgroundView = nil
        } else {
            let pullToRefreshMessage = UILabel()
            pullToRefreshMessage.text = NSLocalizedString("PullToRefreshIfNoDataItunes", comment: "Pull to Refresh or transfer files from itunes")
            pullToRefreshMessage.numberOfLines = 0
            pullToRefreshMessage.textAlignment = .Center
            pullToRefreshMessage.font = UIFont(name: "Palatino-Italic", size: 20)
            pullToRefreshMessage.textColor = UIColor.grayColor()
            self.tableView.backgroundView = pullToRefreshMessage
            self.tableView.separatorStyle = .None
        }
        return (self.fetchedResultsController.sections?.count)!
    }

    override func tableView(tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        let sectionInfo = self.fetchedResultsController.sections![section]
        return sectionInfo.numberOfObjects

    }

    override func tableView(tableView: UITableView, heightForRowAtIndexPath indexPath: NSIndexPath) -> CGFloat {
        return 80
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
        let formateador = NSDateFormatter()
        formateador.dateStyle = .LongStyle
        formateador.timeStyle = .ShortStyle
        
        let samples = NSLocalizedString("Samples", comment: "Samples")
        let exportedOn = NSLocalizedString("ExportedOn", comment: "Exported on")
        let backupFile = (self.fetchedResultsController.objectAtIndexPath(indexPath) as! BackupFile)
        let samplesCount = backupFile.quantitySamples!.count
        let exportDate = formateador.stringFromDate(backupFile.exportDate!)
        let fileName = backupFile.fileName
        cell.textLabel!.text = fileName
        cell.detailTextLabel!.text = "\(samplesCount) \(samples)\r\(exportedOn) \(exportDate)"
        //cell.imageView!.frame = CGRectMake(0, 0, 32, 32)
        
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

    
     // Implementing the above methods to update the table view in response to individual changes may have performance implications if a large number of changes are made simultaneously. If this proves to be an issue, you can instead just implement controllerDidChangeContent: which notifies the delegate that all section and object changes have been processed.
     
//     func controllerDidChangeContent(controller: NSFetchedResultsController) {
//         // In the simplest, most efficient, case, reload the table view.
//         self.tableView.reloadData()
//     }
    

}



