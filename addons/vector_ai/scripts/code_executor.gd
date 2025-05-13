@tool
extends Node

# Reference to the editor interface
var editor_interface
var undo_redo
var scene_modifier

# Blacklisted keywords for security
const BLACKLISTED_KEYWORDS = [
	"OS.execute",
	"OS.shell_open",
	"Directory.remove",
	"DirAccess.remove",
	"FileAccess.open",
	"load_resource",
	"ResourceLoader.load",
	"ProjectSettings",
	"get_tree().quit",
	"Engine.get_singleton"
]

func _ready():
	# Get the editor interface
	editor_interface = Engine.get_singleton("EditorInterface")
	undo_redo = editor_interface.get_undo_redo()

	# Get reference to scene_modifier
	scene_modifier = get_parent().get_node("SceneModifier")

# Execute code with syntax validation
func execute_code(code_string):
	# First, validate and fix the code
	var validated_code = _validate_and_fix_gdscript_syntax(code_string)

	# Check for security issues
	for keyword in BLACKLISTED_KEYWORDS:
		if validated_code.find(keyword) != -1:
			return {
				"success": false,
				"error": "Security violation: Use of restricted keyword '" + keyword + "' is not allowed."
			}

	# Check for syntax errors that couldn't be automatically fixed
	var syntax_errors = _check_for_syntax_errors(validated_code)
	if syntax_errors.size() > 0:
		var error_message = "GDScript syntax errors detected:\n"
		for error in syntax_errors:
			error_message += "Line " + str(error.line) + ": " + error.error + "\n"

		# Return both the error and the partially fixed code
		return {
			"success": false,
			"error": error_message,
			"fixed_code": validated_code
		}

	# For direct scene editing, we'll return the validated code
	return {
		"success": true,
		"validated_code": validated_code,
		"message": "Code validated successfully. Use direct scene editing to apply changes."
	}

# Preprocess code specifically for execution in the EditorScript
func _preprocess_code_for_execution(code):
	var lines = code.split("\n")
	var processed_lines = []
	var variable_declarations = {}
	var known_variables = {}

	# First pass: identify all variable declarations and assignments
	for i in range(lines.size()):
		var line = lines[i].strip_edges()

		# Skip empty lines and comments
		if line.is_empty() or line.begins_with("#"):
			continue

		# Track variables that are already declared with var or const
		if line.begins_with("var ") or line.begins_with("const "):
			var var_name = line.substr(line.begins_with("var ") ? 4 : 6).strip_edges()
			if "=" in var_name:
				var_name = var_name.split("=")[0].strip_edges()
			if ":" in var_name:
				var_name = var_name.split(":")[0].strip_edges()

			known_variables[var_name] = true

		# Check for variable assignments without var/const
		elif "=" in line and not line.begins_with("@"):
			var parts = line.split("=", true, 1)
			var variable_name = parts[0].strip_edges()

			# Only consider it a variable assignment if:
			# 1. It's not a property access (no dots)
			# 2. It's not an array/dictionary access (no brackets)
			# 3. It's not a function call (no parentheses)
			# 4. It's not a comparison (==, !=, <=, >=)
			# 5. It's not a logical operation (and, or, not)
			if not "." in variable_name and not "[" in variable_name and not "(" in variable_name and \
			   not "==" in line and not "!=" in line and not "<=" in line and not ">=" in line and \
			   not " and " in line and not " or " in line and not " not " in line:

				# This is likely a variable assignment without var/const
				if not known_variables.has(variable_name):
					variable_declarations[variable_name] = true

	# Second pass: add var declarations and fix other issues
	for i in range(lines.size()):
		var line = lines[i].strip_edges()

		# Skip empty lines
		if line.is_empty():
			continue

		# Fix variable assignments that need var declarations
		if "=" in line and not line.begins_with("var ") and not line.begins_with("const ") and not line.begins_with("@"):
			var parts = line.split("=", true, 1)
			var variable_name = parts[0].strip_edges()

			# Only add var if:
			# 1. We identified it as needing a declaration
			# 2. It's not a property access, array access, or function call
			if variable_declarations.has(variable_name):
				# Add var declaration
				line = "var " + line

		# Fix Vector2 syntax only for literal coordinates, not for variables
		if "(" in line and "," in line and ")" in line:
			# Look for patterns like (x, y) that should be Vector2(x, y)
			# But only if x and y are numbers, not variables
			var regex = RegEx.new()
			regex.compile("\\(\\s*(\\d+(\\.\\d+)?)\\s*,\\s*(\\d+(\\.\\d+)?)\\s*\\)")
			var result = regex.search(line)
			if result:
				var match_str = result.get_string()
				var x = result.get_string(1)
				var y = result.get_string(3)
				line = line.replace(match_str, "Vector2(" + x + ", " + y + ")")

		processed_lines.append(line)

	return "\n".join(processed_lines)

