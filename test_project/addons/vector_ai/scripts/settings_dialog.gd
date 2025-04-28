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
var api_key = "AIzaSyArlvZ3E9fcqcb_nNCnabSj4RRjGbUWE7g"
var model = "gemini-1.5-pro"
var temperature = 0.7
var max_output_tokens = 2048
var dev_mode = true

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

	# Load settings
	_load_settings()

	# Populate UI with settings
	api_key_input.text = api_key
	dev_mode_check.button_pressed = dev_mode

	# Show/hide API key input based on dev mode
	api_key_container.visible = dev_mode

	# Populate model options
	model_option.clear()
	model_option.add_item("gemini-1.5-pro")
	model_option.add_item("gemini-1.5-flash")

	# Select the current model
	for i in range(model_option.get_item_count()):
		if model_option.get_item_text(i) == model:
			model_option.select(i)
			break

	temperature_slider.value = temperature
	max_tokens_input.value = max_output_tokens

func _load_settings():
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
			if settings.has("temperature"):
				temperature = settings.temperature
			if settings.has("max_output_tokens"):
				max_output_tokens = settings.max_output_tokens
			if settings.has("dev_mode"):
				dev_mode = settings.dev_mode

func _save_settings():
	var settings = {
		"api_key": api_key,
		"model": model,
		"temperature": temperature,
		"max_output_tokens": max_output_tokens,
		"dev_mode": dev_mode
	}

	var settings_path = "res://addons/vector_ai/settings.json"
	var settings_file = FileAccess.open(settings_path, FileAccess.WRITE)

	if settings_file:
		settings_file.store_string(JSON.stringify(settings, "  "))
		settings_file.close()

func _on_save_button_pressed():
	# Get values from UI
	if dev_mode:
		api_key = api_key_input.text
	model = model_option.get_item_text(model_option.selected)
	temperature = temperature_slider.value
	max_output_tokens = int(max_tokens_input.value)

	# Save settings
	_save_settings()

	# Close dialog
	queue_free()

func _on_cancel_button_pressed():
	# Close dialog without saving
	queue_free()

func _on_dev_mode_toggled(toggled_on):
	dev_mode = toggled_on
	api_key_container.visible = toggled_on
