package ui

import rl "vendor:raylib"

Layout :: struct {
    screen_width:  f32,
    screen_height: f32,
    
    // Header
    header_y: f32,
    header_title_size: i32,
    
    // New Task Button
    new_btn_rect: rl.Rectangle,
    
    // Theme Toggle
    theme_btn_rect: rl.Rectangle,
    
    // Filter Bar
    filter_bar_y: f32,
    filter_start_x: f32,
    filter_spacing: f32,
    filter_font_size: i32,
    
    // Task List
    list_start_y: f32,
    task_height: f32,
    task_spacing: f32,
    task_width: f32, // Calculated based on padding
    task_start_x: f32,
}

calculate_layout :: proc() -> Layout {
    w := f32(rl.GetScreenWidth())
    h := f32(rl.GetScreenHeight())
    
    l := Layout{
        screen_width = w,
        screen_height = h,
        header_y = 40,
        header_title_size = 40,
    }
    
    // Padding
    padding_x: f32 = 50
    if w < 600 {
        padding_x = 20
        l.header_title_size = 30
    }
    
    // New Task Button (Top Right)
    btn_w: f32 = 120
    btn_h: f32 = 40
    l.new_btn_rect = rl.Rectangle{w - padding_x - btn_w, l.header_y, btn_w, btn_h}
    
    // Theme Toggle (Icon/Button left of New Task)
    theme_size: f32 = 40
    l.theme_btn_rect = rl.Rectangle{l.new_btn_rect.x - theme_size - 20, l.header_y, theme_size, theme_size}
    
    // Position the filter bar below the header
    l.filter_bar_y = l.header_y + 50
    l.filter_start_x = padding_x
    l.filter_spacing = 20
    l.filter_font_size = 14
    
    // Task List Area
    l.list_start_y = l.filter_bar_y + 40
    l.task_height = 60
    l.task_spacing = 10
    l.task_start_x = padding_x
    l.task_width = w - (padding_x * 2)
    
    return l
}
