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
	@IBOutlet weak var requestButton: UIButton!
	
    override func awakeFromNib() {
        super.awakeFromNib()
        // Initialization code
    }

    override func setSelected(selected: Bool, animated: Bool) {
        super.setSelected(selected, animated: animated)

        // Configure the view for the selected state
    }

}