# Fix common syntax errors in code
func _fix_common_syntax_errors(code):
	var lines = code.split("\n")
	var processed_lines = []
	var in_function = false
	var has_ready_function = false
	var known_variables = {}
	var class_level_assignments = []

	# First pass: identify variable declarations and bare assignments
	for i in range(lines.size()):
		var line = lines[i].strip_edges()

		# Skip empty lines and comments
		if line.is_empty() or line.begins_with("#"):
			continue

		# Track variables that are already declared with var or const
		if line.begins_with("var ") or line.begins_with("const "):
			var var_name = line.substr(line.begins_with("var ") ? 4 : 6).strip_edges()
			if "=" in var_name:
				var_name = var_name.split("=")[0].strip_edges()
			if ":" in var_name:
				var_name = var_name.split(":")[0].strip_edges()

			known_variables[var_name] = true

		# Check if we're entering a function
		if line.begins_with("func "):
			in_function = true
			if line.begins_with("func _ready"):
				has_ready_function = true

		# Check if we're exiting a function
		elif in_function and line == "":
			in_function = false

		# Check for bare assignments at class level (not in a function)
		elif not in_function and "=" in line and not line.begins_with("var ") and not line.begins_with("const ") and not line.begins_with("@"):
			var parts = line.split("=", true, 1)
			var variable_name = parts[0].strip_edges()

			# Only consider it a variable assignment if:
			# 1. It's not a property access (no dots)
			# 2. It's not an array/dictionary access (no brackets)
			# 3. It's not a function call (no parentheses)
			# 4. It's not a comparison (==, !=, <=, >=)
			# 5. It's not a logical operation (and, or, not)
			if not "." in variable_name and not "[" in variable_name and not "(" in variable_name and \
			   not "==" in line and not "!=" in line and not "<=" in line and not ">=" in line and \
			   not " and " in line and not " or " in line and not " not " in line:

				# This is likely a variable assignment without var/const
				if not known_variables.has(variable_name):
					class_level_assignments.append(i)
					known_variables[variable_name] = true

	# Only create a _ready function if we actually found bare assignments
	var ready_func_lines = []
	if class_level_assignments.size() > 0 and not has_ready_function:
		ready_func_lines.append("func _ready():")
		for i in class_level_assignments:
			ready_func_lines.append("\t" + lines[i].strip_edges())
		ready_func_lines.append("\tpass")

	# Second pass: process the lines with proper indentation and fix bare assignments
	in_function = false
	var skip_indices = []
	if ready_func_lines.size() > 0:
		for i in class_level_assignments:
			skip_indices.append(i)

	for i in range(lines.size()):
		if skip_indices.has(i):
			continue

		var line = lines[i].strip_edges()

		# Skip empty lines
		if line.is_empty():
			continue

		# Check if we're entering or exiting a function
		if line.begins_with("func "):
			in_function = true
		elif in_function and line == "":
			in_function = false

		# Fix bare assignments at class level only if we're not in a function
		if not in_function and class_level_assignments.has(i):
			line = "var " + line

		# Add the line to processed lines
		processed_lines.append(line)

	# Add the _ready function if needed
	if ready_func_lines.size() > 0:
		# Find the right position to insert the _ready function
		var insert_index = 0
		for i in range(processed_lines.size()):
			if processed_lines[i].begins_with("func "):
				insert_index = i
				break

		# Insert the _ready function
		for i in range(ready_func_lines.size()):
			processed_lines.insert(insert_index + i, ready_func_lines[i])

	return "\n".join(processed_lines)

