//
//  noPartnerViewController.swift
//  Pods
//
//  Created by Brandon Chen on 7/23/16.
//
//

import UIKit

class NoPartnerViewController: UIViewController {

    override func viewDidLoad() {
        super.viewDidLoad()

		self.navigationItem.hidesBackButton = true
		print("hi from no partner screen")
		// Do any additional setup after loading the view.
    }
	
	override func viewWillAppear(animated: Bool) {
		if let chat_id = AppState.sharedInstance.groupchat_id where chat_id != "" {
			navigationController!.popViewControllerAnimated(true)
			
		}
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
