/**************************************************************************/
/*  vector_ai_dock.cpp                                                    */
/**************************************************************************/
/*                         This file is part of:                          */
/*                             GODOT ENGINE                               */
/*                        https://godotengine.org                         */
/**************************************************************************/
/* Copyright (c) 2014-present Godot Engine contributors (see AUTHORS.md). */
/* Copyright (c) 2007-2014 Juan Linietsky, Ariel Manzur.                  */
/*                                                                        */
/* Permission is hereby granted, free of charge, to any person obtaining  */
/* a copy of this software and associated documentation files (the        */
/* "Software"), to deal in the Software without restriction, including    */
/* without limitation the rights to use, copy, modify, merge, publish,    */
/* distribute, sublicense, and/or sell copies of the Software, and to     */
/* permit persons to whom the Software is furnished to do so, subject to  */
/* the following conditions:                                              */
/*                                                                        */
/* The above copyright notice and this permission notice shall be         */
/* included in all copies or substantial portions of the Software.        */
/*                                                                        */
/* THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND,        */
/* EXPRESS OR IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF     */
/* MERCHANTABILITY, FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. */
/* IN NO EVENT SHALL THE AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY   */
/* CLAIM, DAMAGES OR OTHER LIABILITY, WHETHER IN AN ACTION OF CONTRACT,   */
/* TORT OR OTHERWISE, ARISING FROM, OUT OF OR IN CONNECTION WITH THE      */
/* SOFTWARE OR THE USE OR OTHER DEALINGS IN THE SOFTWARE.                 */
/**************************************************************************/

#include "vector_ai_dock.h"

#include "editor/editor_node.h"
#include "editor/editor_scale.h"
#include "scene/gui/label.h"
#include "scene/gui/separator.h"

void VectorAIDock::_notification(int p_what) {
    switch (p_what) {
        case NOTIFICATION_READY: {
            _setup_ui();
            _setup_settings_window();
            _load_settings();
            _add_system_message("Welcome to Vector AI! I can help you modify your Godot scenes based on natural language prompts. Type your request and press Enter or click Send.");
        } break;
    }
}

void VectorAIDock::_bind_methods() {
    ClassDB::bind_method(D_METHOD("_on_send_button_pressed"), &VectorAIDock::_on_send_button_pressed);
    ClassDB::bind_method(D_METHOD("_on_input_field_text_submitted"), &VectorAIDock::_on_input_field_text_submitted);
    ClassDB::bind_method(D_METHOD("_on_settings_button_pressed"), &VectorAIDock::_on_settings_button_pressed);
    ClassDB::bind_method(D_METHOD("_on_clear_button_pressed"), &VectorAIDock::_on_clear_button_pressed);
    ClassDB::bind_method(D_METHOD("_on_save_settings_pressed"), &VectorAIDock::_on_save_settings_pressed);
    ClassDB::bind_method(D_METHOD("_on_cancel_settings_pressed"), &VectorAIDock::_on_cancel_settings_pressed);
    ClassDB::bind_method(D_METHOD("_on_dev_mode_toggled"), &VectorAIDock::_on_dev_mode_toggled);
    ClassDB::bind_method(D_METHOD("_on_gemini_response"), &VectorAIDock::_on_gemini_response);
}

