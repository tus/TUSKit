//
//  SchedulerTests.swift
//  
//
//  Created by Elvirion Antersijn on 17/03/2022.
//

import XCTest
@testable import TUSKit

private final class TestTask: ScheduledTask {
    func run(completed: @escaping TaskCompletion) {}
    func cancel() {}
}

final class SchedulerTests: XCTestCase {
    
    private let scheduler = Scheduler()

    func testAddTask() {
        scheduler.addTask(task: TestTask())
        XCTAssertEqual(scheduler.allTasks.count, 1)
    }
    
    func testCancelTask() {
        let taskToCancel = TestTask()
        scheduler.addTask(task: taskToCancel)
        XCTAssertEqual(scheduler.allTasks.count, 1)
        
        scheduler.cancelTasks([taskToCancel])
        XCTAssertEqual(scheduler.allTasks.count, 0)
    }
   
}
