package model

import "core:time"
import "core:strings"

Priority :: enum {
	Low,
	Medium,
	High,
}

TaskFilter :: enum {
	All,
	InProgress,
	Completed,
	Low,
	Medium,
	High,
}

Task :: struct {
	id:           u64,
	title:        string,
	is_completed: bool,
	priority:     Priority,
	created_at:   time.Time,
}

// Global state or managing struct
TaskList :: struct {
	tasks:   [dynamic]Task,
	next_id: u64,
}

init_task_list :: proc() -> TaskList {
	return TaskList{
		tasks = make([dynamic]Task),
		next_id = 1,
	}
}

destroy_task_list :: proc(list: ^TaskList) {
	delete(list.tasks)
}

add_task :: proc(list: ^TaskList, title: string, priority: Priority) {
	t := Task{
		id = list.next_id,
		title = strings.clone(title),
		is_completed = false,
		priority = priority,
		created_at = time.now(),
	}
	append(&list.tasks, t)
	list.next_id += 1
}

remove_task :: proc(list: ^TaskList, id: u64) {
	index := -1
	for t, i in list.tasks {
		if t.id == id {
			index = i
			break
		}
	}
	if index != -1 {
		ordered_remove(&list.tasks, index)
	}
}

toggle_task :: proc(list: ^TaskList, id: u64) {
	for &t in list.tasks {
		if t.id == id {
			t.is_completed = !t.is_completed
			break
		}
	}
}

should_show_task :: proc(t: Task, filter: TaskFilter) -> bool {
    switch filter {
    case .All: return true
    case .InProgress: return !t.is_completed
    case .Completed: return t.is_completed
    case .Low: return t.priority == .Low
    case .Medium: return t.priority == .Medium
    case .High: return t.priority == .High
    }
    return true
}
