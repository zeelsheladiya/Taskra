package utils

import rl "vendor:raylib"

Theme :: struct {
    background: rl.Color,
    text_primary: rl.Color,
    text_secondary: rl.Color,
    accent: rl.Color,
    task_bg: rl.Color,
    priority_low: rl.Color,
    priority_medium: rl.Color,
    priority_high: rl.Color,
}

// Predefined Themes
Theme_Dark :: Theme{
    background = rl.Color{20, 20, 20, 255},       // #141414
    text_primary = rl.Color{255, 255, 255, 255},
    text_secondary = rl.Color{150, 150, 150, 255},
    accent = rl.Color{53, 166, 240, 255},         // Light Blue #35A6F0
    task_bg = rl.Color{30, 30, 30, 255},          // Slightly lighter for hover/items if needed
    priority_low = rl.Color{100, 255, 100, 255},  // Green
    priority_medium = rl.Color{255, 255, 100, 255},// Yellow
    priority_high = rl.Color{255, 100, 100, 255}, // Red
}

Theme_Light :: Theme{
    background = rl.Color{245, 245, 245, 255},
    text_primary = rl.Color{20, 20, 20, 255},
    text_secondary = rl.Color{100, 100, 100, 255},
    accent = rl.Color{53, 166, 240, 255},
    task_bg = rl.Color{255, 255, 255, 255},
    priority_low = rl.Color{50, 200, 50, 255},
    priority_medium = rl.Color{200, 200, 50, 255},
    priority_high = rl.Color{200, 50, 50, 255},
}

current_theme: Theme

init_theme :: proc(is_dark: bool) {
    if is_dark {
        current_theme = Theme_Dark
    } else {
        current_theme = Theme_Light
    }
}

toggle_theme :: proc() {
    if current_theme.background == Theme_Dark.background {
        current_theme = Theme_Light
    } else {
        current_theme = Theme_Dark
    }
}
