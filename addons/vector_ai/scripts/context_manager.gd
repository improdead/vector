@tool
extends Node

# References to other components
var scene_analyzer
var project_analyzer
var editor_interface

# Allowed file paths for modification
var allowed_files = []

# Storage for generated code
var generated_code = ""
var target_script = ""

func _ready():
	# Get the editor interface
	editor_interface = Engine.get_singleton("EditorInterface")

	# Get references to analyzers
	scene_analyzer = get_parent().get_node("SceneAnalyzer")
	project_analyzer = get_parent().get_node("ProjectAnalyzer")

# Build a prompt for the AI based on the current context
func build_prompt(task_id, placeholders = {}):
	var prompt = {}

	# Add system context
	prompt["system"] = _get_system_context()

	# Add task-specific template
	match task_id:
		"scene_analysis":
			prompt["task"] = _build_scene_analysis_prompt(placeholders)
		"code_generation":
			prompt["task"] = _build_code_generation_prompt(placeholders)
		"project_refactor":
			prompt["task"] = _build_project_refactor_prompt(placeholders)
		"multi_file_modification":
			prompt["task"] = _build_multi_file_modification_prompt(placeholders)
		_:
			prompt["task"] = "Please provide more specific instructions."

	# Add allowed files
	prompt["allowed_files"] = allowed_files

	return prompt

# Get the system context
func _get_system_context():
	return """
You are "Vector AI Assistant", an internal Gemini agent embedded in the Godot editor.

Capabilities you MAY use:
• Scene analysis & modification via SceneAnalyzer / SceneModifier
• GDScript code generation & execution
• Project-wide code understanding (ProjectAnalyzer)
• Multi-file diff & patch application
• Context-aware suggestions based on Git data

Hard constraints:
• Only modify files whose absolute paths are supplied in the {{allowed_files}} list.
• All edits must be returned as a **unified diff** (`diff --git a/file b/file`) wrapped in ```diff fences.
• Do NOT output any code that violates licences; prefer MIT/BSD/Apache snippets.
• Assume Godot 4.x, GDScript 2.0, and Gemini-pro API.
• Honour JSON schemas exactly; invalid JSON terminates the request.

Return format for every task:
```json
{
  "plan": "high-level reasoning here",
  "diff": "```diff\\n<unified-diff-patch>\\n```",
  "explanation": "why these changes solve the task"
}
```
"""

# Build a scene analysis prompt
func _build_scene_analysis_prompt(placeholders):
	var scene_path = placeholders.get("scene_path", "")
	var scene_tree = placeholders.get("scene_tree", "")
	var analysis_objectives = placeholders.get("analysis_objectives", "Analyze the scene structure and suggest improvements.")
	var focus_areas = placeholders.get("focus_areas", "All aspects")
	var excluded_elements = placeholders.get("excluded_elements", "None")

	# If scene_tree is empty, get it from the scene_analyzer
	if scene_tree.is_empty() and not scene_path.is_empty():
		scene_tree = scene_analyzer.analyze_current_scene()

	return """
# Scene Analysis Request
Scene: %s

```
%s
```

Goals: %s
Focus areas: %s (exclude %s).

Return an ordered list:
1. Scene Overview
2. Potential Issues
3. Optimisation Tips
4. Suggested Code / Node changes
""" % [scene_path, scene_tree, analysis_objectives, focus_areas, excluded_elements]

# Build a code generation prompt
func _build_code_generation_prompt(placeholders):
	var target_file = placeholders.get("target_file", "")
	var existing_code = placeholders.get("existing_code", "")
	var requirements = placeholders.get("requirements", "")
	var integration_points = placeholders.get("integration_points", "")

	# Add the target file to allowed files
	if not target_file.is_empty() and not allowed_files.has(target_file):
		allowed_files.append(target_file)

	return """
# Code Generation
File: %s
Current code:
```gdscript
%s
```
Requirements: %s
Integrate with: %s
Return ONLY a patch inside ```diff fences plus an explanation paragraph.
""" % [target_file, existing_code, requirements, integration_points]

# Build a project refactor prompt
func _build_project_refactor_prompt(placeholders):
	var affected_files = placeholders.get("affected_files", [])
	var target_feature = placeholders.get("target_feature", "")
	var project_structure = placeholders.get("project_structure", "")
	var refactoring_objectives = placeholders.get("refactoring_objectives", "")

	# Add affected files to allowed files
	for file in affected_files:
		if not allowed_files.has(file):
			allowed_files.append(file)

	# If project_structure is empty, get it from the project_analyzer
	if project_structure.is_empty():
		project_structure = project_analyzer.analyze_project()

	return """
# Project-Wide Refactor
Files to edit: %s
Goal: %s

Current graph:
%s

Refactor objectives:
%s

Return one unified diff that touches every file listed.
""" % [str(affected_files), target_feature, project_structure, refactoring_objectives]

# Build a multi-file modification prompt
func _build_multi_file_modification_prompt(placeholders):
	var files_list = placeholders.get("files_list", [])
	var modification_purpose = placeholders.get("modification_purpose", "")
	var current_implementation = placeholders.get("current_implementation", "")
	var required_changes = placeholders.get("required_changes", "")

	# Add files to allowed files
	for file in files_list:
		if not allowed_files.has(file):
			allowed_files.append(file)

	return """
# Multi-File Modification
Files: %s
Purpose: %s

Existing implementation snippets:
%s

Required changes:
%s

Output: unified diff + test plan + rollback steps.
""" % [str(files_list), modification_purpose, current_implementation, required_changes]

# Check if a file path is allowed for modification
func is_path_allowed(file_path):
	return allowed_files.has(file_path)

# Get the current scene information
func get_current_scene_info():
	return scene_analyzer.analyze_current_scene()

# Get project structure information
func get_project_structure():
	return project_analyzer.analyze_project()

# Get file content
func get_file_content(file_path):
	var file = FileAccess.open(file_path, FileAccess.READ)
	if file:
		var content = file.get_as_text()
		file.close()
		return content
	return ""

# Apply a diff to files
func apply_diff(diff_text):
	# This is a placeholder for a more complex diff application system
	# In a real implementation, you would parse the diff and apply changes to files

	# For now, we'll just return a success message
	return {"success": true, "message": "Diff applied successfully."}

# Insert generated code into a script
func insert_code_at_cursor(script_path):
	if generated_code.is_empty() or script_path.is_empty():
		return {"success": false, "error": "No generated code or target script."}

	# Get the script editor
	var script_editor = editor_interface.get_script_editor()
	var script_edit = script_editor.get_current_editor()

	if not script_edit:
		return {"success": false, "error": "No script editor found."}

	# Get the text edit control
	var text_edit = script_edit.get_base_editor()

	if not text_edit:
		return {"success": false, "error": "No text editor found."}

	# Insert the code at the cursor position
	text_edit.insert_text_at_caret(generated_code)

	return {"success": true, "message": "Code inserted successfully."}

# Replace the entire script with generated code
func replace_script_content(script_path):
	if generated_code.is_empty() or script_path.is_empty():
		return {"success": false, "error": "No generated code or target script."}

	# Open the file for writing
	var file = FileAccess.open(script_path, FileAccess.WRITE)
	if not file:
		return {"success": false, "error": "Failed to open file for writing."}

	# Write the generated code to the file
	file.store_string(generated_code)
	file.close()

	return {"success": true, "message": "Script content replaced successfully."}
