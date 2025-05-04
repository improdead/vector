extends SceneTree

func _init():
    print("Checking input actions...")
    var actions = InputMap.get_actions()
    print("Available input actions: ", actions)
    quit()
