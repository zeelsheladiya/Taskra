package ui

import rl "vendor:raylib"
import "../model"
import "../utils"

process_input :: proc(layout: Layout, task_list: ^model.TaskList, active_filter: ^model.TaskFilter, is_entering: ^bool, new_task_input: ^[256]byte, new_task_len: ^int, scroll_offset: ^f32) {
    mouse_p := rl.GetMousePosition()
    
    // Scroll the list if the mouse is over the task area
    list_area := rl.Rectangle{0, layout.list_start_y, layout.screen_width, layout.screen_height - layout.list_start_y}
    if rl.CheckCollisionPointRec(mouse_p, list_area) {
        wheel := rl.GetMouseWheelMove()
        if wheel != 0 {
            scroll_offset^ += wheel * 20
            
            // Clamp
            visible_height := layout.screen_height - layout.list_start_y
            
            // Calculate Total Dynamic Height
            total_height: f32 = 0
            text_max_w := layout.task_width - 150
            
            for t in task_list.tasks {
                if model.should_show_task(t, active_filter^) {
                    text_h := measure_multiline_height(t.title, 20, text_max_w)
                    h := max(10 + text_h + 6 + 12 + 10, layout.task_height)
                    total_height += h + layout.task_spacing
                }
            }
            
            // Add some padding at bottom
            total_height += 100 
            
            max_scroll := total_height - visible_height
            if max_scroll < 0 { max_scroll = 0 }
            
            if scroll_offset^ > 0 { scroll_offset^ = 0 }
            if scroll_offset^ < -max_scroll { scroll_offset^ = -max_scroll }
        }
    }

    // Theme Toggle
    if rl.IsMouseButtonPressed(.LEFT) && rl.CheckCollisionPointRec(mouse_p, layout.theme_btn_rect) {
        utils.toggle_theme()
    }

    // Filter Tabs
    {
        x := layout.filter_start_x
        y := layout.filter_bar_y
        labels := []string{"ALL", "IN PROGRESS", "COMPLETED", "LOW", "MEDIUM", "HIGH"}
        filters := []model.TaskFilter{.All, .InProgress, .Completed, .Low, .Medium, .High}
        
        for label, i in labels {
            width := measure_text_custom(label, f32(layout.filter_font_size))
            rect := rl.Rectangle{x - 10, y - 5, width + 20, f32(layout.filter_font_size + 10)}
            
            if rl.IsMouseButtonPressed(.LEFT) && rl.CheckCollisionPointRec(mouse_p, rect) {
                active_filter^ = filters[i]
                return
            }
             
            x += width + layout.filter_spacing + 20
        }
    }
    
    // New Task Button
    if rl.IsMouseButtonPressed(.LEFT) && rl.CheckCollisionPointRec(mouse_p, layout.new_btn_rect) {
        is_entering^ = !is_entering^
    }
    
    // Process Task List Items (Clicks, Deletes, Toggles)
    if !is_entering^ {
        y_start := layout.list_start_y + scroll_offset^
        
        text_max_w := layout.task_width - 150

        for t in task_list.tasks {
            if !model.should_show_task(t, active_filter^) {
                continue
            }
            
            // Dynamic Height Calc
            text_h := measure_multiline_height(t.title, 20, text_max_w)
            task_h := max(10 + text_h + 6 + 12 + 10, layout.task_height)
            
            y := y_start
            rect := rl.Rectangle{layout.task_start_x, y, layout.task_width, task_h}
            
            // Optimization: Skip processing for items outside the visible viewport
            if y + task_h < layout.list_start_y { 
                 y_start += task_h + layout.task_spacing
                 continue 
            }
            if y > layout.screen_height { break }

            // Check Deletion (Right Side)
            del_size: f32 = 24
            del_rect := rl.Rectangle{rect.x + rect.width - 40, rect.y + (rect.height - del_size)/2, del_size, del_size}
            
            if rl.IsMouseButtonPressed(.LEFT) && rl.CheckCollisionPointRec(mouse_p, del_rect) {
                model.remove_task(task_list, t.id)
                model.save_tasks(task_list)
                return 
            }
            
            // Checkbox
            check_size: f32 = 20
            check_rect := rl.Rectangle{rect.x + 60 - 5, rect.y + (rect.height - check_size)/2 - 5, check_size + 10, check_size + 10}
             if rl.IsMouseButtonPressed(.LEFT) && rl.CheckCollisionPointRec(mouse_p, check_rect) {
                model.toggle_task(task_list, t.id)
                model.save_tasks(task_list)
                return
            }
            
            y_start += task_h + layout.task_spacing
        }
    }
}
