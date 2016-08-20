//
//  CAGradientLayerExtension.swift
//  project-kaerus-firebase
//
//  Created by Brandon Chen on 8/19/16.
//  Copyright © 2016 Brandon Chen. All rights reserved.
//

import UIKit

extension CAGradientLayer {
	class func gradientLayerForBounds(bounds: CGRect) -> CAGradientLayer {
		let layer = CAGradientLayer()
		layer.frame = bounds
		layer.colors = [UIColor.redColor().CGColor, UIColor.blueColor().CGColor]
		return layer
	}
}