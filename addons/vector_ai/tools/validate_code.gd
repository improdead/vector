#!/usr/bin/env -S godot --headless --script
extends SceneTree

# This script validates GDScript code in a headless environment
# It can be used in CI/CD pipelines to catch syntax errors before they cause problems
# Usage: godot --headless --script validate_code.gd -- [file_path]

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
	
	# Get the file path
	var file_path = args[0]
	
	# Validate the file
	var result = validate_file(file_path)
	
	if result.success:
		print("Validation successful: " + file_path)
	else:
		print("Validation failed: " + file_path)
		print("Error: " + result.error)
		OS.exit_code = 1
	
	quit()

# Print help information
func print_help():
	print("GDScript Validator - Command-line tool for validating GDScript code")
	print("")
	print("Usage:")
	print("  godot --headless --script validate_code.gd -- [file_path]")
	print("")
	print("Arguments:")
	print("  file_path - Path to the GDScript file to validate")
	print("")
	print("Examples:")
	print("  godot --headless --script validate_code.gd -- res://main.gd")
	print("  godot --headless --script validate_code.gd -- res://scripts/player.gd")

# Validate a GDScript file
func validate_file(file_path):
	var result = {
		"success": false,
		"error": ""
	}
	
	# Check if the file exists
	if not FileAccess.file_exists(file_path):
		result.error = "File does not exist: " + file_path
		return result
	
	# Check if the file is a GDScript file
	if not file_path.ends_with(".gd"):
		result.error = "Not a GDScript file: " + file_path
		return result
	
	# Load the file
	var file = FileAccess.open(file_path, FileAccess.READ)
	if not file:
		result.error = "Failed to open file: " + file_path
		return result
	
	var code = file.get_as_text()
	file.close()
	
	# Try to parse the script
	var script = GDScript.new()
	script.source_code = code
	
	var error = script.reload()
	if error != OK:
		result.error = "Script compilation error: " + str(error)
		return result
	
	# If we got here, the script is valid
	result.success = true
	return result
