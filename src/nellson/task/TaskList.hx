﻿/**
* @author Joshua Granick
* @version 0.1
*/


package nellson.task;


import nellson.utils.MessageLog;
import nme.events.Event;
import msignal.Signal;


class TaskList {
	
	private var completedTasks:Hash <Task>;
	private var pendingTasks:Array <Task>;
	public var completed:Signal0;
	
	public function new () {
		
		initialize ();
		
	}
	
	
	/**
	 * Add a new task to the pending tasks list
	 * @param	task		A new task
	 * @param	prerequisiteTasks		(Optional) An array of task objects or IDs which must be completed before running the task
	 * @param	autoComplete		(Optional) Determines whether to automatically mark tasks as complete after they are run. Does not affect tasks which use TaskList.handleEvent. Default is true.
	 */
	public function addTask (task:Task, prerequisiteTasks:Array <Dynamic> = null, autoComplete:Bool = true):Void {
		
		task.autoComplete = autoComplete;
		task.prerequisiteTasks = prerequisiteTasks;
		pendingTasks.push (task);
		processTasks ();
		
	}
	
	public function size():Int
	{
		return pendingTasks.length;
	}
	
	
	public function reset():Void
	{
		for (key in completedTasks.keys())
		{
			completedTasks.remove(key);
		}
		pendingTasks = [];
	}
	
	/**
	 * Marks a task as complete
	 * @param	reference		A task object or ID to mark as complete
	 */
	public function completeTask (reference:Dynamic):Void {
		
		var task:Task = qualifyReference (reference);
		
		if (task != null) {
			
			MessageLog.debug (this, "Completed task \"" + task.id + "\"");
			
			completedTasks.set (task.id, task);
			pendingTasks.remove (task);
			
			if (task.completeHandler != null) {
				
				task.completeHandler (task.result);
				
			}
			
			processTasks ();
			
		}
		
	}
	
	
	/**
	 * Creates an event handler in-place of TaskList.handleEvent
	 * @param	task		A task object to create a handler for
	 * @return		A custom event handler
	 */
	private function createEventHandler (task:Task, handledEvent:HandledEvent):Dynamic {
		
		var completeReference:Dynamic = completeTask;
		
		var eventHandler:Dynamic = function (event:Event = null):Void {
			
			if (event != null) {
				
				handledEvent.handler (event);
				
			} else {
				
				handledEvent.handler ();
				
			}
			
			if (task.autoComplete) {
				
				completeReference (task);
				
			}
			
		}
		
		return eventHandler;
		
	}
	
	
	/**
	 * Looks up a task by an ID reference to find a matching task object
	 * @param	id		An ID to search for
	 * @return		A task object or null if the task was not found
	 */
	private function getTaskByID (id:String):Task {
		
		var task:Task;
		
		for (task in pendingTasks) {
			
			if (task.id == id) {
				
				return task;
				
			}
			
		}
		
		if (completedTasks.exists (id)) {
			
			return completedTasks.get (id);
			
		}
		
		MessageLog.error (this, "Bad reference to task \"" + id + "\"");
		
		return null;
		
	}
	
	
	/**
	 * When autoComplete is true, the TaskList will mark the task as complete once it has been run. This works correctly for synchronous function calls, but may not work as expected 
	 * for asynchronous function calls, such as when you are loading a file. In these situations, you can wrap the completion event with TaskList.handleEvent to autoComplete in these
	 * situations.
	 * 
	 * For example, here is a basic synchronous function call:
	 * 
	 * new Task ("Say Hello", trace, [ "Hello!" ]);
	 * 
	 * Here is an example of an asynchronous function call:
	 * 
	 * new Task ("Load XML", loadXML, [ xmlPath, loadXML_onComplete ]);
	 * 
	 * While the synchronous call is finished once the target method has been called, the asynchronous call is still waiting for the file to load. Here is an example of the same task, using
	 * TaskList.handleEvent to wrap the complete handler:
	 * 
	 * new Task ("Load XML", loadXML, [ xmlPath, TaskList.handleEvent (loadXML_onComplete) ]);
	 * 
	 * That will properly cause the TaskList to wait before flagging the task as complete, until after the complete handler has been called.
	 */
	public static function handleEvent (handler:Dynamic):HandledEvent {
		
		return new HandledEvent (handler);
		
	}
	
	
	/**
	 * Initialize class values
	 */
	private function initialize ():Void {
		
		completedTasks = new Hash <Task> ();
		pendingTasks = new Array <Task> ();
		completed = new Signal0();
	}
	
	
	/**
	 * Check to see if a task object or task ID has been completed
	 * @param	reference		A task object or task ID to check
	 * @return		A boolean value representing whether the task has been completed
	 */
	public function isCompleted (reference:Dynamic):Bool {
		
		var task:Task = cast (qualifyReference (reference), Task);
		
		if (task != null && completedTasks.exists (task.id)) {
			return true;
		} else {
			return false;
		}
		
	}
	
	
	/**
	 * Check for any tasks which are ready to be run
	 */
	private function processTasks ():Void {
		
		if (pendingTasks.length > 0)
		{
			for (task in pendingTasks) {
				
				if (task.target != null && !task.run) {
					
					var taskReady:Bool = true;
					
					if (task.prerequisiteTasks != null) {
						
						for (reference in task.prerequisiteTasks) {
							
							var prerequisiteTask:Task = qualifyReference (reference);
							
							if (!completedTasks.exists (prerequisiteTask.id)) {
								
								taskReady = false;
								
							}
							
						}
						
					}
					
					if (taskReady) {
						
						runTask (task);
						
					}
					
				}
				
			}
		}
		else 
		{
			completed.dispatch();
		}
		
		
	}
	
	
	/**
	 * Determines if a reference is a task object or a task ID. If it is a task ID it is converted into the appropriate object.
	 * @param	reference		A task object or task ID
	 * @return		A task object or null if no matching task is found
	 */
	private function qualifyReference (reference:Dynamic):Task {
		
		var task:Task;
		
		if (Std.is (reference, Task)) {
			task = cast (reference, Task);
		} else {
			task = getTaskByID (cast (reference, String));
		}
		
		return task;
		
	}
	
	
	/**
	 * Runs a task and marks it as complete if autoComplete is true
	 * @param	reference		A task object or task ID
	 */
	private function runTask (reference:Dynamic):Void {
		
		var task:Task = qualifyReference (reference);
		
		if (task != null) {
			
			MessageLog.debug (this, "Running task \"" + task.id + "\"");
			
			task.run = true;
			
			var params:Array <Dynamic> = task.params;
			var handlingEvent:Bool = false;
			
			if (params != null) {
				for (i in 0...params.length) {
					if (Std.is (params[i], HandledEvent)) {
						params[i] = createEventHandler (task, params[i]);
						handlingEvent = true;
					}
				}
			}
			
			task.result = Reflect.callMethod (task.target, task.target, params);
			
			if (task.autoComplete && !handlingEvent) {
				completeTask (task);
			}
			
		}
		
	}
	
	
}




class HandledEvent {


public var handler:Dynamic;


public function new (handler:Dynamic) {
	
	this.handler = handler;
	
}


}