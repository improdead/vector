#!/usr/bin/env -S godot --headless --script
extends SceneTree

# This script validates scene files in a headless environment
# It can be used in CI/CD pipelines to catch errors before they cause problems
# Usage: godot --headless --script validate_scene.gd -- [scene_path]

func _init():
	# Parse command line arguments
	var args = OS.get_cmdline_args()
	
	# Find the -- separator
	var separator_index = args.find("--")
	if separator_index == -1:
		print_help()
		quit()
		return
	
	# Get the arguments after the separator
	args = args.slice(separator_index + 1)
	
	if args.size() == 0:
		print_help()
		quit()
		return
	
	# Get the scene path
	var scene_path = args[0]
	
	# Validate the scene
	var result = validate_scene(scene_path)
	
	if result.success:
		print("Validation successful: " + scene_path)
	else:
		print("Validation failed: " + scene_path)
		print("Error: " + result.error)
		OS.exit_code = 1
	
	quit()

# Print help information
func print_help():
	print("Scene Validator - Command-line tool for validating Godot scene files")
	print("")
	print("Usage:")
	print("  godot --headless --script validate_scene.gd -- [scene_path]")
	print("")
	print("Arguments:")
	print("  scene_path - Path to the scene file to validate")
	print("")
	print("Examples:")
	print("  godot --headless --script validate_scene.gd -- res://main.tscn")
	print("  godot --headless --script validate_scene.gd -- res://scenes/level1.tscn")

# Validate a scene file
func validate_scene(scene_path):
	var result = {
		"success": false,
		"error": ""
	}
	
	# Check if the file exists
	if not FileAccess.file_exists(scene_path):
		result.error = "File does not exist: " + scene_path
		return result
	
	# Check if the file is a scene file
	if not scene_path.ends_with(".tscn"):
		result.error = "Not a scene file: " + scene_path
		return result
	
	# Try to load the scene
	var scene = ResourceLoader.load(scene_path, "PackedScene")
	if not scene:
		result.error = "Failed to load scene: " + scene_path
		return result
	
	# Try to instantiate the scene
	var instance = scene.instantiate()
	if not instance:
		result.error = "Failed to instantiate scene: " + scene_path
		return result
	
	# Clean up
	instance.queue_free()
	
	# If we got here, the scene is valid
	result.success = true
	return result
