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

    // MARK: - Variables and Properties
    
    var detailViewController: DetailTableViewController? = nil
    var managedObjectContext: NSManagedObjectContext? = nil
    var healthStore: HKHealthStore? = nil
    
    let paths = NSSearchPathForDirectoriesInDomains(.DocumentDirectory, .UserDomainMask, true)
    var documentsDirectory : String = ""
    var documentsToParse : Int = 0
    var documentsParsed : Int = 0
    var elementsSaved : Int = 0
    var applicationDocumentsDirectory: NSURL?
    var horaInicio: NSDate = NSDate()
    
    let formateador = NSDateFormatter()
    
    @IBOutlet weak var progressBar: UIProgressView!
    
    // MARK: - Application live cicle
    
    override func viewDidLoad() {
        super.viewDidLoad()
        // Do any additional setup after loading the view, typically from a nib.
        if let split = self.splitViewController {
            let controllers = split.viewControllers
            self.detailViewController = (controllers[controllers.count-1] as! UINavigationController).topViewController as? DetailTableViewController
        }
    }

    override func viewWillAppear(animated: Bool) {
        self.clearsSelectionOnViewWillAppear = self.splitViewController!.collapsed
        super.viewWillAppear(animated)

        //Asignamos función al pull to refresh y cambiamos el titulo
        self.refreshControl?.addTarget(self, action: #selector(MasterViewController.refreshDocumentsFolderFileList(_:)), forControlEvents: UIControlEvents.ValueChanged)
        self.refreshControl?.attributedTitle = NSAttributedString(string: NSLocalizedString("PullToRefresh", comment: "Pull to Refresh"))
    }

    override func didReceiveMemoryWarning() {
        super.didReceiveMemoryWarning()
        // Dispose of any resources that can be recreated.
        log.warning("La aplicacion ha recibido un memory warning")
    }

    // MARK: - Documents
    
    func getDocumentsFolderFileList() -> [String] {
        
        horaInicio = NSDate()
        log.debug("Hora de inicio del refresco: \(horaInicio)")
        
        var documentsFolderFileList: [String] = []
        documentsDirectory = paths[0] as String
        log.debug(documentsDirectory)
        let fileManager: NSFileManager = NSFileManager()
        do {
            let fileList = try fileManager.contentsOfDirectoryAtPath(documentsDirectory)
            for name in fileList {
                if name.hasSuffix(".xml") {
                    documentsFolderFileList.append(name)
                    documentsToParse += 1
                }
            }
            log.debug("Documentos a tratar: \(documentsToParse)")
            return documentsFolderFileList
        } catch {
            log.error("Error Cargando el listado de ficheros!")
            return []
        }
    }
    
    func refreshDocumentsFolderFileList(sender: AnyObject) {
        
        //log.debug("refreshDocumentsFolderFileList:")

        UIApplication.sharedApplication().idleTimerDisabled = true
        log.debug("Modo reposo desactivado")
        
        for fetchedObject in self.fetchedResultsController.fetchedObjects! {
            let backupFile = (fetchedObject as! BackupFile)
            deleteBackupFile(backupFile)
        }
        
        documentsParsed = 0
        documentsToParse = 0
        elementsSaved = 0
        
        let fileList = getDocumentsFolderFileList()
        
        for name in fileList {
            let xmlParser: XMLParser = XMLParser()
            let fileURLWithPath: String = documentsDirectory.stringByAppendingPathComponent(name)
            log.debug("Realizando el parsing a \(fileURLWithPath)")
            xmlParser.delegate = self
            xmlParser.processOnlyHeader = false
            xmlParser.startParsingWithContentsOfURL(NSURL(fileURLWithPath: fileURLWithPath), fileName: name)
        }
        self.refreshControl?.attributedTitle = NSAttributedString(string: NSLocalizedString("PullToRefresh", comment: "Pull to Refresh"))
        self.tableView.reloadData()
        
        if documentsToParse == 0 {
            self.refreshControl!.endRefreshing()
            UIApplication.sharedApplication().idleTimerDisabled = false
            log.debug("Modo reposo activado")
        }
    }
    
    // MARK: - Parsing and CoreData
    
    func parsingWasFinished(xmlParser: XMLParser) {
        
        //Cuando el Parser va terminando de leer los documentos los carga en la tabla y avisa a la vista
        
        log.verbose("parsingWasFinished:")
        
        documentsParsed += 1

        let context = self.fetchedResultsController.managedObjectContext
        let backupFile = createBackupFileRegister(xmlParser)
        backupFile?.quantitySamplesCount = xmlParser.quantitySamplesCount
        var permissionsList : String = ""
        for permission in xmlParser.permissionsList {
            permissionsList += permission + ","
        }
        
        if !permissionsList.isEmpty { permissionsList = permissionsList.substringToIndex(permissionsList.endIndex.predecessor()) }
        backupFile?.permissionsList = permissionsList
        
        do {
            try context.save()
            log.debug("numero de samples en el fichero actualizado a: \(xmlParser.quantitySamplesCount)")
            log.debug("numero de permisos necesarios: \(xmlParser.permissionsList.count)")
        } catch {
            log.error("Error actualizando el numero de samples o los tipos en el fichero de backup")
        }
        
        if documentsParsed == documentsToParse {
            log.verbose("Todos los documentos examinados...\(documentsParsed)/\(documentsToParse)")
            
            let horaFin : NSDate = NSDate()
            let diferencia  = horaFin.timeIntervalSinceDate(horaInicio)

            log.debug("Carga finalizada: \(horaFin)")
            log.debug("Tiempo empleado: \(diferencia)")
            
            self.refreshControl!.endRefreshing()
            //self.tableView.endUpdates()
            self.tableView.reloadData()
        }
    }
    
    func errorParsing(xmlParser: XMLParser, error: NSError) {
        
        let backupFile = createBackupFileRegister(xmlParser)
        if backupFile != nil {
            deleteBackupFile(backupFile!)
        }
        
        let msg = NSLocalizedString("PleaseContactSupport", comment: "PleaseContactSupport")
        notifyUser(xmlParser.fileName, err: String(format: msg, error.description) )
        
    }
    
    func createBackupFileRegister(xmlParser: XMLParser) -> BackupFile? {

        log.verbose("createBackupFileRegister:")
        
        let context = self.fetchedResultsController.managedObjectContext
        let entity = self.fetchedResultsController.fetchRequest.entity!

        if xmlParser.coredataBackupFileId != nil {
            log.debug("El fichero existe ya existe")
            return (context.objectWithID(xmlParser.coredataBackupFileId!) as! BackupFile)
        }
        
        if (xmlParser.exportDate != nil) && (xmlParser.isValidBackupFile)  {
            let newBackupFile = NSEntityDescription.insertNewObjectForEntityForName(entity.name!, inManagedObjectContext: context) as! BackupFile
            newBackupFile.fileURLWithPath = xmlParser.fileURLWithPath!.description
            newBackupFile.fileName = xmlParser.fileName
            newBackupFile.exportDate = xmlParser.exportDate
            newBackupFile.lastImportDate = nil
            newBackupFile.quantitySamplesCount = 0
            newBackupFile.permissionsList = ""
            
            do {
                try context.save()
                log.debug("Registro Creado: \(newBackupFile.fileName)")
            } catch {
                // Replace this implementation with code to handle the error appropriately.
                // abort() causes the application to generate a crash log and terminate. You should not use this function in a shipping application, although it may be useful during development.
                log.error("Unresolved error \(error)")
                //abort()
            }
            
            return newBackupFile
        } else {
            log.verbose("Registro no creado, el fichero no es valido...")
            return nil
        }
    }
    
    func saveElementsParsed(xmlParser: XMLParser) {
        
        //Cuando el Parser a leido algunos registros avisa a la vista para guardar los datos en sqlite y liberar memoria
                
        let context = self.fetchedResultsController.managedObjectContext
        context.undoManager?.disableUndoRegistration()

        elementsSaved += xmlParser.samples.count
        
        if xmlParser.coredataBackupFileId != nil {
            xmlParser.coredataBackupFile =  (context.objectWithID(xmlParser.coredataBackupFileId!) as! BackupFile)
        }

        let formateador = NSDateFormatter()
        formateador.dateFormat = "yyyyMMddHHmmssZ"

        //context.performBlock {
            
            autoreleasepool {
                for sample in xmlParser.samples {
                    let sampleType = sample["type"]
                    if sampleType?.hasPrefix("HKQuantityType") == true {
                        let newSample: QuantitySample = NSEntityDescription.insertNewObjectForEntityForName("QuantitySample", inManagedObjectContext: context) as! QuantitySample
                        if sample["source"] != nil {
                            newSample.source = sample["source"]!
                        } else {
                            newSample.source = sample["sourceName"]!
                        }
                        if sample["startDate"] != nil {
                            if formateador.dateFromString(sample["startDate"]!) == nil {
                                formateador.dateFormat = "yyyy-MM-dd HH:mm:ss Z"
                            }
                            newSample.startDate = formateador.dateFromString(sample["startDate"]!)!
                        }
                        if sample["endDate"] != nil {
                            if formateador.dateFromString(sample["endDate"]!) == nil {
                                formateador.dateFormat = "yyyy-MM-dd HH:mm:ss Z"
                            }
                            newSample.endDate = formateador.dateFromString(sample["endDate"]!)!
                        }
                        if let tmpUnit = sample["unit"]  {
                            newSample.quantityType = tmpUnit
                        }
                        if sample["value"] != nil {
                            newSample.quantity = NSString(string: sample["value"]!).doubleValue
                            //log.debug("CoreData - Muestra de \(sampleType!) guardando el valor: \(newSample.quantity)")
                        }
                        if sample["recordCount"] != nil {
                            newSample.recordCount = NSString(string: sample["recordCount"]!).doubleValue
                        }
                        newSample.backupFile = xmlParser.coredataBackupFile!
                        newSample.typeIdentifier = sampleType!
                    } else {
                        //log.debug("CoreData - SampleType not implemented \(sampleType!)")
                    }
                }
            }

            do {
                try context.save()
                log.debug("Total de elementos procesados \(self.elementsSaved)")
                
            } catch {
                log.error("Algo fallo en context.save() de saveElementsParsed(): \(error)")
            }
            context.reset()
        //}
    }
    
    func deleteBackupFile(backupFile: BackupFile) {
        
        let context = self.managedObjectContext!
        
        if #available(iOS 9.0, *) {
            log.debug("Borrando el fichero \"\(backupFile.fileName)\" usando iOS 9 NSBatchDeleteRequest.")
            let fetchRequest = NSFetchRequest(entityName: "BackupFile")
            let predicateByFileName = NSPredicate(format: "fileName = %@", backupFile.fileName)
            fetchRequest.predicate = predicateByFileName
            let batchDeleteRequest = NSBatchDeleteRequest(fetchRequest: fetchRequest)
            batchDeleteRequest.resultType = .ResultTypeCount
            
            do {
                // Execute Batch Request
                let batchDeleteResult = try context.executeRequest(batchDeleteRequest) as? NSBatchDeleteResult
                
                log.debug("El borrado por lotes ha eliminado \"\(batchDeleteResult?.result)\" registros.")
                
                // Reset Managed Object Context
                context.reset()
                
                // Perform Fetch
                try self.fetchedResultsController.performFetch()
                
                // Reload Table View
                tableView.reloadData()
                
            } catch {
                let updateError = error as NSError
                log.error("\(updateError), \(updateError.userInfo)")
            }
        } else {
            log.debug("Borrando el fichero \(backupFile) usando coredata loop.")
            let fetchRequest = NSFetchRequest(entityName: "QuantitySample")
            let predicateByFileName = NSPredicate(format: "backupFile = %@", backupFile)
            fetchRequest.predicate = predicateByFileName
            fetchRequest.fetchLimit = 1
            fetchRequest.fetchBatchSize = 1
            do {
                while try context.executeFetchRequest(fetchRequest).count > 0 {
                    deleteData("QuantitySample",backupFile: backupFile)
                }
            } catch {
                log.error("Algo fue mal...")
            }
            deleteData("BackupFile",backupFile: backupFile)
        }
    }
    
    func deleteData(entity: String, backupFile: BackupFile) {
        let context = self.managedObjectContext!
        let objectsToDeleteRequest = NSFetchRequest(entityName: entity)

        if entity == "QuantitySample" {
            let predicateByFileName = NSPredicate(format: "backupFile = %@", backupFile)
            objectsToDeleteRequest.predicate = predicateByFileName
        } else {
            let predicateByFileName = NSPredicate(format: "fileName = %@", backupFile)
            objectsToDeleteRequest.predicate = predicateByFileName
        }

        objectsToDeleteRequest.includesPropertyValues = false
        objectsToDeleteRequest.includesSubentities = false
        objectsToDeleteRequest.fetchBatchSize = 25000
        objectsToDeleteRequest.fetchLimit = 25000
        
        do {
            let objectsToDelete = try context.executeFetchRequest(objectsToDeleteRequest)
            if let _ = objectsToDelete.last as! NSManagedObject? {
                for object in objectsToDelete {
                    let managedObject = (object as! NSManagedObject)
                    context.deleteObject(managedObject)
                }
                try context.save()
                context.reset()
            }
        } catch {
            log.error("Algo fallo en context.save() de deleteData()")
        }
    }
    
    // MARK: - Segues
    
    override func prepareForSegue(segue: UIStoryboardSegue, sender: AnyObject?) {
        self.refreshControl!.endRefreshing()
        if segue.identifier == "showDetail" {
            if let indexPath = self.tableView.indexPathForSelectedRow {
                let selectedBackupFile = (self.fetchedResultsController.objectAtIndexPath(indexPath) as! BackupFile)
                self.pedirPermisos(selectedBackupFile)
                let controller = (segue.destinationViewController as! UINavigationController).topViewController as! SamplesGroupsTableViewController
                controller.detailItem = selectedBackupFile
                controller.healthStore = self.healthStore
                controller.navigationItem.leftBarButtonItem = self.splitViewController?.displayModeButtonItem()
                controller.navigationItem.leftItemsSupplementBackButton = true
            }
        }
    }
    
    // Actualizacción de permisos

    func pedirPermisos(backupFile: BackupFile) {
        
        if HKHealthStore.isHealthDataAvailable() {
            var hkQuantitySampleTypes: Set<HKSampleType> = []
            let permissionsList = backupFile.permissionsList.componentsSeparatedByString(",")
            if permissionsList.count == 0 {
                log.verbose("No hay permisos que solicitar")
                return
            }
            for permission in permissionsList {
                let typeToInsert = HKObjectType.quantityTypeForIdentifier(permission)
                if typeToInsert != nil {
                    hkQuantitySampleTypes.insert(typeToInsert!)
                }
            }
            if hkQuantitySampleTypes.count > 0 {
                self.healthStore!.requestAuthorizationToShareTypes(hkQuantitySampleTypes, readTypes: hkQuantitySampleTypes, completion: {
                    (success, error) -> Void in
                    log.debug("Petición de permisos para \(permissionsList), Realizada con resultado de \(success), Error: \(error)")
                })
            }
            hkQuantitySampleTypes.removeAll(keepCapacity: false)
        } else {
            log.error("HealthKit no esta disponible")
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
            
            let backupFile = self.fetchedResultsController.objectAtIndexPath(indexPath) as! BackupFile
            documentsDirectory = paths[0] as String
            let filePath = documentsDirectory.stringByAppendingPathComponent(backupFile.fileName)
            let fileManager: NSFileManager = NSFileManager.defaultManager()

            do {
                try fileManager.removeItemAtPath(filePath)
                let backupFile = self.fetchedResultsController.objectAtIndexPath(indexPath) as! BackupFile
                deleteBackupFile(backupFile)
            } catch let error as NSError {
                log.debug(error.description)
            }
                
            do {
                try context.save()
                //Todo: Borrar el fichero del disco
            } catch {
                // Replace this implementation with code to handle the error appropriately.
                // abort() causes the application to generate a crash log and terminate. You should not use this function in a shipping application, although it may be useful during development.
                //log.error("Unresolved error \(error), \(error.userInfo)")
                abort()
            }
        }
    }

    func configureCell(cell: UITableViewCell, atIndexPath indexPath: NSIndexPath) {

        formateador.dateStyle = .LongStyle
        formateador.timeStyle = .ShortStyle
        
        let samples = NSLocalizedString("Samples", comment: "Samples")
        let exportedOn = NSLocalizedString("ExportedOn", comment: "Exported on")
        let backupFile = (self.fetchedResultsController.objectAtIndexPath(indexPath) as! BackupFile)
        //let samplesCount = formatNumberInDecimalStyle(backupFile.quantitySamples!.count)
        var samplesCount = formatNumberInDecimalStyle(backupFile.quantitySamplesCount)
        
        if backupFile.quantitySamplesCount == 0 {
            samplesCount = NSLocalizedString("UnknownNumberOf", comment: "UnknowNumberOf")
        }
        
        let exportDate = formateador.stringFromDate(backupFile.exportDate!)
        //let exportDate = "--/--/--"
        let fileName = backupFile.fileName
        cell.textLabel!.text = fileName
        cell.detailTextLabel!.text = "\(samplesCount) \(samples)\r\(exportedOn) \(exportDate)"
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
        //fetchRequest.includesPropertyValues = false
        //fetchRequest.includesSubentities = false
        
        // Set the batch size to a suitable number.
        fetchRequest.fetchBatchSize = 20
        
        // Edit the sort key as appropriate.
        let sortDescriptor = NSSortDescriptor(key: "fileName", ascending: false)
        
        fetchRequest.sortDescriptors = [sortDescriptor]
        
        // Edit the section name key path and cache name if appropriate.
        // nil for section name key path means "no sections".
//        let aFetchedResultsController = NSFetchedResultsController(fetchRequest: fetchRequest, managedObjectContext: self.managedObjectContext!, sectionNameKeyPath: nil, cacheName: "Master")
        let aFetchedResultsController = NSFetchedResultsController(fetchRequest: fetchRequest, managedObjectContext: self.managedObjectContext!, sectionNameKeyPath: nil, cacheName: nil)
        aFetchedResultsController.delegate = self
        _fetchedResultsController = aFetchedResultsController
        
        do {
            try _fetchedResultsController!.performFetch()
        } catch {
             // Replace this implementation with code to handle the error appropriately.
             // abort() causes the application to generate a crash log and terminate. You should not use this function in a shipping application, although it may be useful during development. 
             //log.error("Unresolved error \(error), \(error.userInfo)")
             abort()
        }
        
        return _fetchedResultsController!
    }
    
    var _fetchedResultsController: NSFetchedResultsController? = nil

    func controllerWillChangeContent(controller: NSFetchedResultsController) {
        self.tableView.beginUpdates()
    }

