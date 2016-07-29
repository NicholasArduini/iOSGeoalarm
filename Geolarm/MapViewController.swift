//
//  MapViewController.swift
//  Location Alarm
//
//  Created by Nicholas Arduini on 2016-05-09.
//  Copyright © 2016 Nicholas Arduini. All rights reserved.
//

import UIKit
import MapKit
import CoreLocation
import MediaPlayer

protocol HandleMapSearch {
    func onCellItemSelected(placemark:MKPlacemark)
}

class MapViewController: UIViewController, UIGestureRecognizerDelegate, CLLocationManagerDelegate, HandleMapSearch {
    
    @IBOutlet var mapView: MKMapView!
    
    @IBOutlet var currentLocationButton: UIButton!
    @IBOutlet var viewRouteButton: UIButton!
    @IBOutlet var setAlarmButton: UIButton!
    @IBOutlet var deleteButton: UIButton!
    @IBOutlet var cancelDeleteButton: UIButton!
    @IBOutlet var radiusSlider: UISlider!
    @IBOutlet var unitSwitchButton: UIButton!
    @IBOutlet var radiusInMetersLabel: UILabel!
    
    var searchBar:UISearchBar? = nil
    
    let locationManager = CLLocationManager()
    var resultsSearchController:UISearchController? = nil
    
    var destinationLocation:CLLocationCoordinate2D? = nil
    var cancelButtonColor: UIColor!
    var setButtonColor: UIColor!
    var currentLocationSelected = true //location toggle
    var locationRadius = 1500.0
    var sliderValue:Float = 1500.0
    var sliderLastValue = 750
    var destinationRadiusCircle:MKCircle? = nil
    var deleteConfirmed = false
    var kmOnSwitch = false
    var alarmRunning = false
    var volumeAlertShown = false
    var alarmJustStarted = true // used to zoom out the map if the current location isn't already inside the destination radius on start
    let masterVolumeSlider: MPVolumeView = MPVolumeView() //to change the volumeof the device
    let defaultsStore = DefaultsStorage()
    
    func alertUser(title: String, message: String){
        let alert = UIAlertController(title: title, message: message, preferredStyle: .Alert)
        let action = UIAlertAction(title: "OK", style: UIAlertActionStyle.Cancel, handler: nil)
        alert.addAction(action)
        self.presentViewController(alert, animated: true, completion: nil)
    }
    
    func alertUserVolume(title: String, message: String){
        let alert = UIAlertController(title: title, message: message, preferredStyle: .Alert)
        let a1 = UIAlertAction(title: "Ignore", style: UIAlertActionStyle.Default, handler: nil)
        let a2 = UIAlertAction(title: "Set to 50%", style: UIAlertActionStyle.Cancel, handler: {(alert: UIAlertAction!) in self.changeAudioToHalf()})
        alert.addAction(a1)
        alert.addAction(a2)
        self.presentViewController(alert, animated: true, completion: nil)
    }
    
    //request the users location on launch
    func locationManager(manager: CLLocationManager, didChangeAuthorizationStatus status: CLAuthorizationStatus) {
        mapView.showsUserLocation = (status == .AuthorizedAlways)
    }
    
    func locationManager(manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        if(currentLocationSelected){
            if let location = locations.first {
                centerMapOnLocation(location)
            }
        }
        
        if(alarmRunning){
            updateDistance()
            if(!volumeAlertShown){
                checkVolume()
            }
        }
        
    }
    
    func locationManager(manager: CLLocationManager, didFailWithError error: NSError) {
        print("Location Manager failed with the following error: \(error)")
    }
    
    func locationManager(manager: CLLocationManager, monitoringDidFailForRegion region: CLRegion?, withError error: NSError) {
        print("Monitoring failed for region with identifier: \(region!.identifier)")
        alertUser("Warning", message: "Alarm monitoring for your destination has failed")
    }
    
    //reset the current location button when the user moves the map
    func onDragMap(gestureRecognizer: UIGestureRecognizer) {
        currentLocationButton.setImage(UIImage(named: "noCurrentLocation")!, forState: .Normal)
        currentLocationSelected = false
    }
    
