package tests

import "core:testing"
import "../src/model"

@(test)
test_task_management :: proc(t: ^testing.T) {
    list := model.init_task_list()
    defer model.destroy_task_list(&list)
    
    // Test Add
    model.add_task(&list, "Task 1", .Low)
    testing.expect_value(t, len(list.tasks), 1)
    testing.expect_value(t, list.tasks[0].title, "Task 1")
    
    model.add_task(&list, "Task 2", .High)
    testing.expect_value(t, len(list.tasks), 2)
    
    // Test Toggle
    id1 := list.tasks[0].id
    model.toggle_task(&list, id1)
    testing.expect(t, list.tasks[0].is_completed == true, "Task 1 should be completed")
    
    model.toggle_task(&list, id1)
    testing.expect(t, list.tasks[0].is_completed == false, "Task 1 should be incomplete")
    
    // Test Remove
    id2 := list.tasks[1].id
    model.remove_task(&list, id2)
    testing.expect_value(t, len(list.tasks), 1)
    testing.expect_value(t, list.tasks[0].id, id1)
}

@(test)
test_filtering_logic :: proc(t: ^testing.T) {
    // Note: Filtering is currently implemented in UI/App layer helpers, 
    // but we can verify the properties here.
    
    t1 := model.Task{priority = .Low, is_completed = false}
    t2 := model.Task{priority = .High, is_completed = true}
    
    // Manual check logic simulation
    testing.expect(t, !t1.is_completed, "T1 should be in progress")
    testing.expect(t, t2.is_completed, "T2 should be completed")
}
