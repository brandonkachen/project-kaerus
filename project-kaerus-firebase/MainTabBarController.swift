//
//  MainTabBarController.swift
//  project-kaerus-firebase
//
//  Created by Brandon Chen on 9/2/16.
//  Copyright © 2016 Brandon Chen. All rights reserved.
//

import UIKit

class MainTabBarController: UITabBarController {

    override func viewDidLoad() {
        super.viewDidLoad()
		self.tabBarItem.imageInsets = UIEdgeInsetsMake(6, 0, -6, 0)
		self.title = nil
    }

    override func didReceiveMemoryWarning() {
        super.didReceiveMemoryWarning()
        // Dispose of any resources that can be recreated.
    }
    

    /*
    // MARK: - Navigation

    // In a storyboard-based application, you will often want to do a little preparation before navigation
    override func prepareForSegue(segue: UIStoryboardSegue, sender: AnyObject?) {
        // Get the new view controller using segue.destinationViewController.
        // Pass the selected object to the new view controller.
    }
    */

}
