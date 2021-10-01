//
//  Scheduler.swift
//  
//
//  Created by Tjeerd in ‘t Veen on 13/09/2021.
//

import Foundation

typealias TaskCompletion = (Result<[Task], Error>) -> ()

protocol SchedulerDelegate: AnyObject {
    func didStartTask(task: Task, scheduler: Scheduler)
    func didFinishTask(task: Task, scheduler: Scheduler)
    func onError(error: Error, task: Task, scheduler: Scheduler)
}

/// A scheduler is responsible for processing tasks
/// It keeps track of related tasks, adds limiter capabilities (e.g. only process x amount of tasks) and concurrency.
/// Keeps track of related tasks and their errors.
final class Scheduler {

    private var pendingTasks = [Task]()
    private var runningTasks = [Task]()
    weak var delegate: SchedulerDelegate?
    
    var allTasks: [Task] { runningTasks + pendingTasks }
    
    // Tasks are processed in background
    let queue = DispatchQueue(label: "com.TUSKit.Scheduler")

    // We limit the number of concurrent tasks. E.g. iOS can handle 5 concurrent uploads.
    static let maxConcurrentActions = 5
    let semaphore = DispatchSemaphore(value: maxConcurrentActions)
    
    init() {}
    
    /// Add multiple tasks. Note that these are independent tasks. If you want multiple tasks that are related in one way or another, use addGroupedTasks
    /// - Parameter tasks: The tasks to add
    func addTasks(tasks: [Task]) {
        guard !tasks.isEmpty else { return }
        queue.async {
            self.pendingTasks.append(contentsOf: tasks)
        }
        checkProcessNextTask()
    }
        
    func addTask(task: Task) {
        queue.async {
            self.pendingTasks.append(task)
        }
        checkProcessNextTask()
    }
    
    func cancelAll() {
        self.pendingTasks = []
        self.runningTasks.forEach { $0.cancel() }
    }

    private func checkProcessNextTask() {
        queue.async { [unowned self] in
            guard !pendingTasks.isEmpty else { return }
            
            guard let task = extractFirstTask() else {
                assertionFailure("Could not get a new task, despite tasks being filled \(pendingTasks)")
                return
            }
            
            self.semaphore.wait()
            
            self.runningTasks.append(task)
            self.delegate?.didStartTask(task: task, scheduler: self)
            
            task.run { [unowned self] result in
                self.semaphore.signal()
                // // Make sure tasks are updated atomically
                queue.async {
                    if let index = self.runningTasks.firstIndex(where: { $0 === task }) {
                        self.runningTasks.remove(at: index)
                    } else {
                        assertionFailure("Currently finished task does not have an index in running tasks")
                    }
                    
                    switch result {
                    case .success(let newTasks):
                        if !newTasks.isEmpty {
                            self.pendingTasks = newTasks + self.pendingTasks // If there are new tasks, perform them first. E.g. After creation of a file, start uploading.
                        }
                        delegate?.didFinishTask(task: task, scheduler: self)
                    case .failure(let error):
                        delegate?.onError(error: error, task: task, scheduler: self)
                    }
                    self.checkProcessNextTask()
                }
                    
            }
            
        }
    }
    
    /// Get first available task, removes it from current tasks
    /// - Returns: First next task, or nil if tasks are empty
    private func extractFirstTask() -> Task? {
        guard !pendingTasks.isEmpty else { return nil }
        return pendingTasks.removeFirst()
    }
    
}

/// A Task is run by the scheduler
/// Once a Task is finished. It can spawn new tasks that need to be run.
/// E.g. If a task is to upload a file, then it can spawn into tasks to cut up the file first. Which can then cut up into a task to upload, which can then add a task to delete the files.
protocol Task: AnyObject {
    func run(completed: @escaping TaskCompletion)
    func cancel()
}

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