//    func controller(controller: NSFetchedResultsController, didChangeSection sectionInfo: NSFetchedResultsSectionInfo, atIndex sectionIndex: Int, forChangeType type: NSFetchedResultsChangeType) {
//        switch type {
//            case .Insert:
//                self.tableView.insertSections(NSIndexSet(index: sectionIndex), withRowAnimation: .Fade)
//            case .Delete:
//                self.tableView.deleteSections(NSIndexSet(index: sectionIndex), withRowAnimation: .Fade)
//            default:
//                return
//        }
//    }

    func controller(controller: NSFetchedResultsController, didChangeObject anObject: AnyObject, atIndexPath indexPath: NSIndexPath?, forChangeType type: NSFetchedResultsChangeType, newIndexPath: NSIndexPath?) {
        switch type {
            case .Insert:
                tableView.insertRowsAtIndexPaths([newIndexPath!], withRowAnimation: .Automatic)
            case .Delete:
                tableView.deleteRowsAtIndexPaths([indexPath!], withRowAnimation: .Automatic)
            case .Update:
                self.configureCell(tableView.cellForRowAtIndexPath(indexPath!)!, atIndexPath: indexPath!)
            case .Move:
                tableView.deleteRowsAtIndexPaths([indexPath!], withRowAnimation: .None)
                tableView.insertRowsAtIndexPaths([newIndexPath!], withRowAnimation: .None)
        }
    }

    func controllerDidChangeContent(controller: NSFetchedResultsController) {
        self.tableView.endUpdates()
    }

    func notifyUser(msg: String, err: String?) {
        let alert = UIAlertController(title: msg,
                                      message: err,
                                      preferredStyle: UIAlertControllerStyle.Alert)
        
        let continueAction = UIAlertAction(title: "OK",
                                           style: .Default, handler: nil)
        
        alert.addAction(continueAction)
        
        self.presentViewController(alert, animated: true,
                                   completion: nil)
        
        log.debug(msg)
        log.error(err.debugDescription)
    }
    
     // Implementing the above methods to update the table view in response to individual changes may have performance implications if a large number of changes are made simultaneously. If this proves to be an issue, you can instead just implement controllerDidChangeContent: which notifies the delegate that all section and object changes have been processed.
     
//     func controllerDidChangeContent(controller: NSFetchedResultsController) {
//         // In the simplest, most efficient, case, reload the table view.
//         self.tableView.reloadData()
//     }
    

    
    
}