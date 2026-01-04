package ui

import rl "vendor:raylib"
import "../model"
import "../utils"
import "core:strings"

draw_ui :: proc(layout: Layout, theme: utils.Theme, task_list: model.TaskList, active_filter: model.TaskFilter, scroll_offset: f32) {
    // Header Title
    draw_text_custom("Your To Do", i32(layout.task_start_x), i32(layout.header_y), f32(layout.header_title_size), theme.text_primary)
    
    // Theme Toggle
    draw_theme_icon(theme, layout.theme_btn_rect)
    
    // New Task Button
    draw_new_task_button(theme, layout.new_btn_rect)
    
    // Filter Bar
    draw_filter_bar(layout, theme, active_filter)
    
    // Scissor Mode to clip the scrolling list area
    clip_y := i32(layout.list_start_y)
    clip_h := i32(layout.screen_height) - clip_y
    if clip_h > 0 {
        rl.BeginScissorMode(0, clip_y, i32(layout.screen_width), clip_h)
        draw_task_list(layout, theme, task_list, active_filter, scroll_offset)
        rl.EndScissorMode()
    }
}

draw_theme_icon :: proc(theme: utils.Theme, rect: rl.Rectangle) {
    // Button bg
    rl.DrawRectangleRounded(rect, 0.4, 4, rl.ColorAlpha(theme.text_secondary, 0.1))
    
    // Icon center
    cx := i32(rect.x + rect.width/2)
    cy := i32(rect.y + rect.height/2)
    
    is_dark := theme.background.r < 100
    
    if is_dark {
        // Draw Moon
        rl.DrawCircle(cx, cy, 10, theme.text_primary)
        rl.DrawCircle(cx + 4, cy - 4, 8, theme.background) 
        // Or simpler crescent
    } else {
        // Draw Sun
        rl.DrawCircle(cx, cy, 6, theme.text_primary)
        // Rays
        rl.DrawCircleLines(cx, cy, 11, theme.text_primary)
    }
}

draw_new_task_button :: proc(theme: utils.Theme, bounds: rl.Rectangle) {
    // Shadow/Depth
    shadow_rect := bounds
    shadow_rect.x += 2
    shadow_rect.y += 2
    rl.DrawRectangleRounded(shadow_rect, 0.3, 4, rl.Color{0,0,0, 50})

    rl.DrawRectangleRounded(bounds, 0.3, 4, theme.accent)
    
    text := "New Task"
    font_size: f32 = 20
    width := measure_text_custom(text, font_size)
    x := i32(bounds.x + (bounds.width/2) - width/2)
    y := i32(bounds.y + (bounds.height/2) - font_size/2)
    
    draw_text_custom(text, x, y, font_size, theme.background)
}

draw_filter_bar :: proc(layout: Layout, theme: utils.Theme, current_filter: model.TaskFilter) {
    x := layout.filter_start_x
    y := i32(layout.filter_bar_y)
    
    labels := []string{"ALL", "IN PROGRESS", "COMPLETED", "LOW", "MEDIUM", "HIGH"}
    filters := []model.TaskFilter{.All, .InProgress, .Completed, .Low, .Medium, .High}
    
    for label, i in labels {
        color := theme.text_secondary
        if filters[i] == current_filter {
            color = theme.text_primary
            // Draw Pill
            width := measure_text_custom(label, f32(layout.filter_font_size))
            rect := rl.Rectangle{x - 10, f32(y - 5), width + 20, f32(layout.filter_font_size + 10)}
            rl.DrawRectangleRounded(rect, 0.4, 4, theme.task_bg)
        }
        
        draw_text_custom(label, i32(x), y, f32(layout.filter_font_size), color)
        width := measure_text_custom(label, f32(layout.filter_font_size))
        x += f32(width) + layout.filter_spacing + 20
    }
}