void VectorAIDock::_setup_ui() {
    set_name("Vector AI");
    set_v_size_flags(SIZE_EXPAND_FILL);

    // Create a stylish dark-futuristic theme container
    Panel *background_panel = memnew(Panel);
    background_panel->set_anchors_preset(Control::PRESET_FULL_RECT);
    add_child(background_panel);

    // Main container
    VBoxContainer *main_container = memnew(VBoxContainer);
    main_container->set_anchors_preset(Control::PRESET_FULL_RECT);
    main_container->set_margin(SIDE_LEFT, 10 * EDSCALE);
    main_container->set_margin(SIDE_TOP, 10 * EDSCALE);
    main_container->set_margin(SIDE_RIGHT, 10 * EDSCALE);
    main_container->set_margin(SIDE_BOTTOM, 10 * EDSCALE);
    background_panel->add_child(main_container);

    // Top bar with title and buttons
    HBoxContainer *top_bar = memnew(HBoxContainer);
    main_container->add_child(top_bar);

    // Stylish title with icon
    HBoxContainer *title_container = memnew(HBoxContainer);
    title_container->set_h_size_flags(SIZE_EXPAND_FILL);
    top_bar->add_child(title_container);

    Label *title_label = memnew(Label);
    title_label->set_text("VECTOR AI");
    title_label->add_theme_font_override("font", EditorNode::get_singleton()->get_editor_theme()->get_font("title", "EditorFonts"));
    title_label->add_theme_color_override("font_color", Color(0.0, 0.7, 1.0)); // Neon blue
    title_label->set_h_size_flags(SIZE_EXPAND_FILL);
    title_container->add_child(title_label);

    // Buttons with futuristic styling
    settings_button = memnew(Button);
    settings_button->set_text("⚙");
    settings_button->set_tooltip_text("Settings");
    settings_button->connect("pressed", callable_mp(this, &VectorAIDock::_on_settings_button_pressed));
    top_bar->add_child(settings_button);

    clear_button = memnew(Button);
    clear_button->set_text("🗑");
    clear_button->set_tooltip_text("Clear Chat");
    clear_button->connect("pressed", callable_mp(this, &VectorAIDock::_on_clear_button_pressed));
    top_bar->add_child(clear_button);

    // Separator with glow effect
    HSeparator *separator = memnew(HSeparator);
    separator->add_theme_color_override("color", Color(0.0, 0.7, 1.0, 0.3)); // Neon blue with transparency
    main_container->add_child(separator);

    // Chat history with custom styling
    chat_history = memnew(RichTextLabel);
    chat_history->set_v_size_flags(SIZE_EXPAND_FILL);
    chat_history->set_use_bbcode(true);
    chat_history->set_scroll_follow(true);
    chat_history->add_theme_color_override("default_color", Color(0.9, 0.9, 0.95)); // Light text for readability
    chat_history->add_theme_stylebox_override("normal", EditorNode::get_singleton()->get_editor_theme()->get_stylebox("panel", "Tree"));
    main_container->add_child(chat_history);

    // Input area with futuristic styling
    HBoxContainer *input_container = memnew(HBoxContainer);
    input_container->set_custom_minimum_size(Vector2(0, 40 * EDSCALE));
    main_container->add_child(input_container);

    input_field = memnew(TextEdit);
    input_field->set_h_size_flags(SIZE_EXPAND_FILL);
    input_field->set_placeholder("Ask Vector AI to modify your scene...");
    input_field->set_wrap_mode(TextEdit::LineWrappingMode::LINE_WRAPPING_BOUNDARY);
    input_field->set_auto_translate(false);
    input_field->connect("text_changed", callable_mp(this, &VectorAIDock::_on_input_field_text_submitted));
    input_field->add_theme_color_override("font_color", Color(0.9, 0.9, 0.95)); // Light text
    input_field->add_theme_color_override("font_placeholder_color", Color(0.5, 0.5, 0.6)); // Subtle placeholder
    input_container->add_child(input_field);

    send_button = memnew(Button);
    send_button->set_text("Send");
    send_button->add_theme_color_override("font_color", Color(0.0, 0.7, 1.0)); // Neon blue
    send_button->add_theme_color_override("font_hover_color", Color(0.2, 0.8, 1.0)); // Brighter blue on hover
    send_button->connect("pressed", callable_mp(this, &VectorAIDock::_on_send_button_pressed));
    input_container->add_child(send_button);

    // Initialize components
    gemini_client = memnew(GeminiClient);
    scene_analyzer = memnew(SceneAnalyzer);
    scene_modifier = memnew(SceneModifier);

    add_child(gemini_client);
    add_child(scene_analyzer);
    add_child(scene_modifier);
}

