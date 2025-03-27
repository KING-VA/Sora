//
//  DropManager.swift
//  Sora
//
//  Created by Francesco on 25/01/25.
//

import Drops
import UIKit

class DropManager {
    static let shared = DropManager()
    
    private init() {}
    
    #if !os(tvOS)
    func showDrop(title: String, subtitle: String, duration: TimeInterval, icon: UIImage?) {
        let position: Drop.Position = .top
        
        let drop = Drop(
            title: title,
            subtitle: subtitle,
            icon: icon,
            position: position,
            duration: .seconds(duration)
        )
        Drops.show(drop)
    }
    #else
    func showDrop(title: String, subtitle: String, duration: TimeInterval, icon: UIImage?) {
        Logger.shared.log("Drops are not supported on tvOS")
    }
    #endif
}
