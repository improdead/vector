extends SceneTree

func _init():
    print("Fixing main.tscn file...")
    
    # Load the main scene
    var scene = load("res://main.tscn")
    if scene:
        print("Main scene loaded successfully")
        
        # Save the scene to ensure it's properly formatted
        var error = ResourceSaver.save(scene, "res://main.tscn")
        if error == OK:
            print("Main scene saved successfully")
        else:
            print("Error saving main scene: " + str(error))
    else:
        print("Failed to load main scene")
    
    quit()
