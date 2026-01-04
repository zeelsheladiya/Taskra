package ui

import rl "vendor:raylib"
import "core:strings"
import "core:fmt"
import "../utils"

to_cstring :: proc(s: string) -> cstring {
    return strings.clone_to_cstring(s, context.temp_allocator)
}

// Wrapper to draw text using the global custom font
draw_text_custom :: proc(text: string, x, y: i32, size: f32, color: rl.Color) {
    // Spacing 1.0 looks good for Arial
    rl.DrawTextEx(utils.ui_font, to_cstring(text), rl.Vector2{f32(x), f32(y)}, size, 1.0, color)
}

// Wrapper for measuring
measure_text_custom :: proc(text: string, size: f32) -> f32 {
    vec := rl.MeasureTextEx(utils.ui_font, to_cstring(text), size, 1.0)
    return vec.x
}

draw_text_truncated :: proc(text: string, x, y: i32, size: f32, max_width: f32, color: rl.Color) {
    width := measure_text_custom(text, size)
    if width <= max_width {
        draw_text_custom(text, x, y, size, color)
    } else {
        // Truncate
        // Simple search for length that fits
        // (A binary search would be faster but for short strings linear is OK or just stripping chars)
        // Let's strip chars until it fits with "..."
        
        display_text := text
        ellipsis := "..."
        
        // Very crude iterative shortening
        current_len := len(text)
        for current_len > 0 {
            candidate := text[:current_len]
            w := measure_text_custom(candidate, size)
            e_w := measure_text_custom(ellipsis, size)
            
            if w + e_w <= max_width {
                // Draw candidate + ellipsis
                // Need to concat, but string allocation in loop is bad.
                // Just draw separately closely? or alloc temp
                full_s := strings.concatenate({candidate, ellipsis}, context.temp_allocator)
                draw_text_custom(full_s, x, y, size, color)
                return
            }
            current_len -= 1
        }
        
        // If nothing fits, draw nothing or just ellipsis
        draw_text_custom("...", x, y, size, color)
    }
}

draw_text_wrapped :: proc(text: string, x, y: i32, max_width: f32, size: f32, color: rl.Color, cursor_index: int, selection_anchor: int, scroll_offset: f32) -> (i32, i32) {
    // Returns the calculated (x, y) for the cursor.
    // We iterate character by character to ensure we can split anywhere and track cursor precisely.
    // Ideally we split by words, but for cursor tracking within words, char-by-char with "lookback" for word wrapping is standard.
    // For this simple implementation: Just wrap at char if needed, or better, stick to word wrapping but track cursor.
    
    // Improve word wrapping by tracking the cursor position.
    // We split words manually to ensure we can split long words if needed.
    
    current_line_width: f32 = 0
    line_start_y := f32(y) + scroll_offset  // Apply Scroll
    line_start_x := f32(x)
    line_height := size + 4
    
    cursor_pos_x: i32 = x
    cursor_pos_y: i32 = y
    
    // If empty text and cursor is 0
    if len(text) == 0 && cursor_index == 0 {
        return i32(line_start_x), i32(line_start_y)
    }

    // Iterate characters to build words while maintaining potential split points
    
    // Better: Iterate chars, build "current word". If space, it's a word end.
    
    word_buf := strings.builder_make(context.temp_allocator)
    char_count := 0
    
    // We render immediately when a word is complete or line breaks.
    
    // Actually, to correctly place the cursor strictly *between* characters, we need to know the position of every character.
    // Drawing whole words makes "mid-word" cursor hard.
    // CHANGE: Draw character by character for MVP interactive text area. It's Raylib, it can handle it.
    
    current_x := line_start_x
    current_y := line_start_y
    
    for i := 0; i < len(text); i += 1 {
        // Track Cursor
        if char_count == cursor_index {
            cursor_pos_x = i32(current_x)
            cursor_pos_y = i32(current_y)
        }
        
        char := text[i]
        s := fmt.tprintf("%c", char)
        char_w := measure_text_custom(s, size)
        
        // Wrap logic: check if adding this character exceeds width
        
        if current_x + char_w > line_start_x + max_width {
            current_x = line_start_x
            current_y += line_height
            // Update cursor if it was at this wrap point (cursor is before this char)
             if char_count == cursor_index {
                cursor_pos_x = i32(current_x)
                cursor_pos_y = i32(current_y)
            }
        }
        

        
        // Draw Selection Highlight
        is_selected := false
        if selection_anchor != -1 {
            start := min(cursor_index, selection_anchor)
            end := max(cursor_index, selection_anchor)
            if char_count >= start && char_count < end {
                is_selected = true
            }
        }
        
        if is_selected {
            rl.DrawRectangle(i32(current_x), i32(current_y), i32(char_w), i32(size), rl.ColorAlpha(rl.BLUE, 0.3))
        }
        
        draw_text_custom(s, i32(current_x), i32(current_y), size, color)
        current_x += char_w
        char_count += 1
    }
    
    // If cursor is at the very end
    if char_count == cursor_index {
        cursor_pos_x = i32(current_x)
        cursor_pos_y = i32(current_y)
    }
    
    return cursor_pos_x, cursor_pos_y
}