    func gestureRecognizer(gestureRecognizer: UIGestureRecognizer, shouldRecognizeSimultaneouslyWithGestureRecognizer otherGestureRecognizer: UIGestureRecognizer) -> Bool {
        return true
    }
    
    func regionWithAlarmLocation(alarmLocation: AlarmLocation) -> CLCircularRegion {
        let region = CLCircularRegion(center: alarmLocation.coordinate, radius: alarmLocation.radius, identifier: alarmLocation.identifier)
        region.notifyOnEntry = true
        return region
    }
    
    func startMonitoringAlarmLocation(alarmLocation: AlarmLocation) {
        if(!CLLocationManager.isMonitoringAvailableForClass(CLCircularRegion)){
            alertUser("Error", message: "Geofencing is not supported on this device")
            return
        }
        
        if(CLLocationManager.authorizationStatus() != .AuthorizedAlways){
            alertUser("Warning", message: "You must grant Location Alarm permission to access the device location")
        }
        
        stopMonitoringAlarmLocations()
        let region = regionWithAlarmLocation(alarmLocation)
        locationManager.startMonitoringForRegion(region)
    }
    
    func stopMonitoringAlarmLocations() {
        for region in locationManager.monitoredRegions {
            if let circularRegion = region as? CLCircularRegion {
                mapView.removeOverlays(mapView.overlays)
                locationManager.stopMonitoringForRegion(circularRegion)
            }
        }
    }
    
    func addRadiusOverlayForAlarmLocation(alarmLocation: AlarmLocation) {
        mapView?.addOverlay(MKCircle(centerCoordinate: alarmLocation.coordinate, radius: alarmLocation.radius))
    }
    
    func mapView(mapView: MKMapView!, rendererForOverlay overlay: MKOverlay!) -> MKOverlayRenderer! {
        //radius circle
        if overlay is MKCircle {
            let circleRenderer = MKCircleRenderer(overlay: overlay)
            circleRenderer.lineWidth = 5
            circleRenderer.strokeColor = UIColor.blueColor().colorWithAlphaComponent(0.6)
            circleRenderer.fillColor = UIColor.blueColor().colorWithAlphaComponent(0.08)
            return circleRenderer
        }
        
        return nil
    }
    
    func locationManager(manager: CLLocationManager, didDetermineState state: CLRegionState, forRegion region: CLRegion) {
        if region is CLCircularRegion {
            if(!(state == CLRegionState.Inside) && alarmJustStarted){
                zoomMapToShowPins()
                alarmJustStarted = false
            }
        }
    }
    
    func startAlarm(){
        unitSwitchButton.setTitle(" ", forState: .Normal)
        volumeAlertShown = false
        viewRouteButton.hidden = false
        unitSwitchButton.hidden = false
        radiusInMetersLabel.hidden = true
        radiusSlider.hidden = true
        deleteButton.setTitle("Delete Alarm", forState: .Normal)
        let alarmLocation = AlarmLocation(coordinate: destinationRadiusCircle!.coordinate, radius: locationRadius, identifier: "1")
        startMonitoringAlarmLocation(alarmLocation)
        mapView.selectedAnnotations.removeAll()
        updateDistance()
        alarmRunning = true
        defaultsStore.setRadiusValue(Int(locationRadius))
        if let view = masterVolumeSlider.subviews.first as? UISlider{
            view.value = 0.5
        }
        alarmJustStarted = true
    }
    
    func stopAlarm(){
        stopMonitoringAlarmLocations()
        mapView.removeAnnotations(mapView.annotations)
        mapView.removeOverlays(mapView.overlays)
        radiusSlider.hidden = true
        viewRouteButton.hidden = true
        deleteButton.hidden = true
        cancelDeleteButton.hidden = true
        currentLocationButton.hidden = false
        unitSwitchButton.hidden = true
        alarmRunning = false
        deleteConfirmed = false
    }
    
    //center the map view with the given location
    func centerMapOnLocation(location: CLLocation) {
        let coordinateRegion = MKCoordinateRegionMakeWithDistance(location.coordinate,
                                                                  2000, 2000)
        mapView.setRegion(coordinateRegion, animated: true)
    }
    
