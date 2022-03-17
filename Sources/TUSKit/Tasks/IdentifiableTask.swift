//
//  IdentifiableTask.swift
//  
//
//  Created by Elvirion Antersijn on 26/02/2022.
//

import Foundation

protocol IdentifiableTask: ScheduledTask {
    var id: UUID { get }
}
