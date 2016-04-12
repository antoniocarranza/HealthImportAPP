//
//  ImportSamplesViewController.swift
//  Health Import
//
//  Created by Antonio Carranza López on 16/11/15.
//  Copyright © 2015 Antonio Carranza López. All rights reserved.
//

import UIKit
import CoreData
import HealthKit


class ImportSamplesViewController: UIViewController {

    
    @IBOutlet weak var messageForUserLabel: UILabel!
    @IBOutlet weak var importSamplesLabel: UILabel!
    @IBOutlet weak var progressBar: UIProgressView!
    @IBOutlet weak var closeButton: UIButton!
    @IBAction func closeButtonAction(sender: UIButton) {
        self.dismissViewControllerAnimated(true, completion: {log.debug("Closed \(self)")})
    }
    
    var lastSearchDuplatesSamplesFound: Int = 0
    var querySet: Set<QuantitySample> = []
    var checking: Bool = false
    var importing: Bool = false
    var healthStore: HKHealthStore? = nil
    var fetchedResultsController: NSFetchedResultsController? = nil
    
    var samplesToImport: [AnyObject] = [] {
        didSet  {
            log.debug("SamplesToImport didSet: \(samplesToImport.count)")
        }
    }
    var samplesToCheck: [AnyObject] = [] {
        didSet {
            log.debug("samplesToCheck didSet: \(samplesToCheck.count)")
        }
    }
    
    //MARK: - Ciclo de Vida de la aplicación
    
    func configureView() {
        // Update the user interface for the detail item.
        self.importSamplesLabel.text = ""
        self.messageForUserLabel.text = NSLocalizedString("LongProccess", comment: "Long Process")
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        // Do any additional setup after loading the view.
        if !samplesToCheck.isEmpty {
            checking = true
        }
        if !samplesToImport.isEmpty {
            importing = true
        }
        self.configureView()
    }
    
    override func viewDidAppear(animated: Bool) {
        if checking {
            checkForDuplicates(samplesToCheck)
        }
        if importing {
            importThisSamples(samplesToImport)
        }
    }
    
    override func viewWillDisappear(animated: Bool) {
        self.healthStore = nil
        self.fetchedResultsController = nil
        self.samplesToCheck.removeAll()
    }
    
    override func didReceiveMemoryWarning() {
        super.didReceiveMemoryWarning()
        // Dispose of any resources that can be recreated.
    }
    
    // MARK: - Busqueda de duplicados e Importación
    