    func onCellItemSelected(placemark:MKPlacemark){
        stopAlarm()
        
        let annotation = MKPointAnnotation()
        annotation.coordinate = placemark.coordinate
        annotation.title = placemark.name
        annotation.subtitle = placemark.locality
        mapView.addAnnotation(annotation)
        mapView.selectAnnotation(annotation, animated: true)
        
        onPinDrop(annotation)
    }
    
    //add a pin by holding on the map
    func addAnnotation(gestureRecognizer:UIGestureRecognizer){
        if(alarmRunning){
            return
        }
        
        if gestureRecognizer.state == UIGestureRecognizerState.Began {
            let touchPoint = gestureRecognizer.locationInView(mapView)
            let newCoordinates = mapView.convertPoint(touchPoint, toCoordinateFromView: mapView)
            let annotation = MKPointAnnotation()
            annotation.coordinate = newCoordinates
            
            CLGeocoder().reverseGeocodeLocation(CLLocation(latitude: newCoordinates.latitude, longitude: newCoordinates.longitude), completionHandler: {(placemarks, error) -> Void in
                if(error != nil) {
                    self.alertUser("Warning", message: "Cannot drop pin, please check your connection")
                    return
                }
                
                self.stopAlarm()
                self.onPinDrop(annotation)
                
                if (placemarks!.count > 0) {
                    let placemark = placemarks![0]
                    annotation.title = placemark.name
                    annotation.subtitle = placemark.locality
                    self.mapView.addAnnotation(annotation)
                } else {
                    annotation.title = "Unknown Place"
                    self.mapView.addAnnotation(annotation)
                }
                
                self.mapView.selectAnnotation(annotation, animated: true)
            })
        }
    }
    
    func onPinDrop(annotation: MKPointAnnotation){
        //reset the current location button
        currentLocationButton.setImage(UIImage(named: "noCurrentLocation")!, forState: .Normal)
        currentLocationSelected = false
        
        deleteButton.setTitle("Delete", forState: .Normal)
        deleteConfirmed = true
        unitSwitchButton.hidden = true
        setAlarmButton.hidden = false
        radiusSlider.hidden = false
        deleteButton.hidden = false
        
        locationRadius = 1500
        radiusSlider.value = Float(locationRadius)
        
        radiusInMetersLabel.hidden = false
        radiusInMetersLabel.text = "  \(Int(locationRadius))  meters"
        
        destinationRadiusCircle = MKCircle(centerCoordinate: annotation.coordinate, radius: locationRadius)
        mapView?.addOverlay(destinationRadiusCircle!)
        
        //set the mapview to bound the radius of the dropped pin
        destinationLocation = annotation.coordinate
        mapView.setRegion(MKCoordinateRegionForMapRect(destinationRadiusCircle!.boundingMapRect), animated: true)
    }
    
    func zoomMapToShowPins(){
        var routeView: MKMapRect? = nil
        
        if(mapView.annotations.count >= 2){
            let annotationPoint1 = MKMapPointForCoordinate(mapView.annotations.first!.coordinate)
            let pointRect1 = MKMapRectMake(annotationPoint1.x, annotationPoint1.y, 0.1, 0.1)
            routeView = pointRect1
            
            let annotationPoint2 = MKMapPointForCoordinate(mapView.annotations[1].coordinate)
            let pointRect2 = MKMapRectMake(annotationPoint2.x, annotationPoint2.y, 0.1, 0.1)
            
            routeView = MKMapRectUnion(routeView!, pointRect2)
            
            //zoom the route view out a little more
            routeView!.size.height *= 2
            routeView!.size.width *= 2
            routeView!.origin.x -= routeView!.size.width/6
            routeView!.origin.y -= routeView!.size.height/6
            
            mapView.setVisibleMapRect(routeView!, animated: true)
        }
    }
    
    func distanceBetweenTwoLocations(source:CLLocation, destination:CLLocation) -> Double{
        let distanceMeters = source.distanceFromLocation(destination)
        let distanceKM = distanceMeters / 1000
        let roundedTwoDigit = distanceKM.roundedTwoDigit
        return roundedTwoDigit
    }
    
