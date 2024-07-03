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
protocol ScheduledTask: Actor {
    func run() async throws -> [ScheduledTask]
    func cancel()
}

/// A scheduler is responsible for processing tasks
/// It keeps track of related tasks, adds limiter capabilities (e.g. only process x amount of tasks) and concurrency.
/// Keeps track of related tasks and their errors.
final actor Scheduler {

    private var pendingTasks = [ScheduledTask]()
    private var runningTasks = [ScheduledTask]()
    nonisolated(unsafe) weak var delegate: SchedulerDelegate?
    
    var allTasks: [ScheduledTask] {
        runningTasks + pendingTasks
    }

    /// Add multiple tasks. Note that these are independent tasks.
    /// - Parameter tasks: The tasks to add
    func addTasks(tasks: [ScheduledTask]) async {
        guard !tasks.isEmpty else { return }
        pendingTasks.append(contentsOf: tasks)
        await checkProcessNextTask()
    }
        
    func addTask(task: ScheduledTask) async {
        pendingTasks.append(task)
        await checkProcessNextTask()
    }
    
    func cancelAll() {
        self.pendingTasks = []
        self.runningTasks.forEach { runningTask in
            Task {
                await runningTask.cancel()
            }
        }
        self.runningTasks = []
    }
    
    func cancelTasks(_ tasksToCancel: [ScheduledTask]) {
        tasksToCancel.forEach { taskToCancel in
            Task {
                if let pendingTaskIndex = self.pendingTasks.firstIndex(where: { pendingTask in
                    pendingTask === taskToCancel
                }) {
                    let pendingTask = self.pendingTasks[pendingTaskIndex]
                    await pendingTask.cancel()
                    self.pendingTasks.remove(at: pendingTaskIndex)
                }
                
                if let runningTaskIndex = self.runningTasks.firstIndex(where: { runningTask in
                    runningTask === taskToCancel
                }) {
                    let runningTask = self.runningTasks[runningTaskIndex]
                    await runningTask.cancel()
                    self.runningTasks.remove(at: runningTaskIndex)
                }
            }
        }
    }

    private func checkProcessNextTask() async {
        guard !pendingTasks.isEmpty else { return }
        
        guard let task = self.extractFirstTask() else {
            assertionFailure("Could not get a new task, despite tasks being filled \(self.pendingTasks)")
            return
        }
        
        self.runningTasks.append(task)
        self.delegate?.didStartTask(task: task, scheduler: self)
        
        do {
            let newTasks = try await task.run()
            if let index = runningTasks.firstIndex(where: { $0 === task }) {
                self.runningTasks.remove(at: index)
            } else {
                // Stray tasks might be canceled meanwhile.
            }
            
            if !newTasks.isEmpty {
                self.pendingTasks = newTasks + self.pendingTasks // If there are new tasks, perform them first. E.g. After creation of a file, start uploading.
            }
            self.delegate?.didFinishTask(task: task, scheduler: self)
        } catch {
            self.delegate?.onError(error: error, task: task, scheduler: self)
        }
        
        await checkProcessNextTask()
    }
    
    /// Get first available task, removes it from current tasks
    /// - Returns: First next task, or nil if tasks are empty
    private func extractFirstTask() -> ScheduledTask? {
        guard !pendingTasks.isEmpty else { return nil }
        return pendingTasks.removeFirst()
    }
    
}
