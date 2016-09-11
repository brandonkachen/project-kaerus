//
//  CustomizePaymentsPageViewController.swift
//  project-kaerus-firebase
//
//  Created by Brandon Chen on 9/10/16.
//  Copyright © 2016 Brandon Chen. All rights reserved.
//

import UIKit

class CustomizePaymentsPageViewController: UIPageViewController {

	private(set) lazy var orderedViewControllers: [UIViewController] = {
		return [self.newCustomizedPaymentViewController("EachDayCost"),
		        self.newCustomizedPaymentViewController("MaxLimitBeforeLocking"),
		        self.newCustomizedPaymentViewController("SplitDeadlinesCost")]
	}()
	
	private func newCustomizedPaymentViewController(nameOfVC: String) -> UIViewController {
		return UIStoryboard(name: "Main", bundle: nil) .
			instantiateViewControllerWithIdentifier("\(nameOfVC)ViewController")
	}
	
    override func viewDidLoad() {
        super.viewDidLoad()

		dataSource = self
		
		if let firstViewController = orderedViewControllers.first {
			setViewControllers([firstViewController],
			                   direction: .Forward,
			                   animated: true,
			                   completion: nil)
		}
    }

    override func didReceiveMemoryWarning() {
        super.didReceiveMemoryWarning()
        // Dispose of any resources that can be recreated.
    }
}

extension CustomizePaymentsPageViewController: UIPageViewControllerDataSource {
	func pageViewController(pageViewController: UIPageViewController,
	                        viewControllerBeforeViewController viewController: UIViewController) -> UIViewController? {
		guard let viewControllerIndex = orderedViewControllers.indexOf(viewController) else {
			return nil
		}
		
		let previousIndex = viewControllerIndex - 1
		
		guard previousIndex >= 0 else {
			return nil
		}
		
		guard orderedViewControllers.count > previousIndex else {
			return nil
		}
		
		return orderedViewControllers[previousIndex]
	}
	
	func pageViewController(pageViewController: UIPageViewController,
	                        viewControllerAfterViewController viewController: UIViewController) -> UIViewController? {
		guard let viewControllerIndex = orderedViewControllers.indexOf(viewController) else {
			return nil
		}
		
		let nextIndex = viewControllerIndex + 1
		let orderedViewControllersCount = orderedViewControllers.count
		
		guard orderedViewControllersCount != nextIndex else {
			return nil
		}
		
		guard orderedViewControllersCount > nextIndex else {
			return nil
		}
		
		return orderedViewControllers[nextIndex]
	}
	
}