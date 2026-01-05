//
//  SleepSegmentEntity.swift
//  CalmTrade
//
//  Created by Anas Parekh on 17/11/25.
//


import Foundation
import CoreData

@objc(SleepSegmentEntity)
public class SleepSegmentEntity: NSManagedObject {}

extension SleepSegmentEntity {
    @nonobjc public class func fetchRequest() -> NSFetchRequest<SleepSegmentEntity> {
        NSFetchRequest(entityName: "SleepSegmentEntity")
    }

    @NSManaged public var startDate: Date
    @NSManaged public var endDate: Date
    @NSManaged public var stageRaw: Int16
    @NSManaged public var sourceRaw: Int16
    @NSManaged public var sleepDayStart: Date
}
