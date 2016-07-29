//
//  AppDelegate.swift
//  Location Alarm
//
//  Created by Nicholas Arduini on 2016-05-09.
//  Copyright © 2016 Nicholas Arduini. All rights reserved.
//

import UIKit
import CoreLocation
import AVFoundation
import AudioToolbox

@UIApplicationMain
class AppDelegate: UIResponder, UIApplicationDelegate, CLLocationManagerDelegate {
    
    var locationManager = CLLocationManager()
    var window: UIWindow?
    var audioPlayer = AVAudioPlayer()
    
    let defaultsStore = DefaultsStorage()
    
    func application(application: UIApplication, didFinishLaunchingWithOptions launchOptions: [NSObject: AnyObject]?) -> Bool {
        // Override point for customization after application launch.
        locationManager = CLLocationManager()
        locationManager.delegate = self
        locationManager.requestAlwaysAuthorization()
        
        application.registerUserNotificationSettings(UIUserNotificationSettings(forTypes: [.Sound, .Alert, .Badge], categories: nil))
        UIApplication.sharedApplication().cancelAllLocalNotifications()
        
        setUpNotifications()
        
        return true
    }
    
    func applicationWillResignActive(application: UIApplication) {
        // Sent when the application is about to move from active to inactive state. This can occur for certain types of temporary interruptions (such as an incoming phone call or SMS message) or when the user quits the application and it begins the transition to the background state.
        // Use this method to pause ongoing tasks, disable timers, and throttle down OpenGL ES frame rates. Games should use this method to pause the game.
    }
    
    func applicationDidEnterBackground(application: UIApplication) {
        // Use this method to release shared resources, save user data, invalidate timers, and store enough application state information to restore your application to its current state in case it is terminated later.
        // If your application supports background execution, this method is called instead of applicationWillTerminate: when the user quits.
    }
    
    func applicationWillEnterForeground(application: UIApplication) {
        // Called as part of the transition from the background to the inactive state; here you can undo many of the changes made on entering the background.
        
    }
    
    func applicationDidBecomeActive(application: UIApplication) {
        // Restart any tasks that were paused (or not yet started) while the application was inactive. If the application was previously in the background, optionally refresh the user interface.
    }
    
    func applicationWillTerminate(application: UIApplication) {
        // Called when the application is about to terminate. Save data if appropriate. See also applicationDidEnterBackground:.
    }
    
    func setupAudio() {
        do {
            if let bundle = NSBundle.mainBundle().pathForResource("Hillside", ofType: "wav") {
                let alertSound = NSURL(fileURLWithPath: bundle)
                try AVAudioSession.sharedInstance().setCategory(AVAudioSessionCategoryPlayback)
                try AVAudioSession.sharedInstance().setActive(true)
                try audioPlayer = AVAudioPlayer(contentsOfURL: alertSound)
                audioPlayer.prepareToPlay()
                audioPlayer.numberOfLoops = 500000
            }
        } catch {
            alertUser("Warning", message: "Error trying to play alert sound")
            print(error)
        }
    }
    
    func alertUser(title: String, message: String){
        let alert = UIAlertController(title: title, message: message, preferredStyle: .Alert)
        let action = UIAlertAction(title: "OK", style: .Cancel, handler: nil)
        alert.addAction(action)
        self.window?.rootViewController?.presentViewController(alert, animated: true, completion: nil)
    }
    
    func alarmTriggeredAlert(title: String, message: String){
        let alert = UIAlertController(title: title, message: message, preferredStyle: .Alert)
        let a1 = UIAlertAction(title: "Stop Alarm", style: UIAlertActionStyle.Cancel, handler: {(alert: UIAlertAction!) in self.stopAlarm()})
        //let a2 = UIAlertAction(title: "Cancel", style: UIAlertActionStyle.Default, handler: nil)
        alert.addAction(a1)
        //alert.addAction(a2)
        self.window?.rootViewController!.presentViewController(alert, animated: true, completion: nil)
    }
    
    func stopAlarm(){
        audioPlayer.pause()
        NSNotificationCenter.defaultCenter().postNotificationName("stopAlarmNotification", object: nil)
    }
    
    func application(application: UIApplication, handleActionWithIdentifier identifier: String?,
                     forLocalNotification notification: UILocalNotification, completionHandler: () -> Void) {
        
        if(notification.category == "AlarmNotificationCategory"){
            if(identifier == "StopAlarm"){
                NSNotificationCenter.defaultCenter().postNotificationName("stopAlarmNotification", object: nil)
                audioPlayer.pause()
            }
        }
        
        completionHandler()
    }
    
    func setUpNotifications(){
        setupAudio()
        
        let stopAlarmAction = UIMutableUserNotificationAction()
        stopAlarmAction.identifier = "StopAlarm"
        stopAlarmAction.title = "Stop Alarm"
        stopAlarmAction.activationMode = UIUserNotificationActivationMode.Background
        stopAlarmAction.authenticationRequired = false
        stopAlarmAction.destructive = true
        
        let AlarmNotificationCategory = UIMutableUserNotificationCategory()
        AlarmNotificationCategory.identifier = "AlarmNotificationCategory"
        
        AlarmNotificationCategory.setActions([stopAlarmAction],
                                             forContext: UIUserNotificationActionContext.Default)
        
        AlarmNotificationCategory.setActions([stopAlarmAction],
                                             forContext: UIUserNotificationActionContext.Minimal)
        
        let settings = UIUserNotificationSettings(forTypes: UIUserNotificationType.Alert, categories: NSSet(object: AlarmNotificationCategory) as? Set<UIUserNotificationCategory>)
        UIApplication.sharedApplication().registerUserNotificationSettings(settings)
        
    }
    
    func application(application: UIApplication, didReceiveLocalNotification notification: UILocalNotification) {
        alarmTriggeredAlert("Alarm Triggered", message: notification.alertBody!)
        AudioServicesPlayAlertSound(SystemSoundID(kSystemSoundID_Vibrate))
    }
    
    func handleRegionEvent(region: CLRegion!) {
        audioPlayer.play()
        
        let notification = UILocalNotification()
        notification.hasAction = true
        notification.alertBody = "You are within \(defaultsStore.getRadiusValue()) meters of your destination"
        notification.category = "AlarmNotificationCategory"
        
        UIApplication.sharedApplication().scheduleLocalNotification(notification)
    }
    
    func locationManager(manager: CLLocationManager, didEnterRegion region: CLRegion) {
        if region is CLCircularRegion {
            //handleRegionEvent(region)
        }

    }
    
    func locationManager(manager: CLLocationManager, didExitRegion region: CLRegion) {
        if region is CLCircularRegion {
            //handleRegionEvent(region)
        }
    }
    
    func locationManager(manager: CLLocationManager, didStartMonitoringForRegion region: CLRegion) {
        dispatch_after(dispatch_time(DISPATCH_TIME_NOW, Int64(0.1 * Double(NSEC_PER_SEC))), dispatch_get_main_queue()) {
            self.locationManager.requestStateForRegion(region)
        }
    }
    
    func locationManager(manager: CLLocationManager, didDetermineState state: CLRegionState, forRegion region: CLRegion) {
        if region is CLCircularRegion {
            if(state == CLRegionState.Inside){
                handleRegionEvent(region)
            }
        }
    }
    
}
