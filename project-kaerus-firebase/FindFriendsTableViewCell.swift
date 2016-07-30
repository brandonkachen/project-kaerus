//
//  FindFriendsTableViewCell.swift
//  
//
//  Created by Brandon Chen on 7/17/16.
//
//

import UIKit

class FindFriendsTableViewCell: UITableViewCell {

	@IBOutlet weak var profilePic: UIImageView!
	@IBOutlet weak var name: UILabel!
	@IBOutlet weak var partnerStatus: UILabel!
	@IBOutlet weak var requestButton: UIButton!
	@IBOutlet weak var acceptButton: UIButton!
	@IBOutlet weak var rejectButton: UIButton!
	
    override func awakeFromNib() {
        super.awakeFromNib()
        // Initialization code
		
		// round corners
		self.requestButton.layer.cornerRadius = 7
		self.acceptButton.layer.cornerRadius = 5
		self.rejectButton.layer.cornerRadius = 5
		
		// hide all buttons
		self.requestButton.hidden = true
		self.acceptButton.hidden = true
		self.rejectButton.hidden = true
	}

    override func setSelected(selected: Bool, animated: Bool) {
        super.setSelected(selected, animated: animated)

        // Configure the view for the selected state
		
		
    }

}
