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
        self.dismissViewControllerAnimated(true, completion: {print("Closed \(self)")})
    }
    
    var lastSearchDuplatesSamplesFound: Int = 0
    var querySet: Set<QuantitySample> = []
    var checking: Bool = false
    var importing: Bool = false
    var healthStore: HKHealthStore? = nil
    var fetchedResultsController: NSFetchedResultsController? = nil
    
    var samplesToImport: [AnyObject] = [] {
        didSet  {
            print("SamplesToImport didSet: \(samplesToImport.count)")
        }
    }
    var samplesToCheck: [AnyObject] = [] {
        didSet {
            print("samplesToCheck didSet: \(samplesToCheck.count)")
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
        
        let incremento: Float = (1 / Float(quantitySamples.count))
        var valor: Float = 0.0
        var isBarAnimated: Bool = false
        if quantitySamples.count > 999 { isBarAnimated = true}
        lastSearchDuplatesSamplesFound = 0
        
        var totalQueriesCount = 0
        let totalQueries = quantitySamples.count
        var totalQueriesExecuted = 0
        
        print("Buscando duplicados...")
        
        dispatch_async(GlobalUserInitiatedQueue) {
            [unowned self] in
            for item in quantitySamples {
                
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
                            print(error)
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
                        print("Busqueda finalizada")
                        print(self.lastSearchDuplatesSamplesFound)
                        
                        let context = self.fetchedResultsController?.managedObjectContext
                        do {
                            try context?.save()
                            print("context saved")
                            print("Recargando los datos de la tabla")
                        } catch {
                            // Replace this implementation with code to handle the error appropriately.
                            // abort() causes the application to generate a crash log and terminate. You should not use this function in a shipping application, although it may be useful during development.
                            print("Unresolved error \(error)")
                            //abort()
                        }

                        
                        dispatch_async(GlobalMainQueue) {
                            self.importSamplesLabel.text = String(format: NSLocalizedString("CheckForDuplicatesFinished", comment: "La Busqueda de duplicados finalizo"), formatNumberInDecimalStyle(self.lastSearchDuplatesSamplesFound))
                            self.closeButton.hidden = false
                        }
                    }
                    
                })
 
                self.healthStore!.executeQuery(hkQuery)
                totalQueriesExecuted += 1
                while totalQueriesExecuted - totalQueriesCount > 350 {
                    sleep(1)
                    print("\(NSDate()) - Ejecutadas: \(totalQueriesExecuted)")
                    print("\(NSDate()) - Pendientes: \(totalQueriesExecuted - totalQueriesCount)")
                }
            }
        }
        


    }

    func importThisSamples(samples: [AnyObject]) {
        print("importThisSample...")

        closeButton.setAttributedTitle(NSAttributedString(string: NSLocalizedString("Close", comment: "Close")), forState: .Normal)
        importSamplesLabel.text = "Importando \(samples.count) muestras"

        let incremento: Float = (1.0 / Float(samples.count))
        var valor: Float = 0.0
        var isBarAnimated: Bool = false
        if samples.count > 999 { isBarAnimated = true}
        
        var samplesSet: [HKObject] = []
        var modifiedSamples: [QuantitySample] = []
        
        dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_BACKGROUND, 0), {
            for item in samples {
                let sample = (item as! QuantitySample)
                
                valor = valor + incremento
                dispatch_async(dispatch_get_main_queue(), {
                    self.progressBar.setProgress(valor, animated: isBarAnimated)
                })
                
                let type = HKObjectType.quantityTypeForIdentifier(sample.typeIdentifier)
                let unit = HKUnit(fromString: sample.quantityType)
                
                let value = sample.quantity
                let quantity = HKQuantity(unit: unit, doubleValue: value)
                let metadata  = [HKMetadataKeyWasUserEntered:true]
                let hkSample = HKQuantitySample(type: type!, quantity: quantity, startDate: sample.startDate, endDate: sample.endDate, metadata: metadata)
                
                if sample.foundInHealthKit == false {
                    samplesSet.append(hkSample)
                    modifiedSamples.append(sample)
                }
            }
            if samplesSet.count > 0 {
                dispatch_async(GlobalMainQueue) {
                    self.importSamplesLabel.text = NSLocalizedString("StoringNow", comment: "Storing at database now, wait...")
                    }
                self.healthStore!.saveObjects(samplesSet, withCompletion: { (success, error) -> Void in
                    if error != nil {
                        print("Errores, terminó la importación con estado \(success)")
                        print("Error: Algo falló con la importación!!! \(error)")
                        dispatch_async(GlobalMainQueue) {
                        self.importSamplesLabel.text = NSLocalizedString("ImportError", comment: "Something were wrong. sorry")
                        self.closeButton.hidden = false
                            }
                        return
                    }
                    if success {
                        for sample in modifiedSamples {
                            sample.foundInHealthKit = true
                        }
                        let msg =   NSLocalizedString("SamplesImported", comment: "number of samples imported")
                        let userInfo = "\(samplesSet.count.description)/\(samples.count.description) \(msg)"
                        dispatch_async(GlobalMainQueue) {
                            self.importSamplesLabel.text = userInfo
                            self.closeButton.hidden = false
                        }
                        print(userInfo)
                    } else {
                        dispatch_async(GlobalMainQueue) {
                            self.importSamplesLabel.text = NSLocalizedString("ImportError", comment: "Something were wrong. please contact support.")
                            self.closeButton.hidden = false
                            }
                        print("Error: Algo falló con la importación pero el sistema no notifico error!!!")
                    }
                })
            } else {
                print("Nada que importar")
                dispatch_async(GlobalMainQueue) {
                    self.importSamplesLabel.text = NSLocalizedString("NothingToImport", comment: "Nothing to Import")
                    self.closeButton.hidden = false
                }
            }
        })
    }
}
