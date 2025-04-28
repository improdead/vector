/**************************************************************************/
/*  vector_ai_dock.h                                                      */
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

#pragma once

#include "scene/gui/box_container.h"
#include "scene/gui/button.h"
#include "scene/gui/check_box.h"
#include "scene/gui/line_edit.h"
#include "scene/gui/option_button.h"
#include "scene/gui/rich_text_label.h"
#include "scene/gui/text_edit.h"
#include "scene/gui/panel_container.h"
#include "scene/gui/popup.h"
#include "scene/gui/spin_box.h"
#include "scene/gui/slider.h"
#include "scene/gui/window.h"

#include "gemini_client.h"
#include "scene_analyzer.h"
#include "scene_modifier.h"

class VectorAIDock : public VBoxContainer {
    GDCLASS(VectorAIDock, VBoxContainer);

private:
    // UI elements
    RichTextLabel *chat_history = nullptr;
    TextEdit *input_field = nullptr;
    Button *send_button = nullptr;
    Button *settings_button = nullptr;
    Button *clear_button = nullptr;

    // Components
    GeminiClient *gemini_client = nullptr;
    SceneAnalyzer *scene_analyzer = nullptr;
    SceneModifier *scene_modifier = nullptr;

    // Settings window
    Window *settings_window = nullptr;
    LineEdit *api_key_input = nullptr;
    CheckBox *dev_mode_check = nullptr;
    OptionButton *model_option = nullptr;
    HSlider *temperature_slider = nullptr;
    SpinBox *max_tokens_input = nullptr;

    // Chat history
    Vector<Dictionary> messages;

    void _setup_ui();
    void _setup_settings_window();
    void _load_settings();
    void _save_settings();

    void _on_send_button_pressed();
    void _on_input_field_text_submitted(const String &p_text);
    void _on_settings_button_pressed();
    void _on_clear_button_pressed();
    void _on_save_settings_pressed();
    void _on_cancel_settings_pressed();
    void _on_dev_mode_toggled(bool p_toggled);
    void _on_gemini_response(const Dictionary &p_response, const String &p_error);

    void _add_user_message(const String &p_text);
    void _add_ai_message(const String &p_text);
    void _add_system_message(const String &p_text);

protected:
    void _notification(int p_what);
    static void _bind_methods();

public:
    VectorAIDock();
    ~VectorAIDock();
};