void VectorAIDock::_setup_settings_window() {
    settings_window = memnew(Window);
    settings_window->set_title("Vector AI Settings");
    settings_window->set_exclusive(true);
    settings_window->set_size(Vector2(500, 350) * EDSCALE);
    add_child(settings_window);

    // Background panel for dark theme
    Panel *settings_bg = memnew(Panel);
    settings_bg->set_anchors_preset(Control::PRESET_FULL_RECT);
    settings_window->add_child(settings_bg);

    VBoxContainer *settings_vbox = memnew(VBoxContainer);
    settings_vbox->set_anchors_preset(Control::PRESET_FULL_RECT);
    settings_vbox->set_margin(SIDE_LEFT, 15 * EDSCALE);
    settings_vbox->set_margin(SIDE_TOP, 15 * EDSCALE);
    settings_vbox->set_margin(SIDE_RIGHT, 15 * EDSCALE);
    settings_vbox->set_margin(SIDE_BOTTOM, 15 * EDSCALE);
    settings_bg->add_child(settings_vbox);

    // Stylish header
    Label *settings_label = memnew(Label);
    settings_label->set_text("VECTOR AI SETTINGS");
    settings_label->add_theme_font_override("font", EditorNode::get_singleton()->get_editor_theme()->get_font("title", "EditorFonts"));
    settings_label->add_theme_color_override("font_color", Color(0.0, 0.7, 1.0)); // Neon blue
    settings_label->set_horizontal_alignment(HORIZONTAL_ALIGNMENT_CENTER);
    settings_vbox->add_child(settings_label);

    // Glowing separator
    HSeparator *separator1 = memnew(HSeparator);
    separator1->add_theme_color_override("color", Color(0.0, 0.7, 1.0, 0.3)); // Neon blue with transparency
    settings_vbox->add_child(separator1);

    // Settings grid with spacing
    GridContainer *settings_grid = memnew(GridContainer);
    settings_grid->set_columns(2);
    settings_grid->set_v_size_flags(SIZE_EXPAND_FILL);
    settings_grid->add_theme_constant_override("h_separation", 15 * EDSCALE);
    settings_grid->add_theme_constant_override("v_separation", 10 * EDSCALE);
    settings_vbox->add_child(settings_grid);

    // Developer mode checkbox with futuristic styling
    dev_mode_check = memnew(CheckBox);
    dev_mode_check->set_text("Developer Mode (Use direct API access)");
    dev_mode_check->add_theme_color_override("font_color", Color(0.9, 0.9, 0.95)); // Light text
    dev_mode_check->add_theme_color_override("font_color_hover", Color(0.0, 0.7, 1.0)); // Neon blue on hover
    dev_mode_check->connect("toggled", callable_mp(this, &VectorAIDock::_on_dev_mode_toggled));
    settings_vbox->add_child(dev_mode_check);

    // API Key with futuristic styling
    Label *api_key_label = memnew(Label);
    api_key_label->set_text("Gemini API Key:");
    api_key_label->add_theme_color_override("font_color", Color(0.9, 0.9, 0.95)); // Light text
    settings_grid->add_child(api_key_label);

    HBoxContainer *api_key_container = memnew(HBoxContainer);
    api_key_container->set_h_size_flags(SIZE_EXPAND_FILL);
    settings_grid->add_child(api_key_container);

    api_key_input = memnew(LineEdit);
    api_key_input->set_h_size_flags(SIZE_EXPAND_FILL);
    api_key_input->set_placeholder("Enter your Gemini API key");
    api_key_input->set_secret(true);
    api_key_input->add_theme_color_override("font_color", Color(0.9, 0.9, 0.95)); // Light text
    api_key_input->add_theme_color_override("font_placeholder_color", Color(0.5, 0.5, 0.6)); // Subtle placeholder
    api_key_container->add_child(api_key_input);

    // Model selection with futuristic styling
    Label *model_label = memnew(Label);
    model_label->set_text("Model:");
    model_label->add_theme_color_override("font_color", Color(0.9, 0.9, 0.95)); // Light text
    settings_grid->add_child(model_label);

    model_option = memnew(OptionButton);
    model_option->set_h_size_flags(SIZE_EXPAND_FILL);
    model_option->add_item("gemini-1.5-pro");
    model_option->add_item("gemini-1.5-flash");
    model_option->add_item("gemini-1.0-pro");
    model_option->add_theme_color_override("font_color", Color(0.9, 0.9, 0.95)); // Light text
    model_option->add_theme_color_override("font_hover_color", Color(0.0, 0.7, 1.0)); // Neon blue on hover
    settings_grid->add_child(model_option);

    // Temperature with futuristic styling
    Label *temperature_label = memnew(Label);
    temperature_label->set_text("Temperature:");
    temperature_label->add_theme_color_override("font_color", Color(0.9, 0.9, 0.95)); // Light text
    settings_grid->add_child(temperature_label);

    VBoxContainer *temp_container = memnew(VBoxContainer);
    temp_container->set_h_size_flags(SIZE_EXPAND_FILL);
    settings_grid->add_child(temp_container);

    temperature_slider = memnew(HSlider);
    temperature_slider->set_h_size_flags(SIZE_EXPAND_FILL);
    temperature_slider->set_min(0.1);
    temperature_slider->set_max(1.0);
    temperature_slider->set_step(0.1);
    temperature_slider->set_value(0.7);
    temperature_slider->add_theme_color_override("grabber_highlight_color", Color(0.0, 0.7, 1.0)); // Neon blue highlight
    temp_container->add_child(temperature_slider);

    Label *temp_value = memnew(Label);
    temp_value->set_text("0.7 (Higher = more creative, Lower = more precise)");
    temp_value->set_horizontal_alignment(HORIZONTAL_ALIGNMENT_CENTER);
    temp_value->add_theme_color_override("font_color", Color(0.7, 0.7, 0.75)); // Subtle text
    temp_value->add_theme_font_size_override("font_size", 12 * EDSCALE); // Smaller font
    temp_container->add_child(temp_value);

    // Max tokens with futuristic styling
    Label *max_tokens_label = memnew(Label);
    max_tokens_label->set_text("Max Output Tokens:");
    max_tokens_label->add_theme_color_override("font_color", Color(0.9, 0.9, 0.95)); // Light text
    settings_grid->add_child(max_tokens_label);

    max_tokens_input = memnew(SpinBox);
    max_tokens_input->set_h_size_flags(SIZE_EXPAND_FILL);
    max_tokens_input->set_min(1);
    max_tokens_input->set_max(8192);
    max_tokens_input->set_value(2048);
    max_tokens_input->add_theme_color_override("font_color", Color(0.9, 0.9, 0.95)); // Light text
    settings_grid->add_child(max_tokens_input);

    // Glowing separator
    HSeparator *separator2 = memnew(HSeparator);
    separator2->add_theme_color_override("color", Color(0.0, 0.7, 1.0, 0.3)); // Neon blue with transparency
    settings_vbox->add_child(separator2);

    // Buttons with futuristic styling
    HBoxContainer *button_container = memnew(HBoxContainer);
    button_container->set_alignment(BoxContainer::ALIGNMENT_CENTER);
    button_container->add_theme_constant_override("separation", 20 * EDSCALE);
    settings_vbox->add_child(button_container);

    Button *save_button = memnew(Button);
    save_button->set_text("SAVE");
    save_button->set_custom_minimum_size(Vector2(120, 40) * EDSCALE);
    save_button->add_theme_color_override("font_color", Color(0.0, 0.7, 1.0)); // Neon blue
    save_button->add_theme_color_override("font_hover_color", Color(0.2, 0.8, 1.0)); // Brighter blue on hover
    save_button->connect("pressed", callable_mp(this, &VectorAIDock::_on_save_settings_pressed));
    button_container->add_child(save_button);

    Button *cancel_button = memnew(Button);
    cancel_button->set_text("CANCEL");
    cancel_button->set_custom_minimum_size(Vector2(120, 40) * EDSCALE);
    cancel_button->connect("pressed", callable_mp(this, &VectorAIDock::_on_cancel_settings_pressed));
    button_container->add_child(cancel_button);
}

