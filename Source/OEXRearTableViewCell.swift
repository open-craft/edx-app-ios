//
//  OEXRearTableViewCell.swift
//  edX
//
//  Created by Jaime Ohm on 12/29/16.
//  Copyright © 2016 edX. All rights reserved.
//

import UIKit

class OEXRearTableViewCell : UITableViewCell {
    @IBOutlet var titleLabel: UILabel?
    required init?(coder aDecoder: NSCoder) {
        super.init(coder: aDecoder)
    }
    
    override func awakeFromNib() {
        super.awakeFromNib()
        backgroundColor = UIColor.whiteColor()
        titleLabel?.textColor = OEXStyles.sharedStyles().primaryBaseColor()
    }
}

class OEXRearTableViewNameCell : UITableViewCell {
    @IBOutlet var nameLabel: UILabel!
    @IBOutlet var usernameLabel: UILabel!
    @IBOutlet var avatarImageView: UIImageView!
    required init?(coder aDecoder: NSCoder) {
        super.init(coder: aDecoder)
    }
    
    override func awakeFromNib() {
        super.awakeFromNib()
        backgroundColor = OEXStyles.sharedStyles().primaryBaseColor()
        nameLabel.textColor = UIColor.whiteColor()
        usernameLabel.textColor = UIColor.whiteColor()
        avatarImageView.backgroundColor = OEXStyles.sharedStyles().primaryDarkColor()
    }
}
