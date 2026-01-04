
package main

import rl "vendor:raylib"
import "core:fmt"
import "model"
import "utils"
import "ui"
import "core:strings"

App :: struct {
    task_list: model.TaskList,
    should_close: bool,
    
    // UI State
    active_filter: model.TaskFilter,
    
    // Input buffers
    new_task_input: [256]byte,
    new_task_input_len: int,
    new_task_cursor_index: int,
    new_task_selection_anchor: int,
    new_task_scroll_offset: f32,
    
    // Timers
    input_repeat_timer: f32,
    nav_repeat_timer: f32,

    is_entering_task: bool,
    new_task_priority: model.Priority,
    
    // Scrolling
    scroll_offset: f32,
}

init_app :: proc() -> App {
    rl.SetConfigFlags({.WINDOW_RESIZABLE, .VSYNC_HINT})
    rl.InitWindow(1280, 720, "Taskra")
    rl.SetExitKey(.KEY_NULL)
    
    utils.init_theme(true)
    utils.init_resources()

    app := App{
        task_list = model.init_task_list(),
        should_close = false,
        active_filter = .All,
        new_task_priority = .Low,
        new_task_cursor_index = 0,
        new_task_selection_anchor = -1,
        new_task_scroll_offset = 0,
        input_repeat_timer = 0,
        nav_repeat_timer = 0,
    }

    model.load_tasks(&app.task_list)
    return app
}

