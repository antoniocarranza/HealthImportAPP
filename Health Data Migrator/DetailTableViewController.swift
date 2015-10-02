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
    
    var appDel: AppDelegate?
    var managedObjectContext: NSManagedObjectContext?
    let healthStore = HKHealthStore()
    
    var detailItem: BackupFile? {
        didSet {
            // Update the view.
            self.configureView()
            self.appDel = (UIApplication.sharedApplication().delegate as! AppDelegate)
            self.managedObjectContext = appDel?.managedObjectContext
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
        let sortDescriptor = NSSortDescriptor(key: "startDate", ascending: false)
        
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
        
        let importButton = UIBarButtonItem(barButtonSystemItem: .Play, target: self, action: "importSamples:")
        self.navigationItem.rightBarButtonItem = importButton

    }

    override func didReceiveMemoryWarning() {
        super.didReceiveMemoryWarning()
        // Dispose of any resources that can be recreated.
    }

    // MARK: - Authorize and Import
    
    func importSamples(sender: UIBarButtonItem) {
        print("ImportSamples...")
        
        var samples: [HKObject] = []
        
        sender.enabled = false
//        for var index = 0; index < self.tableView.numberOfRowsInSection(0); ++index {
//            let cell = self.tableView.cellForRowAtIndexPath(NSIndexPath(forRow: index, inSection: 0))
//            cell?.accessoryType = .Checkmark
//        }
        for item in self.fetchedResultsController.fetchedObjects! {
            let sample = (item as! QuantitySample)
            
            let type = HKObjectType.quantityTypeForIdentifier("HKQuantityTypeIdentifierBodyMass")
            let unit = HKUnit(fromString: sample.quantityType!)

            let value = sample.quantity?.doubleValue
            let quantity = HKQuantity(unit: unit, doubleValue: value!)
            let metadata  = [HKMetadataKeyWasUserEntered:false]
            let hkSample = HKQuantitySample(type: type!, quantity: quantity, startDate: sample.startDate!, endDate: sample.endDate!, metadata: metadata)
            
            sample.foundInHealthKit = true
            samples.append(hkSample)
        }
        healthStore.saveObjects(samples, withCompletion: { (success, error) -> Void in
            
            if error != nil {
                print("Sin errores")
                return
            }
            
            if success {
                print("Se importo con exito")
            } else {
                print("Algo falló con la importación")
            }
        })
        self.tableView.reloadData()
    }
    
    // MARK: - Table view data source

    override func numberOfSectionsInTableView(tableView: UITableView) -> Int {
        // #warning Incomplete implementation, return the number of sections
        return self.fetchedResultsController.sections?.count ?? 0
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
        
        cell.textLabel!.text = "\(sample.source!), \(formateador.stringFromDate(sample.startDate!))"
        if sample.quantity != nil && sample.quantityType != nil {
                cell.detailTextLabel!.text = "\(sample.quantity!) \(sample.quantityType!)"
            } else {
                cell.detailTextLabel!.text = ""
            }
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

}
