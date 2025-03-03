//
//  Scheduler.swift
//  
//
//  Created by Tjeerd in ‘t Veen on 13/09/2021.
//

import Foundation

typealias TaskCompletion = (Result<[ScheduledTask], Error>) -> ()

protocol SchedulerDelegate: AnyObject {
    func didStartTask(task: ScheduledTask, scheduler: Scheduler)
    func didFinishTask(task: ScheduledTask, scheduler: Scheduler)
    func onError(error: Error, task: ScheduledTask, scheduler: Scheduler)
}

/// A Task is run by the scheduler
/// Once a Task is finished. It can spawn new tasks that need to be run.
/// E.g. If a task is to upload a file, then it can spawn into tasks to cut up the file first. Which can then cut up into a task to upload, which can then add a task to delete the files.
protocol ScheduledTask: AnyObject {
    func run(completed: @escaping TaskCompletion)
    func cancel()
}

/// A scheduler is responsible for processing tasks
/// It keeps track of related tasks, adds limiter capabilities (e.g. only process x amount of tasks) and concurrency.
/// Keeps track of related tasks and their errors.
final class Scheduler {

    private var pendingTasks = [ScheduledTask]()
    private var runningTasks = [ScheduledTask]()
    weak var delegate: SchedulerDelegate?
    
    var allTasks: [ScheduledTask] {
        queue.sync {
            runningTasks + pendingTasks
        }
    }
    
    // Tasks are processed in background
    let queue = DispatchQueue(label: "com.TUSKit.Scheduler")

    /// Add multiple tasks. Note that these are independent tasks.
    /// - Parameter tasks: The tasks to add
    func addTasks(tasks: [ScheduledTask]) {
        queue.async {
            guard !tasks.isEmpty else { return }
            self.pendingTasks.append(contentsOf: tasks)
            self.checkProcessNextTask()
        }
    }
        
    func addTask(task: ScheduledTask) {
        queue.async {
            self.pendingTasks.append(task)
            self.checkProcessNextTask()
        }
    }
    
    func cancelAll() {
        queue.async {
            self.pendingTasks = []
            self.runningTasks.forEach { $0.cancel() }
            self.runningTasks = []
        }
    }
    
    func cancelTask(by id: UUID) {
        queue.async {
            self.pendingTasks.removeAll { task in
                guard let idTask = task as? IdentifiableTask, idTask.id == id else {
                    return false
                }
                idTask.cancel()
                return true
            }
            self.runningTasks.removeAll { task in
                guard let idTask = task as? IdentifiableTask, idTask.id == id else {
                    return false
                }
                idTask.cancel()
                return true
            }
        }
    }

    func cancelTasks(_ tasksToCancel: [ScheduledTask]) {
        queue.async {
            tasksToCancel.forEach { taskToCancel in
                if let pendingTaskIndex = self.pendingTasks.firstIndex(where: { pendingTask in
                    pendingTask === taskToCancel
                }) {
                    let pendingTask = self.pendingTasks[pendingTaskIndex]
                    pendingTask.cancel()
                    self.pendingTasks.remove(at: pendingTaskIndex)
                }

                if let runningTaskIndex = self.runningTasks.firstIndex(where: { runningTask in
                    runningTask === taskToCancel
                }) {
                    let runningTask = self.runningTasks[runningTaskIndex]
                    runningTask.cancel()
                    self.runningTasks.remove(at: runningTaskIndex)
                }
            }
        }
    }

    private func checkProcessNextTask() {
        queue.async { [weak self] in
            guard let self = self else { return }
            guard !self.pendingTasks.isEmpty else { return }
            
            guard let task = self.extractFirstTask() else {
                assertionFailure("Could not get a new task, despite tasks being filled \(self.pendingTasks)")
                return
            }
            
            self.runningTasks.append(task)
            self.delegate?.didStartTask(task: task, scheduler: self)
            
            task.run { [weak self] result in
                guard let self = self else { return }
                // // Make sure tasks are updated atomically
                self.queue.async {
                    if let index = self.runningTasks.firstIndex(where: { $0 === task }) {
                        self.runningTasks.remove(at: index)
                    } else {
                        // Stray tasks might be canceled meanwhile.
                    }
                    
                    switch result {
                    case .success(let newTasks):
                        if !newTasks.isEmpty {
                            self.pendingTasks = newTasks + self.pendingTasks // If there are new tasks, perform them first. E.g. After creation of a file, start uploading.
                        }
                        self.delegate?.didFinishTask(task: task, scheduler: self)
                    case .failure(let error):
                        self.delegate?.onError(error: error, task: task, scheduler: self)
                    }
                    self.checkProcessNextTask()
                }
            }
        }
    }    
    
    /// Get first available task, removes it from current tasks
    /// - Returns: First next task, or nil if tasks are empty
    private func extractFirstTask() -> ScheduledTask? {
        guard !pendingTasks.isEmpty else { return nil }
        return pendingTasks.removeFirst()
    }
    
}
