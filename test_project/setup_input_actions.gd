extends SceneTree

func _init():
    print("Setting up input actions for maze game...")
    
    # Define the required input actions if they don't exist
    if not InputMap.has_action("move_up"):
        InputMap.add_action("move_up")
        var event = InputEventKey.new()
        event.keycode = KEY_UP
        InputMap.action_add_event("move_up", event)
        event = InputEventKey.new()
        event.keycode = KEY_W
        InputMap.action_add_event("move_up", event)
        print("Added move_up action")
    
    if not InputMap.has_action("move_down"):
        InputMap.add_action("move_down")
        var event = InputEventKey.new()
        event.keycode = KEY_DOWN
        InputMap.action_add_event("move_down", event)
        event = InputEventKey.new()
        event.keycode = KEY_S
        InputMap.action_add_event("move_down", event)
        print("Added move_down action")
    
    if not InputMap.has_action("move_left"):
        InputMap.add_action("move_left")
        var event = InputEventKey.new()
        event.keycode = KEY_LEFT
        InputMap.action_add_event("move_left", event)
        event = InputEventKey.new()
        event.keycode = KEY_A
        InputMap.action_add_event("move_left", event)
        print("Added move_left action")
    
    if not InputMap.has_action("move_right"):
        InputMap.add_action("move_right")
        var event = InputEventKey.new()
        event.keycode = KEY_RIGHT
        InputMap.action_add_event("move_right", event)
        event = InputEventKey.new()
        event.keycode = KEY_D
        InputMap.action_add_event("move_right", event)
        print("Added move_right action")
    
    # Save the project settings
    ProjectSettings.save()
    print("Input actions saved to project settings")
    
    quit()