    func updateDistance(){
        let curLocation = CLLocation(latitude: mapView.userLocation.coordinate.latitude, longitude: mapView.userLocation.coordinate.longitude)
        let destLocation = CLLocation(latitude: (destinationLocation?.latitude)!, longitude: (destinationLocation?.longitude)!)
        
        let km = distanceBetweenTwoLocations(curLocation, destination: destLocation)
        let miles = (km * 0.621371).roundedTwoDigit
        
        if(!km.isFinite){
            unitSwitchButton.setTitle("  cannot find distance  ", forState: .Normal)
            return
        }
        
        if(kmOnSwitch){
            unitSwitchButton.setTitle("  \(km) km away  ", forState: .Normal)
        } else {
            if(miles == 1){
                unitSwitchButton.setTitle("  \(miles) mile away  ", forState: .Normal)
            } else {
                unitSwitchButton.setTitle("  \(miles) miles away  ", forState: .Normal)
            }
        }
    }
    
    
    @IBAction func currentLocationButton(sender: AnyObject) {
        //toggle on and off the current location button
        if(currentLocationSelected){
            currentLocationButton.setImage(UIImage(named: "noCurrentLocation")!, forState: .Normal)
            currentLocationSelected = false
            
        } else {
            currentLocationButton.setImage(UIImage(named: "currentLocation")!, forState: .Normal)
            let initialLocation = CLLocation(latitude: mapView.userLocation.coordinate.latitude, longitude: mapView.userLocation.coordinate.longitude)
            centerMapOnLocation(initialLocation)
            currentLocationSelected = true
        }
    }
    
    
    @IBAction func slider(sender: UISlider) {
        sliderValue = sender.value
        let intSliderValue = Int(sliderValue)
        
        //only change the radius if there is a significant change in the slider value
        if(intSliderValue > 1500){
            if((intSliderValue - sliderLastValue > 0 && intSliderValue - sliderLastValue < 2000) ||
                (intSliderValue - sliderLastValue < 0 && intSliderValue - sliderLastValue > -2000)){
                return
            }
        } else {
            if((intSliderValue - sliderLastValue > 0 && intSliderValue - sliderLastValue < 100) ||
                (intSliderValue - sliderLastValue < 0 && intSliderValue - sliderLastValue > -100)){
                return
            }
        }
        
        sliderLastValue = intSliderValue
        
        if(mapView.overlays.count > 0){
            locationRadius = Double(sliderValue)
            var mapOvl = mapView.overlays
            let circle = mapOvl.removeFirst()
            
            mapView?.addOverlay(MKCircle(centerCoordinate: circle.coordinate, radius: locationRadius))
            mapOvl.append(MKCircle(centerCoordinate: circle.coordinate, radius: locationRadius))
            
            radiusInMetersLabel.text = "  \(intSliderValue)  meters"
            
            mapView.setRegion(MKCoordinateRegionForMapRect((mapOvl.first?.boundingMapRect)!), animated: true)
            
            
            if(intSliderValue >= 45000){
                radiusSlider.maximumValue = 50000
            } else {
                
                if(intSliderValue >= sliderLastValue){
                    if(radiusSlider.maximumValue < 50000){
                        radiusSlider.maximumValue += 2000
                    }
                } else {
                    if(radiusSlider.maximumValue >= 3000){
                        radiusSlider.maximumValue -= 2000
                    }
                }
            }
            
            mapView.removeOverlay(circle)
        }
    }
    
    
    @IBAction func viewRouteButton(sender: AnyObject) {
        currentLocationButton.setImage(UIImage(named: "noCurrentLocation")!, forState: .Normal)
        currentLocationSelected = false
        zoomMapToShowPins()
    }
    
