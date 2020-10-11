//
//  PlaceholderImage.swift
//  F1TV
//
//  Created by Adam Bell on 10/10/20.
//

import Foundation
import UIKit

let placeholderImage = UIImage._placeholder

extension UIImage {

    class var placeholder: UIImage? {
        return placeholderImage
    }

    class var _placeholder: UIImage? {
        let bounds = CGRect(x: 0.0, y: 0.0, width: 1.0, height: 1.0)
        UIGraphicsBeginImageContextWithOptions(bounds.size, true, 1.0)
        let ctx = UIGraphicsGetCurrentContext()
        ctx?.setFillColor(UIColor.lightGray.cgColor)
        ctx?.fill(bounds)

        let placeholder = UIGraphicsGetImageFromCurrentImageContext()

        UIGraphicsEndImageContext()

        return placeholder
    }

}
