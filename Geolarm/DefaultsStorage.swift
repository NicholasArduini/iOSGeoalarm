//
//  DefaultsStorage.swift
//  Location Alarm
//
//  Created by Nicholas Arduini on 2016-07-25.
//  Copyright © 2016 Nicholas Arduini. All rights reserved.
//

import Foundation

class DefaultsStorage {
    let defaults = NSUserDefaults.standardUserDefaults()
    let kmOnKey = "kmOnKey" //used to store users choice of km or miles
    let radiusInMetersKey = "radiusInMetersKey" //used to store the current destination radius
    
    func setKmOnValue(kmOnSwitch: Bool){
        if(kmOnSwitch){
            defaults.setValue("true", forKey: kmOnKey)
        } else {
            defaults.setValue("false", forKey: kmOnKey)
        }
        
        defaults.synchronize()
    }
    
    func getKmOnValue(inout kmOnSwitch: Bool){
        if let value = defaults.stringForKey(kmOnKey){
            if(value == "true"){
                kmOnSwitch = true
            } else {
                kmOnSwitch = false
            }
        }
    }
    
    func setRadiusValue(locationRadius: Int){
        defaults.setValue("\(locationRadius)", forKey: radiusInMetersKey)
    }
    
    func getRadiusValue() -> String{
        if let value = defaults.stringForKey(radiusInMetersKey) {
            return value
        }
        
        return " "
    }
}