    @IBAction func deleteButton(sender: AnyObject) {
        setAlarmButton.hidden = true
        
        if(deleteConfirmed){ //pressing for the second time
            stopAlarm()
            let appDelegate = UIApplication.sharedApplication().delegate as! AppDelegate
            let aVariable = appDelegate.audioPlayer
            aVariable.pause()
            deleteConfirmed = false
            deleteButton.backgroundColor = cancelButtonColor
            radiusInMetersLabel.hidden = true
        } else { //pressing for the first time
            cancelDeleteButton.hidden = false
            currentLocationButton.hidden = true
            viewRouteButton.hidden = true
            deleteButton.setTitle("Confirm Delete", forState: .Normal)
            deleteButton.backgroundColor = setButtonColor
            deleteConfirmed = true
        }
    }
    
    @IBAction func setAlarmButton(sender: AnyObject) {
        setAlarmButton.hidden = true
        startAlarm()
    }
    
    @IBAction func cancelDeleteButton(sender: AnyObject) {
        cancelDeleteButton.hidden = true
        currentLocationButton.hidden = false
        viewRouteButton.hidden = false
        deleteButton.setTitle("Delete Alarm", forState: .Normal)
        deleteConfirmed = false
        deleteButton.backgroundColor = cancelButtonColor
    }
    
    @IBAction func unitSwitchButton(sender: AnyObject) {
        if(kmOnSwitch){
            kmOnSwitch = false
            if(alarmRunning){
                updateDistance()
            }
        } else {
            kmOnSwitch = true
            if(alarmRunning){
                updateDistance()
            }
        }
        
        defaultsStore.setKmOnValue(kmOnSwitch)
    }
    
    func handleStopAlarmNotification(){
        stopAlarm()
    }
    
    func changeAudioToHalf(){
        if let view = masterVolumeSlider.subviews.first as? UISlider{
            view.value = 0.5
        }
    }
    
    func checkVolume(){
        if(AVAudioSession().outputVolume < 0.5){
            alertUserVolume("Warning", message: "Volume is less than 50%")
            volumeAlertShown = true
        }
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        NSNotificationCenter.defaultCenter().addObserver(self, selector: #selector(MapViewController.handleStopAlarmNotification), name: "stopAlarmNotification", object: nil)
        
        stopAlarm()
        
        cancelButtonColor = cancelDeleteButton.backgroundColor
        setButtonColor = setAlarmButton.backgroundColor
        
        defaultsStore.getKmOnValue(&kmOnSwitch)
        
        deleteButton.layer.cornerRadius = 4
        cancelDeleteButton.layer.cornerRadius = 4
        unitSwitchButton.layer.cornerRadius = 4
        setAlarmButton.layer.cornerRadius = 4
        
        radiusSlider.value = Float(locationRadius)
        
        //map drag recongnizer
        let mapDragRecognizer = UIPanGestureRecognizer(target: self, action: #selector(MapViewController.onDragMap(_:)))
        mapDragRecognizer.delegate = self
        self.mapView.addGestureRecognizer(mapDragRecognizer)
        //map long press recognizer
        let mapLongPressRecognizer = UILongPressGestureRecognizer(target: self, action: #selector(MapViewController.addAnnotation(_:)))
        mapLongPressRecognizer.minimumPressDuration = 0.2
        mapView.addGestureRecognizer(mapLongPressRecognizer)
        
        locationManager.delegate = self
        locationManager.desiredAccuracy = kCLLocationAccuracyBest
        locationManager.requestAlwaysAuthorization()
        locationManager.startUpdatingLocation()
        
        let locationSearchTable = storyboard!.instantiateViewControllerWithIdentifier("MapSearchTable") as! MapSearchTable
        resultsSearchController = UISearchController(searchResultsController: locationSearchTable)
        
        resultsSearchController?.searchResultsUpdater = locationSearchTable
        resultsSearchController?.hidesNavigationBarDuringPresentation = false
        resultsSearchController?.dimsBackgroundDuringPresentation = true
        
        locationSearchTable.mapView = mapView
        locationSearchTable.handleMapSearchDelegate = self
        
        searchBar = resultsSearchController!.searchBar
        searchBar!.placeholder = "Search or drop pin"
        
        navigationItem.titleView = resultsSearchController?.searchBar
        
        definesPresentationContext = true
    }
}

extension Double{
    
    var roundedTwoDigit:Double{
        
        return Double(round(100*self)/100)
        
    }
}
