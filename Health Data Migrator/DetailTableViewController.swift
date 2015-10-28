//
//  DetailTableViewController.swift
//  Health Importer
//
//  Created by Antonio Carranza López on 27/9/15.
//  Copyright © 2015 Antonio Carranza López. All rights reserved.
//

import UIKit
import CoreData
import HealthKit

class DetailTableViewController: UITableViewController, NSFetchedResultsControllerDelegate {
    
    
    @IBOutlet weak var checkForDuplicatesButton: UIBarButtonItem!
    @IBOutlet weak var importSamplesButton: UIBarButtonItem!
    
    var appDel: AppDelegate?
    var managedObjectContext: NSManagedObjectContext?
    let healthStore = HKHealthStore()
    var checkForDuplicatesPushed = false
    var querySet: Set<QuantitySample> = []
    
    var detailItem: BackupFile? {
        didSet {
            // Update the view.
            self.configureView()
        }
    }
    
    
    // MARK: Core Data
    
    // MARK: - Fetched results controller
    
    var fetchedResultsController: NSFetchedResultsController {
        if _fetchedResultsController != nil {
            return _fetchedResultsController!
        }
        
        let fetchRequest = NSFetchRequest()
        // Edit the entity name as appropriate.
        let entity = NSEntityDescription.entityForName("QuantitySample", inManagedObjectContext: self.managedObjectContext!)
        fetchRequest.entity = entity
        
        // Set the batch size to a suitable number.
        fetchRequest.fetchBatchSize = 20
        
        // Edit the sort key as appropriate.
        let sortDescriptor = NSSortDescriptor(key: "typeIdentifier", ascending: false)
        
        fetchRequest.sortDescriptors = [sortDescriptor]
        
        // Edit the section name key path and cache name if appropriate.
        // nil for section name key path means "no sections".
        let aFetchedResultsController = NSFetchedResultsController(fetchRequest: fetchRequest, managedObjectContext: self.managedObjectContext!, sectionNameKeyPath: "typeIdentifier", cacheName: nil)
        aFetchedResultsController.delegate = self
        _fetchedResultsController = aFetchedResultsController
        
        let predicateByFileName = NSPredicate(format: "backupFile = %@", (self.detailItem!))
        fetchRequest.predicate = predicateByFileName
        
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

    
    func configureView() {
        // Update the user interface for the detail item.
        if let detail = self.detailItem {
            self.title = detail.fileName
        }
    }

    
    override func viewDidLoad() {
        super.viewDidLoad()

        // Uncomment the following line to preserve selection between presentations
        // self.clearsSelectionOnViewWillAppear = false

        // Uncomment the following line to display an Edit button in the navigation bar for this view controller.
        // self.navigationItem.rightBarButtonItem = self.editButtonItem()
        
        //let importButton = UIBarButtonItem(barButtonSystemItem: .Play, target: self, action: "importSamples:")
        //self.navigationItem.rightBarButtonItem = importButton
        
        self.appDel = (UIApplication.sharedApplication().delegate as! AppDelegate)
        self.managedObjectContext = appDel?.managedObjectContext
        
        self.navigationController?.toolbarHidden = false
        
        //self.timer = NSTimer(timeInterval: 10.0, target: self, selector: "actualizarTabla", userInfo: nil, repeats: true)
        //NSRunLoop.mainRunLoop().addTimer(self.timer, forMode: NSRunLoopCommonModes)
        
        self.checkForDuplicatesButton.title = NSLocalizedString("CheckForDuplicates", comment: "Check For samples that will duplicate values on healthkit")
        self.importSamplesButton.title = NSLocalizedString("ImportSamples", comment: "Import Samples")
    }

    override func didReceiveMemoryWarning() {
        super.didReceiveMemoryWarning()
        // Dispose of any resources that can be recreated.
    }

    // MARK: - Authorize and Import
    @IBAction func checkForDuplicatesAction(sender: UIBarButtonItem) {
        
        sender.enabled = false
        
        for item in (self.detailItem?.quantitySamples)! {
            let sample = (item as! QuantitySample)
            //Cabria preguntarse si dicha muestra existe ya en la base de datos de HealthKit, si existe una identica no tiene sentido importar
            //Podriamos marcarla como ya importada
            let type = HKObjectType.quantityTypeForIdentifier(sample.typeIdentifier)
            //Query por fecha exacta
            let explicitTimeInterval = NSPredicate(format: "%K = %@ AND %K = %@",
                HKPredicateKeyPathEndDate, sample.startDate,
                HKPredicateKeyPathStartDate, sample.endDate)
            //Query por cantidad y unidades kg...
            let unit = HKUnit(fromString: sample.quantityType)
            let value = Double(sample.quantity.description)
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
                if querySamples?.count != 0 {
                    sample.foundInHealthKit = true
                }
                
                self.querySet.remove(sample)
                if self.querySet.count == 0 {
                    self.actualizarTabla()
                    dispatch_async(dispatch_get_main_queue(), { () -> Void in
                        self.notifyUser(NSLocalizedString("CheckForDuplicates", comment: "Buscar Duplicados"), err: NSLocalizedString("CheckForDuplicatesFinished", comment: "La Busqueda de duplicados finalizo"))
                    })
                }
            })
            querySet.insert(sample)
            self.healthStore.executeQuery(hkQuery)
        }
        checkForDuplicatesPushed = true
    }
    @IBAction func importSamplesAction(sender: UIBarButtonItem) {
        if !checkForDuplicatesPushed {
            alertUserSearchForDuplicates()
        } else {
            importSamples(sender)
        }
    }
    
    func importSamples(sender: UIBarButtonItem) {
        print("ImportSamples...")
        
        sender.enabled = false
        
        var samples: [HKObject] = []
        var modifiedSamples: [QuantitySample] = []
        
        for item in self.fetchedResultsController.fetchedObjects! {
            let sample = (item as! QuantitySample)
            
            let type = HKObjectType.quantityTypeForIdentifier(sample.typeIdentifier)
            let unit = HKUnit(fromString: sample.quantityType)

            let value = sample.quantity.doubleValue
            let quantity = HKQuantity(unit: unit, doubleValue: value)
            let metadata  = [HKMetadataKeyWasUserEntered:false]
            let hkSample = HKQuantitySample(type: type!, quantity: quantity, startDate: sample.startDate, endDate: sample.endDate, metadata: metadata)
            
            if sample.foundInHealthKit == false {
                samples.append(hkSample)
                modifiedSamples.append(sample)
            }

        }
        if samples.count > 0 {
                healthStore.saveObjects(samples, withCompletion: { (success, error) -> Void in
                    if error != nil {
                        print("Errores, terminó la importación con estado \(success)")
                        print(error)
                        return
                    }
                    
                    if success {
                        //Dialogo informando del resultado
                        print("Se importaron con exito \(samples.count) samples")
                        for sample in modifiedSamples {
                            sample.foundInHealthKit = true
                        }
                        self.actualizarTabla()
                        let msg =   NSLocalizedString("SamplesImported", comment: "Number of samples imported")
                        let userInfo = "\(samples.count.description) \(msg)"
                        dispatch_async(dispatch_get_main_queue(), { () -> Void in
                            self.notifyUser(NSLocalizedString("ImportSuccessfull", comment: "Import Successfull"), err: userInfo )
                        })
                    } else {
                        print("Algo falló con la importación")
                    }
                })
        } else {
            print("Nada que importar")
            self.notifyUser(NSLocalizedString("NothingToImport", comment: "Nothing to Import"), err: NSLocalizedString("AllSamplesAllreadyExist", comment: "All Samples already exists"))
        }
        self.actualizarTabla()
    }
    
    // MARK: - Table view data source

    func actualizarTabla() {
        dispatch_async(dispatch_get_main_queue(),{
            self.tableView.reloadData()
        })
    }
    
    override func numberOfSectionsInTableView(tableView: UITableView) -> Int {
        // #warning Incomplete implementation, return the number of sections
        return self.fetchedResultsController.sections?.count ?? 0
    }
    
    override func tableView(tableView: UITableView, titleForHeaderInSection section: Int) -> String? {
        if let sections = self.fetchedResultsController.sections {
            let currentSection = sections[section]
            let headerTitle = NSLocalizedString(currentSection.name, comment: "headerTitle")
            var numberOfSamples: String
            if currentSection.numberOfObjects == 1 {
                numberOfSamples = NSLocalizedString("SampleOf", comment: "Samples of")
            } else {
                numberOfSamples = NSLocalizedString("SamplesOf", comment: "Samples of")
            }
            return "\(currentSection.numberOfObjects) \(numberOfSamples) \(headerTitle)"
        }
        
        return nil
        
    }
    
    override func tableView(tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        // #warning Incomplete implementation, return the number of rows
        let sectionInfo = self.fetchedResultsController.sections![section]
        return sectionInfo.numberOfObjects
    }
    
    override func tableView(tableView: UITableView, cellForRowAtIndexPath indexPath: NSIndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCellWithIdentifier("sampleCell", forIndexPath: indexPath)
        configureCell(cell, atIndexPath: indexPath)
        return cell
    }
    
    func configureCell(cell: UITableViewCell, atIndexPath indexPath: NSIndexPath) {

        let sample = (self.fetchedResultsController.objectAtIndexPath(indexPath) as! QuantitySample)

        let formateador = NSDateFormatter()
        formateador.dateStyle = .ShortStyle
        formateador.timeStyle = .ShortStyle
        
        cell.detailTextLabel!.text = "\(sample.source), \(formateador.stringFromDate(sample.startDate))"
        //cell.imageView?.image = UIImage(named: sample.typeIdentifier! )
        cell.textLabel!.text = "\(sample.quantity) \(sample.quantityType)"
        if sample.foundInHealthKit {
            cell.accessoryType = .Checkmark
        } else {
            cell.accessoryType = .None
        }
    }

    /*
    // Override to support conditional editing of the table view.
    override func tableView(tableView: UITableView, canEditRowAtIndexPath indexPath: NSIndexPath) -> Bool {
        // Return false if you do not want the specified item to be editable.
        return true
    }
    */

    /*
    // Override to support editing the table view.
    override func tableView(tableView: UITableView, commitEditingStyle editingStyle: UITableViewCellEditingStyle, forRowAtIndexPath indexPath: NSIndexPath) {
        if editingStyle == .Delete {
            // Delete the row from the data source
            tableView.deleteRowsAtIndexPaths([indexPath], withRowAnimation: .Fade)
        } else if editingStyle == .Insert {
            // Create a new instance of the appropriate class, insert it into the array, and add a new row to the table view
        }    
    }
    */

    /*
    // Override to support rearranging the table view.
    override func tableView(tableView: UITableView, moveRowAtIndexPath fromIndexPath: NSIndexPath, toIndexPath: NSIndexPath) {

    }
    */

    /*
    // Override to support conditional rearranging of the table view.
    override func tableView(tableView: UITableView, canMoveRowAtIndexPath indexPath: NSIndexPath) -> Bool {
        // Return false if you do not want the item to be re-orderable.
        return true
    }
    */

    /*
    // MARK: - Navigation

    // In a storyboard-based application, you will often want to do a little preparation before navigation
    override func prepareForSegue(segue: UIStoryboardSegue, sender: AnyObject?) {
        // Get the new view controller using segue.destinationViewController.
        // Pass the selected object to the new view controller.
    }
    */
    
    //MARK: - Notificacion en pantalla
    
    //MARK: Notificación por pantalla
    
    func alertUserSearchForDuplicates() {

        let alert = UIAlertController(title: NSLocalizedString("ImportSamples", comment: "Import Samples"),
            message: NSLocalizedString("AlertCheckForDuplicates", comment: "Alert Check for Duplicates"),
            preferredStyle: UIAlertControllerStyle.Alert)
        
        let continueAction = UIAlertAction(title: NSLocalizedString("Continue", comment: "Continue"),
            style: .Default , handler: {(alert: UIAlertAction!) in
                self.importSamples(self.importSamplesButton)
        })
        
        let cancelAction = UIAlertAction(title: NSLocalizedString("Cancel", comment: "Cancel"),
            style: .Cancel, handler: nil)
        
        alert.addAction(continueAction)
        alert.addAction(cancelAction)
        
        self.presentViewController(alert, animated: true,
            completion: nil)
        
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
    }

}