# Fix syntax issues in a single line
func _fix_line_syntax(line):
	# Fix missing var/const for assignments, but be careful not to modify property assignments
	if "=" in line and not line.begins_with("var ") and not line.begins_with("const ") and not line.begins_with("func ") and not line.begins_with("@"):
		var parts = line.split("=", true, 1)
		var variable_name = parts[0].strip_edges()

		# Only consider it a variable assignment if:
		# 1. It's not a property access (no dots)
		# 2. It's not an array/dictionary access (no brackets)
		# 3. It's not a function call (no parentheses)
		# 4. It's not a comparison (==, !=, <=, >=)
		# 5. It's not a logical operation (and, or, not)
		if not "." in variable_name and not "[" in variable_name and not "(" in variable_name and \
		   not "==" in line and not "!=" in line and not "<=" in line and not ">=" in line and \
		   not " and " in line and not " or " in line and not " not " in line:

			# This is likely a variable assignment without var/const
			line = "var " + line

	# Fix Vector2 syntax, but only for numeric literals
	if "(" in line and "," in line and ")" in line:
		# Look for patterns like (x, y) that should be Vector2(x, y)
		# But only if x and y are numbers, not variables
		var regex = RegEx.new()
		regex.compile("\\(\\s*(\\d+(\\.\\d+)?)\\s*,\\s*(\\d+(\\.\\d+)?)\\s*\\)")
		var result = regex.search(line)
		if result:
			var match_str = result.get_string()
			var x = result.get_string(1)
			var y = result.get_string(3)

			# Make sure we're not inside a function call like some_function(100, 200)
			var prefix = line.substr(0, line.find(match_str)).strip_edges()
			if not prefix.ends_with(")") and not prefix.ends_with("]") and not prefix.ends_with("}") and \
			   not prefix.ends_with("\"") and not prefix.ends_with("'"):
				line = line.replace(match_str, "Vector2(" + x + ", " + y + ")")

	return line

# Preprocess code to ensure proper indentation and fix common issues
func _preprocess_code(code):
	var lines = code.split("\n")
	var processed_lines = []
	var in_function = false
	var has_ready_function = false
	var ready_function_lines = []
	var class_level_assignments = []

	# First pass: identify bare assignments and check for _ready function
	for i in range(lines.size()):
		var line = lines[i].strip_edges()

		# Skip empty lines and comments
		if line.is_empty() or line.begins_with("#"):
			continue

		# Check if we're entering a function
		if line.begins_with("func "):
			in_function = true
			if line.begins_with("func _ready"):
				has_ready_function = true

		# Check if we're exiting a function
		elif in_function and line == "":
			in_function = false

		# Check for bare assignments at class level (not in a function)
		elif not in_function and "=" in line and not line.begins_with("var ") and not line.begins_with("const ") and not line.begins_with("@"):
			# This is a bare assignment at class level
			var parts = line.split("=", true, 1)
			var variable_name = parts[0].strip_edges()

			# Skip if it's a complex expression or already has var/const
			if not "." in variable_name and not "(" in variable_name and not "[" in variable_name:
				class_level_assignments.append(i)

	# Second pass: process the lines with proper indentation and fix bare assignments
	in_function = false
	for i in range(lines.size()):
		var line = lines[i].strip_edges()

		# Skip empty lines
		if line.is_empty():
			continue

		# Check if we're entering or exiting a function
		if line.begins_with("func "):
			in_function = true
		elif in_function and line == "":
			in_function = false

		# Fix bare assignments at class level
		if class_level_assignments.has(i):
			line = "var " + line

		# Add proper indentation (one tab)
		processed_lines.append("\t" + line)

	# If we have bare assignments but no _ready function, create one
	if class_level_assignments.size() > 0 and not has_ready_function:
		var ready_func = "\tfunc _ready():\n"
		for i in class_level_assignments:
			ready_func += "\t\t" + lines[i].strip_edges() + "\n"
		ready_func += "\t\tpass\n"

		# Add the _ready function after the class definition
		var result = "\n".join(processed_lines)
		var insert_pos = result.find("\n")
		if insert_pos != -1:
			result = result.substr(0, insert_pos + 1) + ready_func + result.substr(insert_pos + 1)
			return result

	return "\n".join(processed_lines)

