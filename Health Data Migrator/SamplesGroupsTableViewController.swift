//
//  SamplesGroupsTableViewController.swift
//  Health Import
//
//  Created by Antonio Carranza López on 17/11/15.
//  Copyright © 2015 Antonio Carranza López. All rights reserved.
//

import UIKit
import CoreData
import HealthKit


class SamplesGroupsTableViewController: UITableViewController, NSFetchedResultsControllerDelegate {

    @IBOutlet weak var checkForDuplicatesButton: UIBarButtonItem!
    @IBOutlet weak var importSamplesButton: UIBarButtonItem!
    
    var appDel: AppDelegate?
    var managedObjectContext: NSManagedObjectContext?
    var checkForDuplicatesPushed = false
    var healthStore: HKHealthStore? = nil
    
    var detailItem: BackupFile? {
        didSet {
            // Update the view.
            self.configureView()
        }
    }
    
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
        
        self.appDel = (UIApplication.sharedApplication().delegate as! AppDelegate)
        self.managedObjectContext = appDel?.managedObjectContext
        //self.healthStore = appDel?.healthStore
        
        self.checkForDuplicatesButton.title = NSLocalizedString("CheckForDuplicates", comment: "Check For samples that will duplicate values on healthkit")
        self.importSamplesButton.title = NSLocalizedString("ImportAllSamples", comment: "Import All Samples")

    }
    
    override func viewWillAppear(animated: Bool) {
        self.actualizarTabla()
        self.navigationController?.setToolbarHidden(false, animated: false)
    }
    
    override func viewWillDisappear(animated: Bool) {
        //self.navigationController?.setToolbarHidden(true, animated: false)
    }

    override func didReceiveMemoryWarning() {
        super.didReceiveMemoryWarning()
        // Dispose of any resources that can be recreated.
    }

    // MARK: - Table view data source

    override func numberOfSectionsInTableView(tableView: UITableView) -> Int {
        // #warning Incomplete implementation, return the number of sections
        return 1
    }

    override func tableView(tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        // #warning Incomplete implementation, return the number of rows
        return (self.fetchedResultsController.sections?.count)! + 1 ?? 0
    }

    override func tableView(tableView: UITableView, cellForRowAtIndexPath indexPath: NSIndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCellWithIdentifier("groupSample", forIndexPath: indexPath)

        // Configure the cell...
        configureCell(cell, atIndexPath: indexPath)
        
        return cell
    }

    func configureCell(cell: UITableViewCell, atIndexPath indexPath: NSIndexPath) {
        
        if indexPath.row == 0 {
            cell.textLabel!.text = NSLocalizedString("All", comment: "All")
            let numberOfSamples = formatNumberInDecimalStyle((fetchedResultsController.fetchedObjects?.count)!)
            cell.detailTextLabel!.text = numberOfSamples
            cell.imageView?.image = UIImage(named: "All")
        } else {
            if let sections = self.fetchedResultsController.sections {
                let currentSection = sections[indexPath.row - 1]
                let headerTitle = NSLocalizedString(currentSection.name, comment: "headerTitle")
                let numberOfSamples = formatNumberInDecimalStyle(currentSection.numberOfObjects)
                cell.textLabel?.text = headerTitle
                cell.detailTextLabel?.text = numberOfSamples
                if let imageName = SamplesPictures[currentSection.name] {
                    cell.imageView?.image = UIImage(named: imageName)
                } else {
                    cell.imageView?.image = UIImage(named: "notFoundImage")
                    log.debug(currentSection.name)
                }
            }
        }
    }

    func actualizarTabla() {
        dispatch_async(dispatch_get_main_queue(),{
            self.tableView.reloadData()
        })
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
        
        if self.detailItem != nil {
            let predicateByFileName = NSPredicate(format: "backupFile = %@", (self.detailItem!))
            fetchRequest.predicate = predicateByFileName
        }
        
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
        if segue.identifier == "importAllSamples" {
            if !checkForDuplicatesPushed {
                alertUserSearchForDuplicates()
            }
            let dvc = segue.destinationViewController as! ImportSamplesViewController
            dvc.fetchedResultsController = self.fetchedResultsController
            dvc.samplesToImport = self.fetchedResultsController.fetchedObjects!
            dvc.healthStore = self.healthStore
            dvc.fetchedResultsController = self.fetchedResultsController
        }
        if segue.identifier == "checkAllSamples" {
            let dvc = segue.destinationViewController as! ImportSamplesViewController
            dvc.samplesToCheck = self.fetchedResultsController.fetchedObjects!
            dvc.fetchedResultsController = self.fetchedResultsController
            dvc.healthStore = self.healthStore
            dvc.fetchedResultsController = self.fetchedResultsController
            checkForDuplicatesPushed = true
            log.debug(dvc.description)
        }
        
        if segue.identifier == "showSamples" {
            let dvc = segue.destinationViewController as! DetailTableViewController
            if self.tableView.indexPathForSelectedRow?.row == 0 {
                dvc.detailItem = self.detailItem
                dvc.healthStore = self.healthStore
            } else {
                let sectionIndex = (self.tableView.indexPathForSelectedRow?.row)!  - 1
                let sections = self.fetchedResultsController.sections
                let section = sections![sectionIndex]
                dvc.samplesFilter = section.name
                dvc.detailItem = self.detailItem
                dvc.healthStore = self.healthStore
            }
        }
    }

    // MARK: - Notificación en pantalla
    
    func alertUserSearchForDuplicates() {
        
        let alert = UIAlertController(title: NSLocalizedString("ImportSamples", comment: "Import Samples"),
            message: NSLocalizedString("AlertCheckForDuplicates", comment: "Alert Check for Duplicates"),
            preferredStyle: UIAlertControllerStyle.Alert)
        
        let continueAction = UIAlertAction(title: NSLocalizedString("Continue", comment: "Continue"),
            style: .Default , handler: {(alert: UIAlertAction!) in
                self.checkForDuplicatesPushed = true
                self.performSegueWithIdentifier("importAllSamples", sender: self)
        })
        
        let cancelAction = UIAlertAction(title: NSLocalizedString("Cancel", comment: "Cancel"),
            style: .Cancel, handler: nil)
        
        alert.addAction(continueAction)
        alert.addAction(cancelAction)
        
        self.presentViewController(alert, animated: true,
            completion: nil)
    }


}
