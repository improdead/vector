@tool
extends EditorPlugin

const VectorAISidebar = preload("res://addons/vector_ai/scenes/sidebar.tscn")
const SettingsManager = preload("res://addons/vector_ai/scripts/settings_manager.gd")

var sidebar_instance
var settings_manager

func _enter_tree():
	# Initialize the settings manager
	settings_manager = SettingsManager.new()
	settings_manager.name = "SettingsManager"
	add_child(settings_manager)

	# Force the model to Gemini 2.5 Flash
	settings_manager.force_gemini_25_flash()

	# Initialize the sidebar
	sidebar_instance = VectorAISidebar.instantiate()

	# Add the settings manager to the sidebar
	sidebar_instance.add_child(settings_manager.duplicate())

	# Add the sidebar to the editor
	add_control_to_dock(DOCK_SLOT_RIGHT_UL, sidebar_instance)

	# Register keyboard shortcut (Ctrl+L)
	var shortcut = Shortcut.new()
	var input_event = InputEventKey.new()
	input_event.keycode = KEY_L
	input_event.ctrl_pressed = true
	shortcut.events = [input_event]

	# Add a button next to the inspector
	var button = Button.new()
	button.text = "Vector AI"
	button.tooltip_text = "Open Vector AI Sidebar (Ctrl+L)"
	button.shortcut = shortcut
	button.pressed.connect(_on_vector_ai_button_pressed)
	add_control_to_container(CONTAINER_INSPECTOR_BOTTOM, button)

func _exit_tree():
	# Clean up the sidebar
	if sidebar_instance:
		remove_control_from_docks(sidebar_instance)
		sidebar_instance.queue_free()

	# Clean up the settings manager
	if settings_manager:
		settings_manager.queue_free()

func _on_vector_ai_button_pressed():
	# Make the sidebar visible
	if sidebar_instance:
		sidebar_instance.visible = true
