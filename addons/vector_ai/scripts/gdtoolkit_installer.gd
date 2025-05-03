@tool
extends Node

# This script handles the installation and usage of GDToolkit for GDScript validation

var gdtoolkit_installed = false
var gdtoolkit_path = "res://addons/gdtoolkit"

func _ready():
	# Check if GDToolkit is already installed
	gdtoolkit_installed = _check_gdtoolkit_installed()

# Ensure GDToolkit is installed
func ensure_installed():
	if gdtoolkit_installed:
		return true
	
	# Try to install GDToolkit
	return _install_gdtoolkit()

# Check if GDToolkit is installed
func _check_gdtoolkit_installed():
	return DirAccess.dir_exists_absolute(gdtoolkit_path)

# Install GDToolkit
func _install_gdtoolkit():
	# We can't actually install packages from GDScript
	# So we'll just notify the user that they need to install it manually
	push_warning("GDToolkit is not installed. For better syntax validation, please install it manually.")
	push_warning("Run: pip install gdtoolkit")
	push_warning("Then copy the gdtoolkit folder to: " + gdtoolkit_path)
	
	return false

# Validate GDScript code using GDToolkit
func validate_gdscript(code):
	var result = {
		"success": true,
		"errors": [],
		"warnings": []
	}
	
	if not gdtoolkit_installed:
		# Fall back to basic validation
		return _basic_validate_gdscript(code)
	
	# If GDToolkit is installed, use it for validation
	# This would require integration with the Python module
	# For now, we'll use basic validation
	
	return _basic_validate_gdscript(code)

# Basic GDScript validation without GDToolkit
func _basic_validate_gdscript(code):
	var result = {
		"success": true,
		"errors": [],
		"warnings": []
	}
	
	# Check for common syntax errors
	var lines = code.split("\n")
	var in_function = false
	var in_class = false
	var brace_stack = []
	var parenthesis_stack = []
	var bracket_stack = []
	
	for i in range(lines.size()):
		var line = lines[i].strip_edges()
		
		# Skip empty lines and comments
		if line.is_empty() or line.begins_with("#"):
			continue
		
		# Check for mismatched braces
		for c in line:
			match c:
				"{":
					brace_stack.push_back(i)
				"}":
					if brace_stack.size() == 0:
						result.errors.append({
							"line": i + 1,
							"message": "Unexpected closing brace"
						})
					else:
						brace_stack.pop_back()
				"(":
					parenthesis_stack.push_back(i)
				")":
					if parenthesis_stack.size() == 0:
						result.errors.append({
							"line": i + 1,
							"message": "Unexpected closing parenthesis"
						})
					else:
						parenthesis_stack.pop_back()
				"[":
					bracket_stack.push_back(i)
				"]":
					if bracket_stack.size() == 0:
						result.errors.append({
							"line": i + 1,
							"message": "Unexpected closing bracket"
						})
					else:
						bracket_stack.pop_back()
		
		# Check for variable declarations
		if "=" in line and not line.begins_with("var ") and not line.begins_with("const ") and not line.begins_with("@") and not in_function and not in_class:
			result.warnings.append({
				"line": i + 1,
				"message": "Variable assignment without var/const declaration"
			})
		
		# Check if we're entering a function
		if line.begins_with("func "):
			in_function = true
		
		# Check if we're entering a class
		if line.begins_with("class "):
			in_class = true
		
		# Check if we're exiting a function or class
		if in_function and line == "}":
			in_function = false
		
		if in_class and line == "}":
			in_class = false
	
	# Check for unclosed braces, parentheses, and brackets
	if brace_stack.size() > 0:
		result.errors.append({
			"line": brace_stack.back() + 1,
			"message": "Unclosed brace"
		})
	
	if parenthesis_stack.size() > 0:
		result.errors.append({
			"line": parenthesis_stack.back() + 1,
			"message": "Unclosed parenthesis"
		})
	
	if bracket_stack.size() > 0:
		result.errors.append({
			"line": bracket_stack.back() + 1,
			"message": "Unclosed bracket"
		})
	
	# Set success based on errors
	result.success = result.errors.size() == 0
	
	return result

# Fix common GDScript syntax issues
func fix_gdscript_syntax(code):
	var lines = code.split("\n")
	var processed_lines = []
	var in_function = false
	var in_class = false
	
	for i in range(lines.size()):
		var line = lines[i].strip_edges()
		
		# Skip empty lines and comments
		if line.is_empty() or line.begins_with("#"):
			processed_lines.append(lines[i])
			continue
		
		# Check if we're entering a function
		if line.begins_with("func "):
			in_function = true
		
		# Check if we're entering a class
		if line.begins_with("class "):
			in_class = true
		
		# Check if we're exiting a function or class
		if in_function and line == "}":
			in_function = false
		
		if in_class and line == "}":
			in_class = false
		
		# Fix variable assignments without var/const
		if not in_function and not in_class and "=" in line and not line.begins_with("var ") and not line.begins_with("const ") and not line.begins_with("@"):
			# This is a bare assignment outside a function, add var
			processed_lines.append("var " + lines[i])
		else:
			processed_lines.append(lines[i])
	
	return "\n".join(processed_lines)
