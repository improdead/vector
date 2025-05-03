@tool
extends Window

# References to UI elements
var api_key_input: LineEdit
var api_key_container: HBoxContainer
var model_option: OptionButton
var temperature_slider: HSlider
var max_tokens_input: SpinBox
var save_button: Button
var cancel_button: Button
var dev_mode_check: CheckBox

# Settings
var api_key = ""
var model = "gemini-2.5-flash-preview-04-17"  # Using Gemini 2.5 Flash Preview model (not 1.5 Pro)
var temperature = 0.7
var max_output_tokens = 2048
var dev_mode = false

# Reference to settings manager
var settings_manager

func _ready():
	# Get references to UI elements
	api_key_container = $VBoxContainer/GridContainer/APIKeyContainer
	api_key_input = $VBoxContainer/GridContainer/APIKeyContainer/APIKeyInput
	model_option = $VBoxContainer/GridContainer/ModelOption
	temperature_slider = $VBoxContainer/GridContainer/TemperatureSlider
	max_tokens_input = $VBoxContainer/GridContainer/MaxTokensInput
	dev_mode_check = $VBoxContainer/DevModeCheck
	save_button = $VBoxContainer/ButtonContainer/SaveButton
	cancel_button = $VBoxContainer/ButtonContainer/CancelButton

	# Connect signals
	save_button.pressed.connect(_on_save_button_pressed)
	cancel_button.pressed.connect(_on_cancel_button_pressed)
	dev_mode_check.toggled.connect(_on_dev_mode_toggled)

	# Get the reset button
	var reset_button = $VBoxContainer/ButtonContainer/ResetButton
	reset_button.pressed.connect(_on_reset_button_pressed)

	# Load settings
	_load_settings()

	# Populate UI with settings
	api_key_input.text = api_key
	dev_mode_check.button_pressed = dev_mode

	# Show/hide API key input based on dev mode
	api_key_container.visible = dev_mode

	# Populate model options
	model_option.clear()
	model_option.add_item("gemini-2.5-flash-preview-04-17")  # Prioritize Gemini 2.5 Flash
	model_option.add_item("gemini-2.5-pro-preview-03-25")
	model_option.add_item("gemini-2.0-flash")
	# Add Gemini 1.5 Pro at the end (least preferred)
	model_option.add_item("gemini-1.5-pro")

	# Select the current model
	for i in range(model_option.get_item_count()):
		if model_option.get_item_text(i) == model:
			model_option.select(i)
			break

	temperature_slider.value = temperature
	max_tokens_input.value = max_output_tokens

func _load_settings():
	# Try to find the settings manager in different places
	# First, try to find it in the parent
	settings_manager = get_parent().get_node_or_null("SettingsManager")

	# If not found, try to find it in the parent's parent
	if not settings_manager and get_parent() and get_parent().get_parent():
		settings_manager = get_parent().get_parent().get_node_or_null("SettingsManager")

	# If still not found, try to find it in the scene root
	if not settings_manager:
		var scene_root = get_tree().get_root()
		if scene_root:
			settings_manager = scene_root.get_node_or_null("SettingsManager")

	if not settings_manager:
		push_error("Settings manager not found!")
		# Fall back to direct file loading
		_load_settings_from_file()
		return

	# Load settings from the manager
	var settings = settings_manager.settings

	# Apply settings
	if settings.has("api_key"):
		api_key = settings.api_key
	if settings.has("model"):
		model = settings.model
		print("Settings dialog loaded model: " + model)
	if settings.has("temperature"):
		temperature = settings.temperature
	if settings.has("max_output_tokens"):
		max_output_tokens = settings.max_output_tokens
	if settings.has("dev_mode"):
		dev_mode = settings.dev_mode

# Fallback method for loading settings directly from file
func _load_settings_from_file():
	var settings_path = "res://addons/vector_ai/settings.json"
	var settings_file = FileAccess.open(settings_path, FileAccess.READ)

	if settings_file:
		var settings_text = settings_file.get_as_text()
		settings_file.close()

		var json = JSON.new()
		var error = json.parse(settings_text)

		if error == OK:
			var settings = json.get_data()
			if settings.has("api_key"):
				api_key = settings.api_key
			if settings.has("model"):
				model = settings.model
				print("Settings dialog loaded model from file: " + model)
			if settings.has("temperature"):
				temperature = settings.temperature
			if settings.has("max_output_tokens"):
				max_output_tokens = settings.max_output_tokens
			if settings.has("dev_mode"):
				dev_mode = settings.dev_mode

func _save_settings():
	if settings_manager:
		# Save settings using the manager
		settings_manager.set_setting("model", model)
		settings_manager.set_setting("temperature", temperature)
		settings_manager.set_setting("max_output_tokens", max_output_tokens)
		settings_manager.set_setting("dev_mode", dev_mode)

		# Only save API key in dev mode
		if dev_mode:
			settings_manager.set_setting("api_key", api_key)

		print("Settings saved via manager. Model: " + model)
	else:
		# Fall back to direct file saving
		_save_settings_to_file()

# Fallback method for saving settings directly to file
func _save_settings_to_file():
	var settings = {
		"model": model,
		"temperature": temperature,
		"max_output_tokens": max_output_tokens,
		"dev_mode": dev_mode
	}

	# Only save API key in dev mode
	if dev_mode:
		settings["api_key"] = api_key

	var settings_path = "res://addons/vector_ai/settings.json"
	var settings_file = FileAccess.open(settings_path, FileAccess.WRITE)

	if settings_file:
		settings_file.store_string(JSON.stringify(settings, "  "))
		settings_file.close()
		print("Settings saved to file. Model: " + model)

func _on_save_button_pressed():
	# Get values from UI
	if dev_mode:
		api_key = api_key_input.text

	# Get the selected model
	model = model_option.get_item_text(model_option.selected)
	print("Saving selected model: " + model)

	temperature = temperature_slider.value
	max_output_tokens = int(max_tokens_input.value)

	# Save settings
	_save_settings()

	# Force a reload of settings in all components
	if settings_manager:
		settings_manager.settings_changed.emit()

	# Close dialog
	queue_free()

func _on_cancel_button_pressed():
	# Close dialog without saving
	queue_free()

func _on_dev_mode_toggled(toggled_on):
	dev_mode = toggled_on
	api_key_container.visible = toggled_on

func _on_reset_button_pressed():
	# Reset to default settings
	if settings_manager:
		settings_manager.reset_to_default()

		# Force the model to Gemini 2.5 Flash
		settings_manager.force_gemini_25_flash()

		# Reload settings
		_load_settings()

		# Update UI
		api_key_input.text = api_key
		dev_mode_check.button_pressed = dev_mode

		# Select the model
		for i in range(model_option.get_item_count()):
			if model_option.get_item_text(i) == model:
				model_option.select(i)
				break

		temperature_slider.value = temperature
		max_tokens_input.value = max_output_tokens

		print("Settings reset to default. Model: " + model)
	else:
		# Fall back to direct reset
		model = "gemini-2.5-flash-preview-04-17"
		temperature = 0.7
		max_output_tokens = 2048

		# Update UI
		for i in range(model_option.get_item_count()):
			if model_option.get_item_text(i) == model:
				model_option.select(i)
				break

		temperature_slider.value = temperature
		max_tokens_input.value = max_output_tokens

		print("Settings reset to default (fallback). Model: " + model)
