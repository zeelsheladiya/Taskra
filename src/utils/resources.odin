package utils

import rl "vendor:raylib"

// Global Resources
ui_font: rl.Font

init_resources :: proc() {
    // Load font with bilinear filtering for smoothness
    // Use a large size to allow scaling down nicely
    ui_font = rl.LoadFontEx("assets/font.ttf", 64, nil, 0)
    rl.SetTextureFilter(ui_font.texture, .BILINEAR)
}

unload_resources :: proc() {
    rl.UnloadFont(ui_font)
}