void VectorAIDock::_load_settings() {
    Dictionary settings = gemini_client->load_settings();

    if (settings.has("dev_mode")) {
        dev_mode_check->set_pressed(settings["dev_mode"]);
    }

    if (settings.has("api_key")) {
        api_key_input->set_text(settings["api_key"]);
    }

    if (settings.has("model")) {
        String model = settings["model"];
        for (int i = 0; i < model_option->get_item_count(); i++) {
            if (model_option->get_item_text(i) == model) {
                model_option->select(i);
                break;
            }
        }
    }

    if (settings.has("temperature")) {
        temperature_slider->set_value(settings["temperature"]);
    }

    if (settings.has("max_output_tokens")) {
        max_tokens_input->set_value(settings["max_output_tokens"]);
    }

    // Update UI based on dev mode
    api_key_input->get_parent()->set_visible(dev_mode_check->is_pressed());
}

void VectorAIDock::_save_settings() {
    Dictionary settings;

    settings["dev_mode"] = dev_mode_check->is_pressed();

    if (dev_mode_check->is_pressed()) {
        settings["api_key"] = api_key_input->get_text();
    }

    settings["model"] = model_option->get_item_text(model_option->get_selected());
    settings["temperature"] = temperature_slider->get_value();
    settings["max_output_tokens"] = (int)max_tokens_input->get_value();

    gemini_client->save_settings(settings);
}

void VectorAIDock::_on_send_button_pressed() {
    String user_input = input_field->get_text().strip_edges();
    if (user_input.is_empty()) {
        return;
    }

    // Add user message to chat history
    _add_user_message(user_input);

    // Clear input field
    input_field->set_text("");

    // Get current scene information
    String scene_info = scene_analyzer->analyze_current_scene();

    // Send request to Gemini API
    gemini_client->send_request(user_input, scene_info, callable_mp(this, &VectorAIDock::_on_gemini_response));
}

void VectorAIDock::_on_input_field_text_submitted(const String &p_text) {
    if (Input::get_singleton()->is_key_pressed(Key::ENTER) && !Input::get_singleton()->is_key_pressed(Key::SHIFT)) {
        _on_send_button_pressed();
    }
}

void VectorAIDock::_on_settings_button_pressed() {
    settings_window->popup_centered();
}

