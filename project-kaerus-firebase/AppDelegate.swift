//
//  AppDelegate.swift
//  project-kaerus-firebase
//
//  Created by Brandon Chen on 7/15/16.
//  Copyright © 2016 Brandon Chen. All rights reserved.
//

import UIKit
import Firebase
import FirebaseInstanceID
import FirebaseMessaging
import FBSDKCoreKit
import FBSDKLoginKit

@UIApplicationMain
class AppDelegate: UIResponder, UIApplicationDelegate {

	var window: UIWindow?


	func application(application: UIApplication, didFinishLaunchingWithOptions launchOptions: [NSObject : AnyObject]?) -> Bool {
		// Override point for customization after application launch.
		
//		if #available(iOS 8.0, *) {
//			let settings: UIUserNotificationSettings =
//				UIUserNotificationSettings(forTypes: [.Alert, .Badge, .Sound], categories: nil)
//			application.registerUserNotificationSettings(settings)
//			application.registerForRemoteNotifications()
//		} else {
//			// Fallback
//			let types: UIRemoteNotificationType = [.Alert, .Badge, .Sound]
//			application.registerForRemoteNotificationTypes(types)
//		}
		
		FIRApp.configure()
		
		FIRAuth.auth()?.addAuthStateDidChangeListener { auth, user in
			if let _ = user {
				// user is logged in: load their info, then go to Goals screen
				AppState.sharedInstance.setState(user)
			} else {
				// user not logged in: load login screen
				let storyboard = UIStoryboard(name: "Main", bundle: nil)
				let rootVC = storyboard.instantiateViewControllerWithIdentifier("loginViewController") as! LoginViewController
				self.window?.rootViewController = rootVC
			}
		}
		return FBSDKApplicationDelegate.sharedInstance().application(application, didFinishLaunchingWithOptions: launchOptions)
	}
	
	func application(application: UIApplication, didReceiveRemoteNotification userInfo: [NSObject : AnyObject],
	                 fetchCompletionHandler completionHandler: (UIBackgroundFetchResult) -> Void) {
//		// If you are receiving a notification message while your app is in the background,
//		// this callback will not be fired till the user taps on the notification launching the application.
//		// TODO: Handle data of notification
//		
//		// Print message ID.
//		print("Message ID: \(userInfo["gcm.message_id"]!)")
//		
//		// Print full message.
//		print("%@", userInfo)
	}
	
//	func tokenRefreshNotification(notification: NSNotification) {
//		let refreshedToken = FIRInstanceID.instanceID().token()!
//		print("InstanceID token: \(refreshedToken)")
//		
//		// Connect to FCM since connection may have failed when attempted before having a token.
//		connectToFcm()
//	}
//	
//	func connectToFcm() {
//		FIRMessaging.messaging().connectWithCompletion { (error) in
//			if (error != nil) {
//				print("Unable to connect with FCM. \(error)")
//			} else {
//				print("Connected to FCM.")
//			}
//		}
//	}
	
	func applicationDidBecomeActive(application: UIApplication) {
		// Restart any tasks that were paused (or not yet started) while the application was inactive. If the application was previously in the background, optionally refresh the user interface.
//		FBSDKAppEvents.activateApp()
//		connectToFcm()
	}
	
	func applicationDidEnterBackground(application: UIApplication) {
//		FIRMessaging.messaging().disconnect()
//		print("Disconnected from FCM.")
	}

	func applicationWillResignActive(application: UIApplication) {
		// Sent when the application is about to move from active to inactive state. This can occur for certain types of temporary interruptions (such as an incoming phone call or SMS message) or when the user quits the application and it begins the transition to the background state.
		// Use this method to pause ongoing tasks, disable timers, and throttle down OpenGL ES frame rates. Games should use this method to pause the game.
	}

	func applicationWillEnterForeground(application: UIApplication) {
		// Called as part of the transition from the background to the inactive state; here you can undo many of the changes made on entering the background.
	}


	func applicationWillTerminate(application: UIApplication) {
		// Called when the application is about to terminate. Save data if appropriate. See also applicationDidEnterBackground:.
	}

	func application(application: UIApplication, openURL url: NSURL, sourceApplication: String?, annotation: AnyObject) -> Bool {
		return FBSDKApplicationDelegate.sharedInstance().application(application, openURL: url, sourceApplication: sourceApplication, annotation: annotation)
	}
}

