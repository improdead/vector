/**************************************************************************/
/*  vector_ai.cpp                                                         */
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

#include "vector_ai.h"

#include "editor/editor_node.h"
#include "editor/editor_scale.h"
#include "scene/gui/button.h"
#include "scene/gui/shortcut.h"

void VectorAI::_notification(int p_what) {
    switch (p_what) {
        case NOTIFICATION_READY: {
            _add_vector_ai_button();
        } break;
    }
}

void VectorAI::_bind_methods() {
    ClassDB::bind_method(D_METHOD("show_dock"), &VectorAI::show_dock);
    ClassDB::bind_method(D_METHOD("hide_dock"), &VectorAI::hide_dock);
    ClassDB::bind_method(D_METHOD("is_dock_visible"), &VectorAI::is_dock_visible);
}

void VectorAI::_add_vector_ai_button() {
    // Create the Vector AI button with futuristic styling
    vector_ai_button = memnew(Button);
    vector_ai_button->set_text("VECTOR AI");
    vector_ai_button->set_tooltip_text("Open Vector AI Sidebar (Ctrl+L)");

    // Apply custom styling to make the button stand out
    vector_ai_button->add_theme_color_override("font_color", Color(0.0, 0.7, 1.0)); // Neon blue
    vector_ai_button->add_theme_color_override("font_hover_color", Color(0.2, 0.8, 1.0)); // Brighter blue on hover
    vector_ai_button->add_theme_color_override("font_pressed_color", Color(0.0, 0.5, 0.8)); // Darker blue when pressed

    // Add a subtle glow effect
    vector_ai_button->set_flat(true);

    // Create keyboard shortcut (Ctrl+L)
    Ref<Shortcut> shortcut = memnew(Shortcut);
    Ref<InputEventKey> key = memnew(InputEventKey);
    key->set_keycode(Key::L);
    key->set_ctrl_pressed(true);
    shortcut->add_event(key);
    vector_ai_button->set_shortcut(shortcut);

    // Connect the button press signal
    vector_ai_button->connect("pressed", callable_mp(this, &VectorAI::_on_vector_ai_button_pressed));

    // Add the button to the editor
    EditorNode::get_singleton()->add_control_to_container(EditorNode::CONTAINER_TOOLBAR, vector_ai_button);

    // Create the Vector AI dock
    dock = memnew(VectorAIDock);
    EditorNode::get_singleton()->add_control_to_dock(EditorNode::DOCK_SLOT_RIGHT_UL, dock);
}

void VectorAI::_on_vector_ai_button_pressed() {
    if (is_dock_visible()) {
        hide_dock();
    } else {
        show_dock();
    }
}

void VectorAI::show_dock() {
    if (dock) {
        dock->set_visible(true);
    }
}

void VectorAI::hide_dock() {
    if (dock) {
        dock->set_visible(false);
    }
}

bool VectorAI::is_dock_visible() const {
    return dock && dock->is_visible();
}

VectorAI::VectorAI() {
}

VectorAI::~VectorAI() {
}