// Helpers for non-input multiline text (Word Wrapping with Character Breaking)

measure_multiline_height :: proc(text: string, size: f32, max_width: f32) -> f32 {
    if len(text) == 0 { return size }
    
    words := strings.split(text, " ", context.temp_allocator)
    if len(words) == 0 { return size }
    
    line_count := 1
    current_line_width: f32 = 0
    space_w := measure_text_custom(" ", size)
    
    for word in words {
        word_w := measure_text_custom(word, size)
        
        // If word fits on current line, add it
        if current_line_width + word_w <= max_width {
            current_line_width += word_w + space_w
            continue
        }
        
        // If the word itself is wider than max_width, split it across lines
        if word_w > max_width {
             // If we have content on current line, wrap first
             if current_line_width > 0 {
                 line_count += 1
                 current_line_width = 0
             }
             
             // Now wrap the word itself character by character (approximation)
             // or just check how many lines it takes
             
             // We'll iterate chars of the long word
             w_cursor: f32 = 0
             for j := 0; j < len(word); j += 1 {
                 char_s := fmt.tprintf("%c", word[j])
                 cw := measure_text_custom(char_s, size)
                 
                 if w_cursor + cw > max_width {
                     line_count += 1
                     w_cursor = 0
                 }
                 w_cursor += cw
             }
             
             // After word is done, add space
             current_line_width = w_cursor + space_w
             continue
        }
        
        // Standard wrapping: move to next line
        line_count += 1
        current_line_width = word_w + space_w
    }
    
    // Spacing
    line_spacing: f32 = 4
    return f32(line_count) * (size + line_spacing)
}

draw_text_multiline :: proc(text: string, x, y: i32, max_width: f32, size: f32, color: rl.Color) {
    if len(text) == 0 { return }
    
    words := strings.split(text, " ", context.temp_allocator)
    if len(words) == 0 { return }
    
    current_line_width: f32 = 0
    line_start_y := f32(y)
    line_height := size + 4
    space_w := measure_text_custom(" ", size)
    
    for word in words {
        word_w := measure_text_custom(word, size)
        
        // Case 1: Fits line
        if current_line_width + word_w <= max_width {
            draw_text_custom(word, x + i32(current_line_width), i32(line_start_y), size, color)
            current_line_width += word_w + space_w
            continue
        }
        
        // Case 2: Huge word
        if word_w > max_width {
             // If content exists, wrap first
             if current_line_width > 0 {
                 current_line_width = 0
                 line_start_y += line_height
             }
             
             // Draw char by char
             w_cursor: f32 = 0
             for j := 0; j < len(word); j += 1 {
                 char_s := fmt.tprintf("%c", word[j])
                 cw := measure_text_custom(char_s, size)
                 
                 if w_cursor + cw > max_width {
                     w_cursor = 0
                     line_start_y += line_height
                 }
                 
                 draw_text_custom(char_s, x + i32(w_cursor), i32(line_start_y), size, color)
                 w_cursor += cw
             }
             
             current_line_width = w_cursor + space_w
             continue
        }
        
        // Case 3: New Line
        current_line_width = 0
        line_start_y += line_height
        draw_text_custom(word, x + i32(current_line_width), i32(line_start_y), size, color)
        current_line_width += word_w + space_w
    }
}
