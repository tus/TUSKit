//
//  Scheduler.swift
//  
//
//  Created by Tjeerd in ‘t Veen on 13/09/2021.
//

import Foundation

typealias TaskCompletion = ([Task]) -> ()

protocol SchedulerDelegate: AnyObject {
    func didStartTask(task: Task, scheduler: Scheduler)
    func didFinishTask(task: Task, scheduler: Scheduler)
}

/// A scheduler is responsible for processing tasks
/// It keeps track of related tasks, adds limiter capabilities (e.g. only process x amount of tasks) and concurrency.
/// Keeps track of related tasks and their errors.
final class Scheduler {

    private var tasks = [[Task]]()
    private var runningTasks = [Task]()
    weak var delegate: SchedulerDelegate?
    
    var nrOfRunningTasks: Int { runningTasks.count }
    var nrOfPendingTasks: Int {
        var total = 0
        for group in tasks {
            total += group.count
        }
        return total
    }
    
    // Tasks are processed in background
    let queue = DispatchQueue(label: "com.TUSKit.Scheduler")

    // We limit the number of concurrent tasks. E.g. iOS can handle 5 concurrent uploads.
    static let maxConcurrentActions = 5
    let semaphore = DispatchSemaphore(value: maxConcurrentActions)
    
    init() {}
    
    /// A grouped task counts as a single unit that will succeed or fail as a whole.
    /// Adding these Tasks as a group, means that they all have to succeed together.
    /// - Parameter Tasks: An array of `Task` elements.
    func addGroupedTasks(tasks: [Task]) {
        self.tasks.append(tasks)
        checkProcessNextTask()
    }
    
    func addTask(Task: Task) {
        self.tasks.append([Task])
        checkProcessNextTask()
    }

    // TODO: Call clean up on all related tasks
    private func checkProcessNextTask() {
        queue.async { [unowned self] in
            guard !tasks.isEmpty else { return }
            
            guard let task = extractFirstTask() else {
                assertionFailure("Could not get a new task, despite tasks being filled \(tasks)")
                return
            }
            
            self.semaphore.wait()
            
            self.runningTasks.append(task)
            self.delegate?.didStartTask(task: task, scheduler: self)
            
            task.run { [unowned self] newTasks in
                self.semaphore.signal()
                // // Make sure tasks are updated atomically
                queue.async {
                    if !newTasks.isEmpty {
                        self.tasks.append(newTasks)
                    }
                    if let index = self.runningTasks.firstIndex(where: { $0 === task }) {
                        self.runningTasks.remove(at: index)
                    } else {
                        assertionFailure("Currently finished task does not have an index in running tasks")
                    }
                    self.checkProcessNextTask()
                    self.delegate?.didFinishTask(task: task, scheduler: self)
                }
                
            }
            
        }
    }
    
    /// Get first available task, removes it from current tasks
    /// - Returns: First next task, or nil if tasks are empty
    private func extractFirstTask() -> Task? {
        guard let task = tasks.firstNested else {
            return nil
        }
        
        self.tasks = self.tasks.filterNested { element in
            task === element
        }
        
        return task
    }
    
}

/// A Task is run by the scheduler
/// Once a Task is finished. It can spawn new tasks that need to be run.
/// E.g. If a task is to upload a file, then it can spawn into tasks to cut up the file first. Which can then cut up into a task to upload, which can then add a task to delete the files.
protocol Task: AnyObject {
    func run(completed: @escaping TaskCompletion)
    func cleanUp()
}

extension Task {
    func cleanUp() {}
}

/// Treats multiple tasks as one.
private final class GroupedTask: Task {
    
    let tasks: [Task]
    let group = DispatchGroup()
    let queue: DispatchQueue
    
    init(tasks: [Task], queue: DispatchQueue) {
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

/// A Task is a generic task. It wraps a closure as convenience to prevent creating a new type for each task.
/// Useful for smaller tasks. For big tasks, you can implement the `Task` protocol.
struct SyncTask: Task {
    
    let work: () -> [Task]
    init(work: @escaping () -> [Task]) {
        self.work = work
    }
    
    func run(completed: TaskCompletion) {
        let newTasks = self.work()
        completed(newTasks)
    }
}
*/


// Convenience extensions to help deal with nested arrays.
private extension Array where Element: Collection {
    
    var firstNested: Element.Element? {
        for col in self {
            for el in col {
                return el
            }
        }
        
        return nil
    }
    
    func filterNested(predicate: (Element.Element) -> Bool) -> [[Element.Element]] {
        var arr = [[Element.Element]]()
        
        for col in self {
            var newArr = [Element.Element]()
            for el in col {
                if !predicate(el) {
                    newArr.append(el)
                }
            }
            if !newArr.isEmpty {
                arr.append(newArr)
            }
        }
        
        return arr
    }
}