    func checkForDuplicates(quantitySamples: [AnyObject]) {
        
        closeButton.setAttributedTitle(NSAttributedString(string: NSLocalizedString("Close", comment: "Close")), forState: .Normal)
        importSamplesLabel.text = String(format: NSLocalizedString("CheckForDuplicatesInSamples", comment: "Check for duplictes in n samples"), formatNumberInDecimalStyle(quantitySamples.count) )
        
        let context = self.fetchedResultsController!.managedObjectContext
        
        let incremento: Float = (1 / Float(quantitySamples.count))
        var valor: Float = 0.0
        var isBarAnimated: Bool = false
        if quantitySamples.count > 999 { isBarAnimated = true}
        lastSearchDuplatesSamplesFound = 0
        
        var totalQueriesCount = 0
        let totalQueries = quantitySamples.count
        var totalQueriesExecuted = 0
        
        log.debug("Buscando duplicados...")
        
        UIApplication.sharedApplication().idleTimerDisabled = true
        log.debug("Modo reposo desactivado")
        
        dispatch_async(GlobalUserInitiatedQueue) {
            //[unowned self] in
            autoreleasepool{
                for item in quantitySamples {
                    autoreleasepool{
                        let sample = (item as! QuantitySample)
                        let type = HKObjectType.quantityTypeForIdentifier(sample.typeIdentifier)
                        let explicitTimeInterval = NSPredicate(format: "%K = %@ AND %K = %@",
                            HKPredicateKeyPathStartDate, sample.startDate,
                            HKPredicateKeyPathEndDate, sample.endDate)
                        let unit = HKUnit(fromString: sample.quantityType)
                        let value: Double = sample.quantity
                        
                        let quantity = HKQuantity(unit: unit, doubleValue: value)
                        let explicitValue = HKQuery.predicateForQuantitySamplesWithOperatorType(.EqualToPredicateOperatorType, quantity: quantity)
                        let compoundPredicate = NSCompoundPredicate(andPredicateWithSubpredicates: [explicitTimeInterval, explicitValue])
                        
                        let hkQuery = HKSampleQuery(sampleType: type!, predicate: compoundPredicate, limit: 1, sortDescriptors: nil, resultsHandler: { (hkSampleQuery, querySamples, error) -> Void in
                            
                            totalQueriesCount += 1
                            valor = valor + incremento
                            
                            if (error != nil) {
                                dispatch_async(GlobalMainQueue) {
                                    log.error((error?.description)!)
                                    return
                                }
                            }
                            if querySamples?.count != 0 {
                                dispatch_async(GlobalMainQueue) {
                                    self.lastSearchDuplatesSamplesFound += 1
                                    sample.foundInHealthKit = true
                                }
                            }
                            dispatch_async(GlobalMainQueue) {
                                self.progressBar.setProgress(valor, animated: isBarAnimated)
                            }
                            
                            if totalQueriesCount == totalQueries {
                                log.debug("Busqueda finalizada")
                                log.debug(String(self.lastSearchDuplatesSamplesFound))
                                
                                do {
                                    try context.save()
                                    context.reset()
                                    log.debug("context saved")
                                } catch {
                                    // Replace this implementation with code to handle the error appropriately.
                                    // abort() causes the application to generate a crash log and terminate. You should not use this function in a shipping application, although it may be useful during development.
                                    log.error("Unresolved error \(error)")
                                    //abort()
                                }
                                
                                
                                dispatch_async(GlobalMainQueue) {
                                    self.importSamplesLabel.text = String(format: NSLocalizedString("CheckForDuplicatesFinished", comment: "La Busqueda de duplicados finalizo"), formatNumberInDecimalStyle(self.lastSearchDuplatesSamplesFound))
                                    self.closeButton.hidden = false
                                    UIApplication.sharedApplication().idleTimerDisabled = false
                                    log.debug("Modo reposo activado")
                                }
                            }
                            
                        })
                        
                        log.debug(hkQuery.debugDescription)
                        self.healthStore!.executeQuery(hkQuery)
                        totalQueriesExecuted += 1
                        
                        if (Double(totalQueriesExecuted)/500.0) == round(Double(totalQueriesExecuted)/500.0) {
                            
                            dispatch_async(GlobalMainQueue) {
                                self.importSamplesLabel.text = String(format: NSLocalizedString("Waiting", comment: "Waiting"), formatNumberInDecimalStyle(quantitySamples.count) )
                            }

                            while totalQueriesExecuted - totalQueriesCount != 0{
                                sleep(1)
                                log.debug("Queries pending \(totalQueriesExecuted - totalQueriesCount)")
                            }

                            do {
                                try context.save()
                                context.reset()
                                log.debug("context saved")
                            } catch {
                                // Replace this implementation with code to handle the error appropriately.
                                // abort() causes the application to generate a crash log and terminate. You should not use this function in a shipping application, although it may be useful during development.
                                log.error("Unresolved error \(error)")
                                //abort()
                            }
                            dispatch_async(GlobalMainQueue) {
                                self.importSamplesLabel.text = String(format: NSLocalizedString("CheckForDuplicatesInSamples", comment: "Check for duplictes in n samples"), formatNumberInDecimalStyle(quantitySamples.count) )
                            }


                        }
                        
//                        while totalQueriesExecuted - totalQueriesCount > 350 {
//                            sleep(1)
//                            log.debug("\(NSDate()) - Ejecutadas: \(totalQueriesExecuted)")
//                            log.debug("\(NSDate()) - Pendientes: \(totalQueriesExecuted - totalQueriesCount)")
//                        }
                    }
                }
            }
        }
        


    }

