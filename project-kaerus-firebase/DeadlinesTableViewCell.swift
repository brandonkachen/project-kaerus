//
//  DeadlinesTableViewCell.swift
//  project-kaerus-firebase
//
//  Created by Brandon Chen on 7/20/16.
//  Copyright © 2016 Brandon Chen. All rights reserved.
//

import UIKit

class DeadlinesTableViewCell: UITableViewCell {
	@IBOutlet weak var deadlineText: UILabel!
	@IBOutlet weak var timeDueText: UILabel!

    override func awakeFromNib() {
        super.awakeFromNib()
        // Initialization code
    }

    override func setSelected(selected: Bool, animated: Bool) {
        super.setSelected(selected, animated: animated)

        // Configure the view for the selected state
    }
}
