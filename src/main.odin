package main



main :: proc() {
    app := init_app()
    run_app(&app)
    close_app(&app)
}