run_app :: proc(app: ^App) {
    for !rl.WindowShouldClose() {
        layout := ui.calculate_layout()
    
        ui.process_input(layout, &app.task_list, &app.active_filter, &app.is_entering_task, &app.new_task_input, &app.new_task_input_len, &app.scroll_offset)

        rl.BeginDrawing()
        rl.ClearBackground(utils.current_theme.background)
        
        ui.draw_ui(layout, utils.current_theme, app.task_list, app.active_filter, app.scroll_offset)

        if app.is_entering_task {
            // Overlay
            rl.DrawRectangle(0, 0, i32(layout.screen_width), i32(layout.screen_height), rl.Color{0, 0, 0, 200})
            
            // Input Box
            w: f32 = 500
            h: f32 = 200
            center_x := i32(layout.screen_width/2 - w/2)
            center_y := i32(layout.screen_height/2 - h/2)
            
            rl.DrawRectangle(center_x, center_y, i32(w), i32(h), utils.current_theme.background)
            rl.DrawRectangleLines(center_x, center_y, i32(w), i32(h), utils.current_theme.accent)
            
            ui.draw_text_custom("New Task:", i32(center_x + 10), i32(center_y + 10), 20, utils.current_theme.text_secondary)
            
            text_area_y := i32(center_y + 40)
            text_area_h := i32(h) - 100
            
            rl.BeginScissorMode(center_x + 10, text_area_y, i32(w) - 20, text_area_h)
                input_str := string(app.new_task_input[:app.new_task_input_len])
                
                cx, cy := ui.draw_text_wrapped(input_str, i32(center_x + 10), text_area_y, w - 20, 20, utils.current_theme.text_primary, app.new_task_cursor_index, app.new_task_selection_anchor, app.new_task_scroll_offset)
                
                // Auto-Scroll Logic
                top_y := text_area_y
                bottom_y := text_area_y + text_area_h
                
                if cy > bottom_y - 25 {
                    diff := (bottom_y - 25) - cy
                    app.new_task_scroll_offset += f32(diff)
                }
                if cy < top_y {
                    diff := top_y - cy
                    app.new_task_scroll_offset += f32(diff)
                }
                
                if app.new_task_scroll_offset > 0 {
                    app.new_task_scroll_offset = 0
                }
                
                 if (int(rl.GetTime() * 2) % 2) == 0 {
                    rl.DrawRectangle(cx, cy, 2, 20, utils.current_theme.accent)
                }
            rl.EndScissorMode()
            
            ui.draw_text_custom("Press ENTER to Save, ESC to Cancel", i32(center_x + 10), i32(center_y + i32(h) - 30), 10, utils.current_theme.text_secondary)

            // Priority Selection
            p_y := center_y + i32(h) - 60
            p_start_x := center_x + 10
            
            priorities := []model.Priority{.Low, .Medium, .High}
            colors := []rl.Color{utils.current_theme.priority_low, utils.current_theme.priority_medium, utils.current_theme.priority_high}
            labels := []string{"Low", "Med", "High"}
            
            for p, i in priorities {
                rect := rl.Rectangle{f32(p_start_x), f32(p_y), 60, 25}
                if app.new_task_priority == p {
                     rl.DrawRectangleRounded(rl.Rectangle{rect.x-2, rect.y-2, rect.width+4, rect.height+4}, 0.5, 4, utils.current_theme.text_primary)
                }
                rl.DrawRectangleRounded(rect, 0.4, 4, colors[i])
                ui.draw_text_custom(labels[i], i32(rect.x + 10), i32(rect.y + 5), 10, rl.Color{0,0,0,200})
                
                 if rl.IsMouseButtonPressed(.LEFT) {
                    if rl.CheckCollisionPointRec(rl.GetMousePosition(), rect) {
                        app.new_task_priority = p
                    }
                }
                p_start_x += 70
            }

            // --- INPUT HANDLING ---
            
            // Common Modifiers
            is_shift := rl.IsKeyDown(.LEFT_SHIFT) || rl.IsKeyDown(.RIGHT_SHIFT)
            is_cmd := rl.IsKeyDown(.LEFT_SUPER) || rl.IsKeyDown(.RIGHT_SUPER) || rl.IsKeyDown(.LEFT_CONTROL) || rl.IsKeyDown(.RIGHT_CONTROL)

            // 1. Navigation (Arrows with Repeat)
            nav_key_pressed := false
            if rl.IsKeyDown(.LEFT) || rl.IsKeyDown(.RIGHT) {
                app.nav_repeat_timer += rl.GetFrameTime()
                
                is_initial := app.nav_repeat_timer > 0.4 && app.nav_repeat_timer < 0.45
                is_repeat := app.nav_repeat_timer > 0.45 
                
                should_move := false
                if rl.IsKeyPressed(.LEFT) || rl.IsKeyPressed(.RIGHT) {
                    should_move = true
                    app.nav_repeat_timer = 0 // Reset
                } else if is_repeat {
                    // Accumulate repeat
                   if app.nav_repeat_timer > 0.05 + 0.4 {
                       app.nav_repeat_timer = 0.4
                       should_move = true
                   }
                }
                
                if should_move {
                     if rl.IsKeyDown(.LEFT) {
                        // Selection Logic
                        if is_shift {
                            if app.new_task_selection_anchor == -1 {
                                app.new_task_selection_anchor = app.new_task_cursor_index
                            }
                        } else {
                            app.new_task_selection_anchor = -1
                        }
                        
                        if app.new_task_cursor_index > 0 {
                            app.new_task_cursor_index -= 1
                        }
                     }
                     if rl.IsKeyDown(.RIGHT) {
                        if is_shift {
                            if app.new_task_selection_anchor == -1 {
                                app.new_task_selection_anchor = app.new_task_cursor_index
                            }
                        } else {
                            app.new_task_selection_anchor = -1
                        }
                        
                        if app.new_task_cursor_index < app.new_task_input_len {
                            app.new_task_cursor_index += 1
                        }
                     }
                }
            } else {
                app.nav_repeat_timer = 0
            }
            
            // 2. Clipboard Shortcuts
            // Select All
            if is_cmd && rl.IsKeyPressed(.A) {
                app.new_task_selection_anchor = 0
                app.new_task_cursor_index = app.new_task_input_len
            }
            
            // Copy
            if is_cmd && rl.IsKeyPressed(.C) {
                if app.new_task_selection_anchor != -1 && app.new_task_selection_anchor != app.new_task_cursor_index {
                    start := min(app.new_task_cursor_index, app.new_task_selection_anchor)
                    end := max(app.new_task_cursor_index, app.new_task_selection_anchor)
                    text_slice := app.new_task_input[start:end]
                    text_str := string(text_slice)
                    rl.SetClipboardText(strings.clone_to_cstring(text_str, context.temp_allocator))
                }
            }

            // Paste
            if is_cmd && rl.IsKeyPressed(.V) {
                clip_txt := rl.GetClipboardText()
                if clip_txt != nil {
                    clip_str := string(clip_txt)
                    clip_len := len(clip_str)
                    
                    // Delete selection if exists
                    if app.new_task_selection_anchor != -1 && app.new_task_selection_anchor != app.new_task_cursor_index {
                         start := min(app.new_task_cursor_index, app.new_task_selection_anchor)
                         end := max(app.new_task_cursor_index, app.new_task_selection_anchor)
                         diff := end - start
                         
                         for i := start; i < app.new_task_input_len - diff; i += 1 {
                             app.new_task_input[i] = app.new_task_input[i+diff]
                         }
                         app.new_task_input_len -= diff
                         app.new_task_cursor_index = start
                         app.new_task_selection_anchor = -1
                    }
                    
                    if app.new_task_input_len + clip_len < 255 {
                         for i := app.new_task_input_len - 1; i >= app.new_task_cursor_index; i -= 1 {
                             app.new_task_input[i + clip_len] = app.new_task_input[i]
                         }
                         for i := 0; i < clip_len; i += 1 {
                             app.new_task_input[app.new_task_cursor_index + i] = clip_str[i]
                         }
                         app.new_task_input_len += clip_len
                         app.new_task_cursor_index += clip_len
                    }
                }
            }
            
            // Cut
            if is_cmd && rl.IsKeyPressed(.X) {
                 if app.new_task_selection_anchor != -1 && app.new_task_selection_anchor != app.new_task_cursor_index {
                    start := min(app.new_task_cursor_index, app.new_task_selection_anchor)
                    end := max(app.new_task_cursor_index, app.new_task_selection_anchor)
                    
                    text_slice := app.new_task_input[start:end]
                    text_str := string(text_slice)
                    rl.SetClipboardText(strings.clone_to_cstring(text_str, context.temp_allocator))
                    
                    // Delete
                     diff := end - start
                     for i := start; i < app.new_task_input_len - diff; i += 1 {
                         app.new_task_input[i] = app.new_task_input[i+diff]
                     }
                     app.new_task_input_len -= diff
                     app.new_task_cursor_index = start
                     app.new_task_selection_anchor = -1
                 }
            }

            // 3. Typing
            key := rl.GetCharPressed()
            for key > 0 {
                if key >= 32 && key <= 125 {
                    if app.new_task_input_len < 255 {
                        // Replace Selection
                        if app.new_task_selection_anchor != -1 && app.new_task_selection_anchor != app.new_task_cursor_index {
                             start := min(app.new_task_cursor_index, app.new_task_selection_anchor)
                             end := max(app.new_task_cursor_index, app.new_task_selection_anchor)
                             diff := end - start
                             
                             for i := start; i < app.new_task_input_len - diff; i += 1 {
                                 app.new_task_input[i] = app.new_task_input[i+diff]
                             }
                             app.new_task_input_len -= diff
                             app.new_task_cursor_index = start
                             app.new_task_selection_anchor = -1
                        }
                    
                        // Insert
                        for i := app.new_task_input_len; i > app.new_task_cursor_index; i -= 1 {
                             app.new_task_input[i] = app.new_task_input[i-1]
                        }
                        app.new_task_input[app.new_task_cursor_index] = byte(key)
                        app.new_task_input_len += 1
                        app.new_task_cursor_index += 1
                    }
                }
                key = rl.GetCharPressed()
            }
            
            // 4. Backspace (with Repeat)
            if rl.IsKeyDown(.BACKSPACE) {
                app.input_repeat_timer += rl.GetFrameTime()
                is_repeat := app.input_repeat_timer > 0.45
                
                should_delete := false
                if rl.IsKeyPressed(.BACKSPACE) {
                     should_delete = true
                     app.input_repeat_timer = 0
                } else if is_repeat {
                    if app.input_repeat_timer > 0.05 + 0.4 {
                        app.input_repeat_timer = 0.4
                        should_delete = true
                    }
                }
                
                if should_delete {
                     // Delete Selection
                     if app.new_task_selection_anchor != -1 && app.new_task_selection_anchor != app.new_task_cursor_index {
                         start := min(app.new_task_cursor_index, app.new_task_selection_anchor)
                         end := max(app.new_task_cursor_index, app.new_task_selection_anchor)
                         diff := end - start
                         
                         for i := start; i < app.new_task_input_len - diff; i += 1 {
                             app.new_task_input[i] = app.new_task_input[i+diff]
                         }
                         app.new_task_input_len -= diff
                         app.new_task_cursor_index = start
                         app.new_task_selection_anchor = -1
                     } else if app.new_task_cursor_index > 0 {
                        // Standard Backspace
                        target := app.new_task_cursor_index - 1
                        for i := target; i < app.new_task_input_len - 1; i += 1 {
                            app.new_task_input[i] = app.new_task_input[i+1]
                        }
                        app.new_task_input_len -= 1
                        app.new_task_cursor_index -= 1
                    }
                }
            } else {
                app.input_repeat_timer = 0
            }
            
            if rl.IsKeyPressed(.ENTER) {
                 model.add_task(&app.task_list, input_str, app.new_task_priority)
                 model.save_tasks(&app.task_list)
                 app.is_entering_task = false
                 app.new_task_input_len = 0
                 app.new_task_priority = .Low
                 app.new_task_cursor_index = 0
                 app.new_task_scroll_offset = 0
            }
            
            if rl.IsKeyPressed(.ESCAPE) {
                app.is_entering_task = false
            }
        }

        rl.EndDrawing()
    }
}

close_app :: proc(app: ^App) {
    model.save_tasks(&app.task_list)
    model.destroy_task_list(&app.task_list)
    utils.unload_resources()
    rl.CloseWindow()
}

cb_str :: proc(s: string) -> cstring {
    return strings.clone_to_cstring(s, context.temp_allocator)
}
