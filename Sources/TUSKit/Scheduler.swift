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
    private var runningTasks = [WorkTask]()
    weak var delegate: SchedulerDelegate?
    
    var nrOfRunningTasks: Int { runningTasks.count }
    var nrOfPendingTasks: Int { tasks.count }
    
    let queue = DispatchQueue(label: "com.TUSKit.Scheduler") // Tasks happen on background

    // We limit the number of concurrent tasks.
    // Note that a GroupedTask can still spawn its own threads.
    static let maxConcurrentActions = 5
    let semaphore = DispatchSemaphore(value: maxConcurrentActions)
    
    init() {}
    
    /// A grouped task counts as a single unit that will succeed or fail as a whole.
    /// Adding these workTasks as a group, means that they all have to succeed together.
    /// - Parameter workTasks: An array of `WorkTask` elements.
    func addGroupedTasks(workTasks: [WorkTask]) {
//        let groupedTask = GroupedTask(tasks: workTasks, queue: queue)
//        self.tasks.append(groupedTask)
        self.tasks.append(contentsOf: workTasks)
        checkNextTask()
    }
    
    func addTask(workTask: WorkTask) {
        self.tasks.append(workTask)
        checkNextTask()
    }

    // TODO: Call clean up on all related tasks
    private func checkNextTask() {
        queue.async {  [unowned self] in
            guard !tasks.isEmpty else { return }
            self.semaphore.wait()
            let task = self.tasks.removeFirst()
            self.runningTasks.append(task)
            self.delegate?.didStartTask(task: task, scheduler: self)
            
            task.run { [unowned self] newTasks in
                self.semaphore.signal()
                // // Make sure tasks are updated atomically
                queue.async {
                    self.tasks.append(contentsOf: newTasks)
                    if let index = self.runningTasks.firstIndex(where: { $0 === task }) {
                        print("Index is \(index) tasks count \(self.runningTasks.count)")
                        // TODO: Crash
                        self.runningTasks.remove(at: index)
                    } else {
                        assertionFailure("Currently finished task does not have an index in running tasks")
                    }
                    self.checkNextTask()
                    self.delegate?.didFinishTask(task: task, scheduler: self)
                }
                
                
            }
            
        }
    }
    
}

/// A WorkTask is run by the scheduler
/// Once a WorkTask is finished. It can spawn new tasks that need to be run.
/// E.g. If a task is to upload a file, then it can spawn into tasks to cut up the file first. Which can then cut up into a task to upload, which can then add a task to delete the files.
protocol WorkTask: AnyObject {
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
    let queue: DispatchQueue
    
    init(tasks: [WorkTask], queue: DispatchQueue) {
        self.tasks = tasks
        self.queue = queue
    }
    
    func run(completed: @escaping TaskCompletion) {
        print("---- RUNNING GROUPED TASK ---")
        
        // Idea: Give tasks back to Scheduler, so that the GroupTask cannot circumvent the max concurrent tasks property.
        for task in tasks {
            self.group.enter()
            queue.async { [unowned self] in
                
                print("Running task \(task)")
                task.run { [unowned self] _ in
                    self.group.leave()
                }
            }

        }
        
        group.notify(queue: DispatchQueue.global()) {
            print("Grouped task finished")
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

