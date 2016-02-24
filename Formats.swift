//
//  Formats.swift
//  Health Import
//
//  Created by Antonio Carranza López on 20/11/15.
//  Copyright © 2015 Antonio Carranza López. All rights reserved.
//

import Foundation

func formatNumberInDecimalStyle (number: NSNumber) -> String {
    let numberFormatter = NSNumberFormatter()
    numberFormatter.numberStyle = .DecimalStyle
    return numberFormatter.stringFromNumber(number)!
}

