//
//  Checkbox.swift
//  BFMadness
//
//  Created by David Brownstone on 1/11/16.
//  Copyright © 2016 Brownstone. All rights reserved.
//

import UIKit

let CheckboxStatusChangedNotification = "CheckboxStatusChangedNotification"

class Checkbox: UIButton {
    // Images
    let checkedImage = UIImage(named: "checked")! as UIImage
    let uncheckedImage = UIImage(named: "unchecked")! as UIImage
    
    // Bool property
    var isChecked: Bool = false    
    
    override func awakeFromNib() {
        self.addTarget(self, action: #selector(Checkbox.buttonClicked), for: UIControlEvents.touchUpInside)
        self.isChecked = false
    }
    
    func buttonClicked(_ sender: UIButton) {
        self.isSelected = !self.isSelected
        if sender == self {
            if isChecked == true {
                isChecked = false
                
                self.setBackgroundImage(uncheckedImage, for:UIControlState.selected.union(.highlighted))
//                self.setImage(uncheckedImage, for: UIControlState.selected.union(.highlighted))
            } else {
                isChecked = true
                self.setBackgroundImage(checkedImage, for: UIControlState.selected.union(.highlighted))
            }
            NotificationCenter.default.post(name: NSNotification.Name(rawValue: CheckboxStatusChangedNotification), object: sender)
        }
    }
    
    public func setValue(_ value:Bool) {
        if value == true {
            self.isSelected = true
            isChecked = true
            self.setBackgroundImage(checkedImage, for: UIControlState.selected.union(.highlighted))
        } else {
            self.isSelected = false
            isChecked = false
            self.setBackgroundImage(uncheckedImage, for: UIControlState.selected.union(.highlighted))
        }
    }
}
