//
//  Scheduler.swift
//  
//
//  Created by Tjeerd in ‘t Veen on 13/09/2021.
//

import Foundation

typealias TaskCompletion = ([WorkTask]) -> ()

protocol SchedulerDelegate: AnyObject {
    func didStartTask(task: WorkTask, scheduler: Scheduler)
    func didFinishTask(task: WorkTask, scheduler: Scheduler)
}

// Also filter by only upload tasks

/// A scheduler is responsible for running tasks
/// Keeps track of related tasks and their errors
/// Some tasks are for clean up, such as deleting files that aren't used anymore.
final class Scheduler {

    private var tasks = [WorkTask]()
    weak var delegate: SchedulerDelegate?
    
    init() {}
    
    /// A grouped task counts as a single unit that will succeed or fail as a whole.
    /// Adding these workTasks as a group, means that they all have to succeed together.
    /// - Parameter workTasks: An array of `WorkTask` elements.
    func addGroupedTasks(workTasks: [WorkTask]) {
        // TODO: Grouped tasks must all succeed or all fail
        // Use DispatchGroup, group.enter() group.leave() etc
        let groupedTask = GroupedTask(tasks: workTasks)
        self.tasks.append(groupedTask)
        checkNextTask()
    }
    
    func addTask(workTask: WorkTask) {
        self.tasks.append(workTask)
        checkNextTask()
    }
    
    private func checkNextTask() {
        guard !tasks.isEmpty else { return }
        let task = tasks.removeFirst()
        delegate?.didStartTask(task: task, scheduler: self)
        
        task.run { [weak self] newTasks in
            // TODO: Call clean up on all related tasks
            guard let self = self else { return }
            self.tasks.append(contentsOf: newTasks)
            self.checkNextTask()
            
            self.delegate?.didFinishTask(task: task, scheduler: self)
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

/// Treats multiple tasks as one.
private final class GroupedTask: WorkTask {
    
    let tasks: [WorkTask]
    let group = DispatchGroup()
    
    init(tasks: [WorkTask]) {
        self.tasks = tasks
    }
    
    func run(completed: @escaping TaskCompletion) {
        for task in tasks {
            group.enter()
            task.run { [unowned group] _ in
                group.leave()
            }
        }
        
        group.notify(queue: DispatchQueue.global()) {
            completed([])
        }

    }
    
    func cleanUp() {
        tasks.forEach { $0.cleanUp() }
    }
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

