//
//  AlarmLocation.swift
//  Location Alarm
//
//  Created by Nicholas Arduini on 2016-06-01.
//  Copyright © 2016 Nicholas Arduini. All rights reserved.
//

import Foundation
import CoreLocation

class AlarmLocation {
    var coordinate: CLLocationCoordinate2D
    var radius: CLLocationDistance
    var identifier: String
    
    init(coordinate: CLLocationCoordinate2D, radius: CLLocationSpeed, identifier: String){
        self.coordinate = coordinate
        self.radius = radius
        self.identifier = identifier
    }

}