# Extract code blocks from AI response
func extract_code_from_response(response_text):
	var code_blocks = []

	# Look for code blocks marked with ```gdscript and ```
	var start_markers = ["```gdscript", "```gd", "```GDScript"]
	var end_marker = "```"

	var pos = 0
	while pos < response_text.length():
		var start_pos = -1
		var marker_used = ""

		# Find the first occurrence of any start marker
		for marker in start_markers:
			var marker_pos = response_text.find(marker, pos)
			if marker_pos != -1 and (start_pos == -1 or marker_pos < start_pos):
				start_pos = marker_pos
				marker_used = marker

		if start_pos == -1:
			break

		var code_start = start_pos + marker_used.length()
		var end_pos = response_text.find(end_marker, code_start)

		if end_pos == -1:
			break

		var code_block = response_text.substr(code_start, end_pos - code_start).strip_edges()

		# Clean up the code block
		code_block = _clean_code_block(code_block)

		if not code_block.is_empty():
			code_blocks.append(code_block)

		pos = end_pos + end_marker.length()

	return code_blocks

# Clean up a code block to fix common issues
func _clean_code_block(code):
	# Remove any leading/trailing whitespace
	var cleaned_code = code.strip_edges()

	# Remove any leading/trailing backticks that might have been included
	if cleaned_code.begins_with("```"):
		cleaned_code = cleaned_code.substr(3)
	if cleaned_code.ends_with("```"):
		cleaned_code = cleaned_code.substr(0, cleaned_code.length() - 3)

	# Remove any language specifier at the beginning
	var first_line_end = cleaned_code.find("\n")
	if first_line_end != -1:
		var first_line = cleaned_code.substr(0, first_line_end).strip_edges().to_lower()
		if first_line == "gdscript" or first_line == "gd":
			cleaned_code = cleaned_code.substr(first_line_end + 1)

	# Remove any leading/trailing whitespace again
	cleaned_code = cleaned_code.strip_edges()

	# Apply syntax validation and fixes
	cleaned_code = _validate_and_fix_gdscript_syntax(cleaned_code)

	return cleaned_code

