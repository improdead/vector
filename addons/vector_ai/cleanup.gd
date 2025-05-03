@tool
extends EditorScript

# This script removes old files that are no longer needed
# Run this script from the Godot editor to clean up the project

func _run():
	print("Cleaning up old files...")
	
	# List of files to remove
	var files_to_remove = [
		"res://addons/vector_ai/scripts/advanced_tscn_parser.gd",
		"res://addons/vector_ai/scripts/ai_patch.gd",
		"res://addons/vector_ai/scripts/code_executor.gd",
		"res://addons/vector_ai/scripts/context_manager.gd",
		"res://addons/vector_ai/scripts/json_command_processor.gd",
		"res://addons/vector_ai/scripts/project_analyzer.gd",
		"res://addons/vector_ai/scripts/scene_analyzer.gd",
		"res://addons/vector_ai/scripts/scene_file_modifier.gd",
		"res://addons/vector_ai/scripts/scene_modifier.gd",
		"res://addons/vector_ai/scripts/sidebar.gd",
		"res://addons/vector_ai/scripts/tscn_parser.gd",
		"res://addons/vector_ai/scenes/sidebar.tscn"
	]
	
	# Remove each file
	for file_path in files_to_remove:
		if FileAccess.file_exists(file_path):
			var dir = DirAccess.open("res://")
			if dir:
				var error = dir.remove(file_path)
				if error == OK:
					print("Removed: " + file_path)
				else:
					print("Failed to remove: " + file_path)
			else:
				print("Failed to open directory")
		else:
			print("File not found: " + file_path)
	
	print("Cleanup complete!")
