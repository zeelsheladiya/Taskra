package model

import "core:encoding/json"
import "core:os"
import "core:fmt"

DATA_FILE :: "tasks.json"

save_tasks :: proc(list: ^TaskList) -> bool {
    // Marshal the task list to JSON
    data, err := json.marshal(list.tasks, {pretty=true})
    if err != nil {
        fmt.println("Error marshaling tasks:", err)
        return false
    }
    defer delete(data)

    success := os.write_entire_file(DATA_FILE, data)
    if !success {
        fmt.println("Error writing to file:", DATA_FILE)
        return false
    }
    
    return true
}

load_tasks :: proc(list: ^TaskList) {
    data, success := os.read_entire_file(DATA_FILE)
    if !success {
        // File might not exist yet, which is fine
        return
    }
    defer delete(data)

    err := json.unmarshal(data, &list.tasks)
    if err != nil {
        fmt.println("Error unmarshaling tasks:", err)
        return
    }

    // Recalculate next_id to ensure uniqueness after load
    max_id: u64 = 0
    for t in list.tasks {
        if t.id > max_id {
            max_id = t.id
        }
    }
    list.next_id = max_id + 1
}