draw_task_list :: proc(layout: Layout, theme: utils.Theme, list: model.TaskList, filter: model.TaskFilter, scroll_offset: f32) {
    y := layout.list_start_y + scroll_offset
    
    for t in list.tasks {
        if !model.should_show_task(t, filter) {
             continue
        }
        
        // Dynamic height calculation based on text wrapping
        // Base width calculation: Task width - padding (Left + Right icons/spacing)
        text_max_w := layout.task_width - 150
        text_h := measure_multiline_height(t.title, 20, text_max_w)
        
        // Ensure minimum height and add padding
        
        computed_h := 10 + text_h + 6 + 12 + 10
        final_h := max(computed_h, layout.task_height)
        
        rect := rl.Rectangle{layout.task_start_x, y, layout.task_width, final_h}
        draw_task_item(t, rect, theme)
        y += final_h + layout.task_spacing
    }
}

draw_task_item :: proc(t: model.Task, rect: rl.Rectangle, theme: utils.Theme) {
    // Background
    rl.DrawRectangleRounded(rect, 0.2, 4, rl.ColorAlpha(theme.task_bg, 0.5))

    // Priority Dot
    dot_color := theme.priority_low
    switch t.priority {
        case .Low: dot_color = theme.priority_low
        case .Medium: dot_color = theme.priority_medium
        case .High: dot_color = theme.priority_high
    }
    rl.DrawCircle(i32(rect.x) + 20, i32(rect.y) + i32(rect.height/2), 6, dot_color)
    
    // Checkbox
    checked := t.is_completed
    check_size: f32 = 20
    check_rect := rl.Rectangle{rect.x + 60, rect.y + (rect.height - check_size)/2, check_size, check_size}
    
    rl.DrawRectangleLinesEx(check_rect, 2, theme.text_secondary)
    if checked {
         rl.DrawLineEx(rl.Vector2{check_rect.x + 4, check_rect.y + 10}, rl.Vector2{check_rect.x + 8, check_rect.y + 16}, 2, theme.accent)
         rl.DrawLineEx(rl.Vector2{check_rect.x + 8, check_rect.y + 16}, rl.Vector2{check_rect.x + 16, check_rect.y + 4}, 2, theme.accent)
    }

    // Delete Icon (Better Trash Can)
    del_size: f32 = 20
    del_rect := rl.Rectangle{rect.x + rect.width - 40, rect.y + (rect.height - del_size)/2, del_size, del_size}
    
    // Hover effect
    mouse_p := rl.GetMousePosition()
    if rl.CheckCollisionPointRec(mouse_p, del_rect) {
        rl.DrawCircle(i32(del_rect.x + del_size/2), i32(del_rect.y + del_size/2), 15, rl.ColorAlpha(theme.priority_high, 0.2))
    }
    
    // Icon
    // Can: Rect
    rl.DrawRectangle(i32(del_rect.x)+4, i32(del_rect.y)+4, 12, 14, theme.text_secondary) 
    // Lid
    rl.DrawRectangle(i32(del_rect.x)+2, i32(del_rect.y)+2, 16, 2, theme.text_secondary)
    // Lines
    rl.DrawLine(i32(del_rect.x)+7, i32(del_rect.y)+6, i32(del_rect.x)+7, i32(del_rect.y)+16, theme.background)
    rl.DrawLine(i32(del_rect.x)+10, i32(del_rect.y)+6, i32(del_rect.x)+10, i32(del_rect.y)+16, theme.background)
    
    // Title
    title := t.title
    color := theme.text_primary
    if checked {
        color = theme.text_secondary
    }
    
    // Max width: Rect width - (left_padding + checkbox + spacing) - (trash_icon + spacing)
    // Left side: ~100px. Right side: ~40px. 
    max_w := rect.width - 150 
    
    draw_text_multiline(title, i32(rect.x) + 100, i32(rect.y) + 10, max_w, 20, color)
    
    // Date position at bottom of the card
    
    date_y := i32(rect.y + rect.height - 25)
    date_str := "22.05.2024, 10:58"
    draw_text_custom(date_str, i32(rect.x) + 100, date_y, 12, theme.text_secondary)
}