# Validate and fix GDScript syntax issues
func _validate_and_fix_gdscript_syntax(code):
	var lines = code.split("\n")
	var processed_lines = []
	var in_function = false
	var in_class = false
	var class_level_vars = {}
	var syntax_errors = []
	var function_depth = 0

	# Check if the code has an extends statement
	var has_extends = false
	for line in lines:
		if line.strip_edges().begins_with("extends "):
			has_extends = true
			break

	# Add extends Node if missing
	if not has_extends:
		processed_lines.append("extends Node")
		processed_lines.append("")

	# First pass: identify class structure and variables
	for i in range(lines.size()):
		var line = lines[i].strip_edges()

		# Skip empty lines and comments
		if line.is_empty() or line.begins_with("#"):
			continue

		# Check for class definition
		if line.begins_with("class ") or line.begins_with("extends "):
			in_class = true
			continue

		# Check if we're entering a function
		if line.begins_with("func "):
			in_function = true
			function_depth = 1
			continue

		# Track function depth with braces and indentation
		if in_function:
			if ":" in line:
				function_depth += 1
			if line == "pass" or line == "return" or line == "return null" or line == "return false" or line == "return true":
				function_depth -= 1
				if function_depth <= 0:
					in_function = false
					function_depth = 0
			continue

		# Check for class-level variable declarations (outside functions)
		if in_class and not in_function:
			# Properly declared variables with var/const
			if line.begins_with("var ") or line.begins_with("const "):
				var var_name = line.substr(line.begins_with("var ") ? 4 : 6).strip_edges()
				if "=" in var_name:
					var_name = var_name.split("=")[0].strip_edges()
				if ":" in var_name:
					var_name = var_name.split(":")[0].strip_edges()

				class_level_vars[var_name] = true
				continue

			# Check for bare identifiers at class level
			if "=" in line and not line.begins_with("@") and not line.begins_with("signal ") and not line.begins_with("enum "):
				var parts = line.split("=", true, 1)
				var identifier = parts[0].strip_edges()

				# Only consider it a variable if it's a simple identifier
				if not "." in identifier and not "[" in identifier and not "(" in identifier:
					syntax_errors.append({
						"line": i + 1,
						"error": "Unexpected identifier '" + identifier + "' in class body. Class-level variables must be declared with 'var' or 'const'.",
						"fix": "var " + line
					})

	# Second pass: apply fixes
	in_function = false
	in_class = false
	function_depth = 0

	for i in range(lines.size()):
		var line = lines[i]
		var stripped_line = line.strip_edges()

		# Skip empty lines
		if stripped_line.is_empty():
			processed_lines.append(line)
			continue

		# Skip comments
		if stripped_line.begins_with("#"):
			processed_lines.append(line)
			continue

		# Check for class definition
		if stripped_line.begins_with("class ") or stripped_line.begins_with("extends "):
			in_class = true
			# Skip if we already added an extends statement
			if has_extends or not stripped_line.begins_with("extends "):
				processed_lines.append(line)
			continue

		# Check if we're entering a function
		if stripped_line.begins_with("func "):
			in_function = true
			function_depth = 1
			processed_lines.append(line)
			continue

		# Track function depth
		if in_function:
			if ":" in stripped_line:
				function_depth += 1
			if stripped_line == "pass" or stripped_line == "return" or stripped_line == "return null" or stripped_line == "return false" or stripped_line == "return true":
				function_depth -= 1
				if function_depth <= 0:
					in_function = false
					function_depth = 0

			# Inside functions, just add the line as is
			processed_lines.append(line)
			continue

		# Check if this line has a syntax error
		var has_error = false
		var fixed_line = line

		for error in syntax_errors:
			if error.line == i + 1:
				has_error = true

				# Preserve indentation
				var indent = ""
				for j in range(line.length()):
					if line[j] == " " or line[j] == "\t":
						indent += line[j]
					else:
						break

				fixed_line = indent + error.fix
				break

		processed_lines.append(fixed_line)

	# Check if we need to add a _ready function
	var has_ready = false
	for line in processed_lines:
		if line.strip_edges().begins_with("func _ready"):
			has_ready = true
			break

	if not has_ready:
		processed_lines.append("\nfunc _ready():")
		processed_lines.append("\tpass")

	return "\n".join(processed_lines)

