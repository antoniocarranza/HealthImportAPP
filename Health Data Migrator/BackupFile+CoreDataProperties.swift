//
//  BackupFile+CoreDataProperties.swift
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

extension BackupFile {

    @NSManaged var exportDate: NSDate?
    @NSManaged var fileName: String?
    @NSManaged var fileURLWithPath: String?
    @NSManaged var lastImportDate: NSDate?
    @NSManaged var quantitySamples: NSSet?
    @NSManaged var quantitySamplesCount: Double
    @NSManaged var permissionsList: String

}
