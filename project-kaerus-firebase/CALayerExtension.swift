//
//  CALayerExtension.swift
//  project-kaerus-firebase
//
//  Created by Brandon Chen on 8/7/16.
//  Copyright © 2016 Brandon Chen. All rights reserved.
//

import UIKit

extension CALayer {
	func addBorder(edge: UIRectEdge, color: UIColor, thickness: CGFloat) {
		let border = CALayer()
		switch edge {
			case UIRectEdge.Top:
				border.frame = CGRectMake(0, 0, CGRectGetWidth(self.frame), thickness)
			case UIRectEdge.Bottom:
				border.frame = CGRectMake(0, CGRectGetHeight(self.frame) - thickness, CGRectGetWidth(self.frame), thickness)
			case UIRectEdge.Left:
				border.frame = CGRectMake(0, 0, thickness, CGRectGetHeight(self.frame))
			case UIRectEdge.Right:
				border.frame = CGRectMake(CGRectGetWidth(self.frame) - thickness, 0, thickness, CGRectGetHeight(self.frame))
			default: break
		}
		border.backgroundColor = color.CGColor;
		self.addSublayer(border)
	}
}