# Check for syntax errors that can't be automatically fixed
func _check_for_syntax_errors(code):
	# First, try to fix the code with our validation function
	var fixed_code = _validate_and_fix_gdscript_syntax(code)

	# Now check the fixed code for any remaining errors
	var lines = fixed_code.split("\n")
	var errors = []
	var in_function = false
	var in_class = false
	var function_depth = 0
	var brace_stack = []
	var parenthesis_stack = []
	var bracket_stack = []
	var known_variables = {}

	# First pass: identify all declared variables
	for i in range(lines.size()):
		var line = lines[i].strip_edges()

		# Skip empty lines and comments
		if line.is_empty() or line.begins_with("#"):
			continue

		# Track class and function scope
		if line.begins_with("class ") or line.begins_with("extends "):
			in_class = true
		elif line.begins_with("func "):
			in_function = true
			function_depth = 1

		# Track function depth
		if in_function:
			if ":" in line:
				function_depth += 1
			if line == "pass" or line == "return" or line == "return null" or line == "return false" or line == "return true":
				function_depth -= 1
				if function_depth <= 0:
					in_function = false
					function_depth = 0

		# Track variables that are already declared with var or const
		if line.begins_with("var ") or line.begins_with("const "):
			var var_name = line.substr(line.begins_with("var ") ? 4 : 6).strip_edges()
			if "=" in var_name:
				var_name = var_name.split("=")[0].strip_edges()
			if ":" in var_name:
				var_name = var_name.split(":")[0].strip_edges()

			known_variables[var_name] = true

	# Second pass: check for errors
	in_function = false
	in_class = false
	function_depth = 0

	for i in range(lines.size()):
		var line = lines[i].strip_edges()

		# Skip empty lines and comments
		if line.is_empty() or line.begins_with("#"):
			continue

		# Track class and function scope
		if line.begins_with("class ") or line.begins_with("extends "):
			in_class = true
		elif line.begins_with("func "):
			in_function = true
			function_depth = 1

		# Track function depth
		if in_function:
			if ":" in line:
				function_depth += 1
			if line == "pass" or line == "return" or line == "return null" or line == "return false" or line == "return true":
				function_depth -= 1
				if function_depth <= 0:
					in_function = false
					function_depth = 0

		# Check for bare identifiers at class level (not in a function)
		if in_class and not in_function:
			# Look for identifiers that aren't properly declared
			if not line.begins_with("var ") and not line.begins_with("const ") and \
			   not line.begins_with("func ") and not line.begins_with("class ") and \
			   not line.begins_with("extends ") and not line.begins_with("@") and \
			   not line.begins_with("signal ") and not line.begins_with("enum ") and \
			   not line.begins_with("#"):

				# Check if it's an assignment without var/const
				if "=" in line and not "==" in line and not "!=" in line and not "<=" in line and not ">=" in line:
					var parts = line.split("=", true, 1)
					var identifier = parts[0].strip_edges()

					# Only flag simple identifiers (not properties or function calls)
					if not "." in identifier and not "[" in identifier and not "(" in identifier and \
					   not identifier.begins_with("if ") and not identifier.begins_with("for ") and \
					   not identifier.begins_with("while ") and not identifier.begins_with("match "):

						if not known_variables.has(identifier):
							errors.append({
								"line": i + 1,
								"error": "Unexpected identifier '" + identifier + "' in class body. Class-level variables must be declared with 'var' or 'const'."
							})

		# Check for mismatched braces, parentheses, and brackets
		for j in range(line.length()):
			var char = line[j]

			match char:
				"{": brace_stack.append(i + 1)
				"}":
					if brace_stack.size() == 0:
						errors.append({
							"line": i + 1,
							"error": "Unexpected closing brace '}' without matching opening brace."
						})
					else:
						brace_stack.pop_back()
				"(": parenthesis_stack.append(i + 1)
				")":
					if parenthesis_stack.size() == 0:
						errors.append({
							"line": i + 1,
							"error": "Unexpected closing parenthesis ')' without matching opening parenthesis."
						})
					else:
						parenthesis_stack.pop_back()
				"[": bracket_stack.append(i + 1)
				"]":
					if bracket_stack.size() == 0:
						errors.append({
							"line": i + 1,
							"error": "Unexpected closing bracket ']' without matching opening bracket."
						})
					else:
						bracket_stack.pop_back()

	# Check for unclosed braces, parentheses, and brackets
	if brace_stack.size() > 0:
		errors.append({
			"line": brace_stack[0],
			"error": "Unclosed brace '{' at line " + str(brace_stack[0]) + "."
		})

	if parenthesis_stack.size() > 0:
		errors.append({
			"line": parenthesis_stack[0],
			"error": "Unclosed parenthesis '(' at line " + str(parenthesis_stack[0]) + "."
		})

	if bracket_stack.size() > 0:
		errors.append({
			"line": bracket_stack[0],
			"error": "Unclosed bracket '[' at line " + str(bracket_stack[0]) + "."
		})

	return errors

