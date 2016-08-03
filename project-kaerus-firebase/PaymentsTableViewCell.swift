//
//  PaymentsTableViewCell.swift
//  
//
//  Created by Brandon Chen on 8/3/16.
//
//

import UIKit

class PaymentsTableViewCell: UITableViewCell {

	@IBOutlet weak var profilePic: UIImageView!
	@IBOutlet weak var nameLabel: UILabel!
	@IBOutlet weak var totalBalance: UILabel!
	@IBOutlet weak var owedBalance: UILabel!
	
    override func awakeFromNib() {
        super.awakeFromNib()
        // Initialization code
    }

    override func setSelected(selected: Bool, animated: Bool) {
        super.setSelected(selected, animated: animated)

        // Configure the view for the selected state
    }
}