    func importThisSamples(samples: [AnyObject]) {
        log.debug("importThisSample...")
        
        UIApplication.sharedApplication().idleTimerDisabled = true
        log.debug("Modo reposo desactivado")
        
        closeButton.setAttributedTitle(NSAttributedString(string: NSLocalizedString("Close", comment: "Close")), forState: .Normal)
        let msg =   NSLocalizedString("CreatingSamples", comment: "CreatingSamples")
        self.importSamplesLabel.text = msg
        
        let context = self.fetchedResultsController!.managedObjectContext
        
        let incremento: Float = (1.0 / Float(samples.count))
        var valor: Float = 0.0
        var isBarAnimated: Bool = false
        if samples.count > 999 { isBarAnimated = true}
        
        var samplesSet: [HKObject] = []
        var modifiedSamples: [QuantitySample] = []
        
        var savedSamplesCounter: Int = 0
        let totalSamplesCounter: Int = samples.count
        var pendingSamplesCounter : Int = totalSamplesCounter - savedSamplesCounter
        
        var continueLoop: Bool = true
        var contador: Int = 0
        dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_BACKGROUND, 0), {
            
            autoreleasepool{
                for item in samples {
                    autoreleasepool{
                        contador += 1
                        let sample = (item as! QuantitySample)
                        
                        valor = valor + incremento
                        dispatch_async(dispatch_get_main_queue(), {
                            self.progressBar.setProgress(valor, animated: isBarAnimated)
                        })
                        
                        let type = HKObjectType.quantityTypeForIdentifier(sample.typeIdentifier)!
                        let unit = HKUnit(fromString: sample.quantityType)
                        
                        let value = sample.quantity
                        let quantity = HKQuantity(unit: unit, doubleValue: value)
                        let metadata  = [HKMetadataKeyWasUserEntered:true]
                        let hkSample = HKQuantitySample(type: type, quantity: quantity, startDate: sample.startDate, endDate: sample.endDate, metadata: metadata)
                        
                        if sample.foundInHealthKit == false {
                            samplesSet.append(hkSample)
                            modifiedSamples.append(sample)
                        }
                        
                        if samplesSet.count == 50000 || samplesSet.count == pendingSamplesCounter {
                            continueLoop = false
                            savedSamplesCounter += samplesSet.count
                            pendingSamplesCounter = totalSamplesCounter - savedSamplesCounter
                            log.debug(String(savedSamplesCounter))
                            dispatch_async(GlobalMainQueue) {
                                self.importSamplesLabel.text = NSLocalizedString("Waiting", comment: "Waiting")
                            }
                            self.healthStore!.saveObjects(samplesSet, withCompletion: { (success, error) -> Void in
                                
                                if error != nil {
                                    log.debug("Errores, terminó la importación con estado \(success)")
                                    log.error("Error: Algo falló con la importación!!! \(error)")
                                    dispatch_async(GlobalMainQueue) {
                                        self.importSamplesLabel.text = NSLocalizedString("ImportError", comment: "Something were wrong. sorry")
                                        self.notifyUser(NSLocalizedString("ImportError", comment: "Something were wrong. sorry"), err: error?.description)
                                        log.debug(samplesSet.debugDescription)
                                        self.closeButton.hidden = false
                                        UIApplication.sharedApplication().idleTimerDisabled = false
                                        log.debug("Modo reposo activado")
                                    }
                                    return
                                }
                                                                
                                samplesSet.removeAll()
                                
                                if success {
                                    for sample in modifiedSamples {
                                        sample.foundInHealthKit = true
                                    }
                                    
                                    do {
                                        try context.save()
                                        //context.reset()
                                        log.debug("context saved")
                                    } catch {
                                        // Replace this implementation with code to handle the error appropriately.
                                        // abort() causes the application to generate a crash log and terminate. You should not use this function in a shipping application, although it may be useful during development.
                                        log.error("Unresolved error \(error)")
                                        //abort()
                                    }
                                    
                                    modifiedSamples.removeAll()
                                    
                                    continueLoop = true
                                    dispatch_async(GlobalMainQueue) {
                                        let msg =   NSLocalizedString("CreatingSamples", comment: "CreatingSamples")
                                        self.importSamplesLabel.text = msg
                                    }
                                } else {
                                    dispatch_async(GlobalMainQueue) {
                                        self.importSamplesLabel.text = NSLocalizedString("ImportError", comment: "Something were wrong. please contact support.")
                                        
                                        self.notifyUser(NSLocalizedString("ImportError", comment: "Something were wrong. sorry"), err: error?.description)
                                        
                                        self.closeButton.hidden = false
                                        UIApplication.sharedApplication().idleTimerDisabled = false
                                        log.debug("Modo reposo activado")
                                    }
                                    log.error("Error: Algo falló con la importación pero el sistema no notifico error!!!")
                                }
                            })
                        }
                        if continueLoop == false {
                            dispatch_async(GlobalMainQueue) {
                                self.importSamplesLabel.text = NSLocalizedString("StoringNow", comment: "Storing at database now, wait...")
                            }
                            while continueLoop == false {
                                sleep(1)
                            }

                        }
                    }
                }
            }

            log.debug("Waiting to finish...")
            while continueLoop == false {
                sleep(1)
                
            }
            
            dispatch_async(GlobalMainQueue) {
                let msg =   NSLocalizedString("SamplesImported", comment: "number of samples imported")
                let userInfo = "\(savedSamplesCounter)/\(totalSamplesCounter) \(msg)"
                self.importSamplesLabel.text = userInfo
                self.closeButton.hidden = false
                UIApplication.sharedApplication().idleTimerDisabled = false
                log.debug("Modo reposo activado")
            }
            
            //context.reset()
            
        })
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
}
