//
//  SchedulerTests.swift
//  
//
//  Created by Elvirion Antersijn on 17/03/2022.
//

import XCTest
@testable import TUSKit

private actor TestTask: ScheduledTask {
    func run() async throws -> [any ScheduledTask] { return [] }
    func cancel() {}
}

final class SchedulerTests: XCTestCase {
    
    private let scheduler = Scheduler()

    func testAddTask() async {
        await scheduler.addTask(task: TestTask())
        let taskCount = await scheduler.allTasks.count
        XCTAssertEqual(taskCount, 1)
    }
    
    func testCancelTask() async {
        let taskToCancel = TestTask()
        await scheduler.addTask(task: taskToCancel)
        var taskCount = await scheduler.allTasks.count
        XCTAssertEqual(taskCount, 1)
        
        await scheduler.cancelTasks([taskToCancel])
        taskCount = await scheduler.allTasks.count
        XCTAssertEqual(taskCount, 0)
    }
   
}