void VectorAIDock::_on_clear_button_pressed() {
    messages.clear();
    chat_history->clear();
    _add_system_message("Chat history cleared.");
}

void VectorAIDock::_on_save_settings_pressed() {
    _save_settings();
    settings_window->hide();
}

void VectorAIDock::_on_cancel_settings_pressed() {
    _load_settings();
    settings_window->hide();
}

void VectorAIDock::_on_dev_mode_toggled(bool p_toggled) {
    api_key_input->get_parent()->set_visible(p_toggled);
}

void VectorAIDock::_on_gemini_response(const Dictionary &p_response, const String &p_error) {
    if (!p_error.is_empty()) {
        _add_system_message("Error: " + p_error);
        return;
    }

    // Add AI response to chat history
    _add_ai_message(p_response["text"]);

    // Apply modifications if requested
    if (p_response.has("modifications")) {
        Dictionary result = scene_modifier->apply_modifications(p_response["modifications"]);
        if (result["success"]) {
            _add_system_message("Successfully applied modifications to the scene.");
        } else {
            _add_system_message("Error applying modifications: " + String(result["error"]));
        }
    }
}

void VectorAIDock::_add_user_message(const String &p_text) {
    Dictionary message;
    message["role"] = "user";
    message["text"] = p_text;
    messages.push_back(message);

    chat_history->add_text("\n");

    // User message with futuristic styling
    chat_history->push_table(1);
    chat_history->push_cell();
    chat_history->push_bgcolor(Color(0.15, 0.15, 0.2)); // Slightly lighter background for user messages
    chat_history->push_align(RichTextLabel::ALIGN_LEFT);
    chat_history->push_indent(1);

    chat_history->add_text("\n");
    chat_history->push_bold();
    chat_history->push_color(Color(0.9, 0.9, 0.95)); // Light text color
    chat_history->add_text("You");
    chat_history->pop(); // color
    chat_history->pop(); // bold
    chat_history->add_text("\n");
    chat_history->push_color(Color(0.8, 0.8, 0.9)); // Slightly dimmer for message content
    chat_history->add_text(p_text);
    chat_history->pop(); // color
    chat_history->add_text("\n");

    chat_history->pop(); // indent
    chat_history->pop(); // align
    chat_history->pop(); // bgcolor
    chat_history->pop(); // cell
    chat_history->pop(); // table
}

void VectorAIDock::_add_ai_message(const String &p_text) {
    Dictionary message;
    message["role"] = "ai";
    message["text"] = p_text;
    messages.push_back(message);

    chat_history->add_text("\n");

    // AI message with futuristic styling
    chat_history->push_table(1);
    chat_history->push_cell();
    chat_history->push_bgcolor(Color(0.1, 0.15, 0.2)); // Darker blue-tinted background for AI messages
    chat_history->push_align(RichTextLabel::ALIGN_LEFT);
    chat_history->push_indent(1);

    chat_history->add_text("\n");
    chat_history->push_bold();
    chat_history->push_color(Color(0.0, 0.7, 1.0)); // Neon blue for AI name
    chat_history->add_text("Vector AI");
    chat_history->pop(); // color
    chat_history->pop(); // bold
    chat_history->add_text("\n");
    chat_history->push_color(Color(0.8, 0.8, 0.9)); // Slightly dimmer for message content
    chat_history->add_text(p_text);
    chat_history->pop(); // color
    chat_history->add_text("\n");

    chat_history->pop(); // indent
    chat_history->pop(); // align
    chat_history->pop(); // bgcolor
    chat_history->pop(); // cell
    chat_history->pop(); // table
}

void VectorAIDock::_add_system_message(const String &p_text) {
    chat_history->add_text("\n");

    // System message with futuristic styling
    chat_history->push_align(RichTextLabel::ALIGN_CENTER);
    chat_history->push_table(1);
    chat_history->push_cell();
    chat_history->push_bgcolor(Color(0.1, 0.1, 0.15, 0.5)); // Semi-transparent dark background
    chat_history->push_align(RichTextLabel::ALIGN_CENTER);

    chat_history->add_text("\n");
    chat_history->push_italics();
    chat_history->push_color(Color(0.5, 0.6, 0.7)); // Subtle blue-gray for system messages
    chat_history->add_text(p_text);
    chat_history->pop(); // color
    chat_history->pop(); // italics
    chat_history->add_text("\n");

    chat_history->pop(); // align
    chat_history->pop(); // bgcolor
    chat_history->pop(); // cell
    chat_history->pop(); // table
    chat_history->pop(); // align
}

VectorAIDock::VectorAIDock() {
}

VectorAIDock::~VectorAIDock() {
}
