//
//  Scheduler.swift
//  
//
//  Created by Tjeerd in ‘t Veen on 13/09/2021.
//

import Foundation




typealias TaskCompletion = ([WorkTask]) -> ()


// Also filter by only upload tasks

/// A scheduler is responsible for running tasks
/// Keeps track of related tasks and their errors
/// Some tasks are uploading. But some are for cutting up Data into smaller pieces.
/// Some tasks are for clean up, such as deleting files that aren't used anymore.
final class Scheduler {

    private var tasks = [WorkTask]()
    
    init() {}
    
    func addGroupedTasks(workTask: [WorkTask]) {
        // TODO: Grouped tasks must all succeed or all fail
        // Use DispatchGroup
    }
    
    func addTask(workTask: WorkTask) {
        self.tasks.append(workTask)
        checkNextTask()
    }
    
    private func checkNextTask() {
        guard !tasks.isEmpty else { return }
        let task = tasks.removeFirst()
            
        task.run { [weak self] newTasks in
            // TODO: Call clean up on all related tasks
            self?.tasks.append(contentsOf: newTasks)
            self?.checkNextTask()
        }
    }
    
}

/// A WorkTask is run by the scheduler
/// Once a WorkTask is finished. It can spawn new tasks that need to be run.
/// E.g. If a task is to upload a file, then it can spawn into tasks to cut up the file first. Which can then cut up into a task to upload, which can then add a task to delete the files.
protocol WorkTask {
    func run(completed: @escaping TaskCompletion)
    func cleanUp()
}

extension WorkTask {
    func cleanUp() {}
}
/*

/// A WorkTask is a generic task. It wraps a closure as convenience to prevent creating a new type for each task.
/// Useful for smaller tasks. For big tasks, you can implement the `WorkTask` protocol.
struct SyncTask: WorkTask {
    
    let work: () -> [WorkTask]
    init(work: @escaping () -> [WorkTask]) {
        self.work = work
    }
    
    func run(completed: TaskCompletion) {
        let newTasks = self.work()
        completed(newTasks)
    }
}
*/
