//
//  QuantitySample+CoreDataProperties.swift
//  Health Data Migrator
//
//  Created by Antonio Carranza López on 2/10/15.
//  Copyright © 2015 Antonio Carranza López. All rights reserved.
//
//  Choose "Create NSManagedObject Subclass…" from the Core Data editor menu
//  to delete and recreate this implementation file for your updated model.
//

import Foundation
import CoreData

extension QuantitySample {

    @NSManaged var endDate: NSDate
    @NSManaged var quantity: Double
    @NSManaged var quantityType: String
    @NSManaged var source: String
    @NSManaged var startDate: NSDate
    @NSManaged var backupFile: BackupFile
    @NSManaged var foundInHealthKit: Bool
    @NSManaged var typeIdentifier: String
    @NSManaged var recordCount: Double

}
