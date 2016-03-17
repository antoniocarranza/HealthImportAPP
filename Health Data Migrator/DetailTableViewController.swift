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
    var healthStore: HKHealthStore? = nil
    var checkForDuplicatesPushed = false
    var querySet: Set<QuantitySample> = []
    
    var detailItem: BackupFile? {
        didSet {
            // Update the view.
            self.configureView()
        }
    }
    
    var samplesFilter: String? {
        didSet {
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
        let sortDescriptorTypeIdentifier = NSSortDescriptor(key: "typeIdentifier", ascending: false)
        let sortDescriptorStartDate = NSSortDescriptor(key: "startDate", ascending: true)
        
        fetchRequest.sortDescriptors = [sortDescriptorTypeIdentifier,sortDescriptorStartDate]
        
        // Edit the section name key path and cache name if appropriate.
        // nil for section name key path means "no sections".
        let aFetchedResultsController = NSFetchedResultsController(fetchRequest: fetchRequest, managedObjectContext: self.managedObjectContext!, sectionNameKeyPath: "typeIdentifier", cacheName: nil)
        aFetchedResultsController.delegate = self
        _fetchedResultsController = aFetchedResultsController
        
        if self.samplesFilter != nil {
            let predicateByType = NSPredicate(format: "typeIdentifier = %@ AND backupFile = %@", (self.samplesFilter)!, (self.detailItem!))
            fetchRequest.predicate = predicateByType
        } else {
            let predicateByFileName = NSPredicate(format: "backupFile = %@", (self.detailItem!))
            fetchRequest.predicate = predicateByFileName
        }
        
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

    // MARK: - View
    
    func configureView() {
        // Update the user interface for the detail item.
    }
   
    override func viewWillAppear(animated: Bool) {
        self.actualizarTabla()
        self.navigationController?.setToolbarHidden(false, animated: false)
        self.checkForDuplicatesButton.enabled = true
    }
    
    override func viewWillDisappear(animated: Bool) {
        self.navigationController?.setToolbarHidden(true, animated: false)
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
        self.importSamplesButton.title = NSLocalizedString("ImportThisSamples", comment: "Import This Samples")
    }

    override func didReceiveMemoryWarning() {
        super.didReceiveMemoryWarning()
        // Dispose of any resources that can be recreated.
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

        let dateFormatter = NSDateFormatter()
        dateFormatter.dateStyle = .ShortStyle
        dateFormatter.timeStyle = .ShortStyle
        
        cell.detailTextLabel!.text = "\(sample.source), \(dateFormatter.stringFromDate(sample.startDate))"

        let etiqueta = formatNumberInDecimalStyle(sample.quantity)
        cell.textLabel!.text = "\(etiqueta) \(sample.quantityType)"

        if sample.foundInHealthKit {
            cell.accessoryType = .Checkmark
        } else {
            cell.accessoryType = .None
        }
        if sample.recordCount == 1 {
            cell.imageView?.image = UIImage(named: "recordCountFalse")
        } else {
            cell.imageView?.image = UIImage(named: "recordCountTrue")
        }
        
    }

    override func tableView(tableView: UITableView, didSelectRowAtIndexPath indexPath: NSIndexPath) {
        let sample = (self.fetchedResultsController.objectAtIndexPath(indexPath) as! QuantitySample)
        //checkForDuplicates([sample])
        sample.foundInHealthKit = !sample.foundInHealthKit
        self.actualizarTabla()
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


    // MARK: - Navigation

    // In a storyboard-based application, you will often want to do a little preparation before navigation
    override func prepareForSegue(segue: UIStoryboardSegue, sender: AnyObject?) {
        // Get the new view controller using segue.destinationViewController.
        // Pass the selected object to the new view controller.
        if segue.identifier == "importThisSamples" {
            if !checkForDuplicatesPushed {
                alertUserSearchForDuplicates()
            }
            let dvc = segue.destinationViewController as! ImportSamplesViewController
            dvc.samplesToImport = self.fetchedResultsController.fetchedObjects!
            dvc.healthStore = self.healthStore
            dvc.fetchedResultsController = self.fetchedResultsController
        }
        if segue.identifier == "checkThisSamples" {
            checkForDuplicatesPushed = true
            let dvc = segue.destinationViewController as! ImportSamplesViewController
            dvc.samplesToCheck = self.fetchedResultsController.fetchedObjects!
            dvc.healthStore = self.healthStore
            dvc.fetchedResultsController = self.fetchedResultsController
        }

    }
    
    //MARK: - Notificacion en pantalla
    
    func alertUserSearchForDuplicates() {

        let alert = UIAlertController(title: NSLocalizedString("ImportSamples", comment: "Import Samples"),
            message: NSLocalizedString("AlertCheckForDuplicates", comment: "Alert Check for Duplicates"),
            preferredStyle: UIAlertControllerStyle.Alert)
        
        let continueAction = UIAlertAction(title: NSLocalizedString("Continue", comment: "Continue"),
            style: .Default , handler: {(alert: UIAlertAction!) in
                self.checkForDuplicatesPushed = true
                self.performSegueWithIdentifier("importThisSamples", sender: self)
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