# Parse modifications from the CODE section
func parse_modifications_from_code(response_text):
	var modifications = []

	# Extract code blocks
	var code_blocks = extract_code_from_response(response_text)

	# If no code blocks found, return empty array
	if code_blocks.size() == 0:
		return modifications

	# Analyze the code to extract modifications
	for code_block in code_blocks:
		var lines = code_block.split("\n")
		var in_node_creation = false
		var current_node_path = ""
		var current_node_type = ""
		var current_node_name = ""
		var current_properties = {}

		for line in lines:
			line = line.strip_edges()

			# Skip comments and empty lines
			if line.begins_with("#") or line.is_empty():
				continue

			# Look for node creation
			if (line.find(".new()") != -1 or (line.find(" = ") != -1 and line.find("new ") != -1)) and not in_node_creation:
				in_node_creation = true

				# Try to extract node type and name
				if line.find(" = ") != -1:
					var parts = line.split(" = ")
					if parts.size() >= 2:
						current_node_name = parts[0].strip_edges()

						# Extract node type
						var type_parts = parts[1].strip_edges().split(".")
						if type_parts.size() >= 1:
							current_node_type = type_parts[0].strip_edges()

							# Remove "new" if present
							if current_node_type.begins_with("new "):
								current_node_type = current_node_type.substr(4).strip_edges()

							# Remove trailing parentheses
							if current_node_type.ends_with("()"):
								current_node_type = current_node_type.substr(0, current_node_type.length() - 2).strip_edges()

				continue

			# Look for add_child calls to determine parent path
			if in_node_creation and line.find(".add_child(") != -1:
				var parts = line.split(".add_child(")
				if parts.size() >= 2:
					var parent_path = parts[0].strip_edges()

					# Extract node reference
					var node_ref = parts[1].strip_edges()
					if node_ref.ends_with(")"):
						node_ref = node_ref.substr(0, node_ref.length() - 1).strip_edges()

					if node_ref == current_node_name:
						# We found a complete node creation sequence
						modifications.append({
							"type": "create_node",
							"parent_path": parent_path,
							"node_type": current_node_type,
							"node_name": current_node_name,
							"properties": current_properties.duplicate()
						})

						# Reset for next node
						in_node_creation = false
						current_node_path = ""
						current_node_type = ""
						current_node_name = ""
						current_properties.clear()

				continue

			# Look for property assignments
			if line.find(".") != -1 and line.find(" = ") != -1:
				var parts = line.split(" = ")
				if parts.size() >= 2:
					var node_ref = parts[0].strip_edges()
					var value = parts[1].strip_edges()

					# Remove trailing semicolon if present
					if value.ends_with(";"):
						value = value.substr(0, value.length() - 1).strip_edges()

					# Try to extract node path and property
					var node_parts = node_ref.split(".")
					if node_parts.size() >= 2:
						var node_path = node_parts[0].strip_edges()
						var property_name = node_parts[1].strip_edges()

						# If we're in the middle of a node creation and this is for the current node
						if in_node_creation and node_path == current_node_name:
							current_properties[property_name] = value
						else:
							# This is a property modification for an existing node
							modifications.append({
								"type": "property",
								"node_path": node_path,
								"property_value": property_name + " = " + value
							})

	return modifications
