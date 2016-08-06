//
//  UIImageExtension.swift
//  project-kaerus-firebase
//
//  Created by Brandon Chen on 8/4/16.
//  Copyright © 2016 Brandon Chen. All rights reserved.
//

import Foundation
import UIKit

extension UIImage {
	var circle: UIImage? {
		let square = CGSize(width: min(size.width, size.height), height: min(size.width, size.height))
		let imageView = UIImageView(frame: CGRect(origin: CGPoint(x: 0, y: 0), size: square))
		imageView.contentMode = .ScaleAspectFill
		imageView.image = self
		imageView.layer.cornerRadius = square.width/2
		imageView.layer.masksToBounds = true
		UIGraphicsBeginImageContextWithOptions(imageView.bounds.size, false, scale)
		guard let context = UIGraphicsGetCurrentContext() else { return nil }
		imageView.layer.renderInContext(context)
		let result = UIGraphicsGetImageFromCurrentImageContext()
		UIGraphicsEndImageContext()
		return result
	}
}