/**************************************************************************/
/*  scene_analyzer.cpp                                                    */
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

#include "scene_analyzer.h"

#include "editor/editor_node.h"
#include "scene/2d/sprite_2d.h"
#include "scene/2d/collision_shape_2d.h"
#include "scene/2d/camera_2d.h"
#include "scene/2d/animated_sprite_2d.h"
#include "scene/gui/label.h"
#include "scene/gui/button.h"
#include "scene/audio/audio_stream_player.h"
#include "scene/resources/texture.h"

void SceneAnalyzer::_bind_methods() {
    ClassDB::bind_method(D_METHOD("analyze_current_scene"), &SceneAnalyzer::analyze_current_scene);
}

String SceneAnalyzer::analyze_current_scene() {
    // Get the current scene root
    Node *current_scene = EditorNode::get_singleton()->get_edited_scene();
    
    if (!current_scene) {
        return "No scene is currently open in the editor.";
    }
    
    // Analyze the scene
    String scene_info = "Scene Name: " + current_scene->get_name() + "\n";
    scene_info += "Scene Path: " + current_scene->get_scene_file_path() + "\n\n";
    scene_info += "Node Structure:\n";
    
    // Recursively analyze the scene
    scene_info += _analyze_node(current_scene, 0);
    
    return scene_info;
}

String SceneAnalyzer::_analyze_node(Node *p_node, int p_indent_level) {
    if (!p_node) {
        return "";
    }
    
    String indent = String("  ").repeat(p_indent_level);
    String node_info = indent + "- " + p_node->get_name() + " (" + p_node->get_class() + ")\n";
    
    // Add node properties
    Dictionary properties = _get_node_properties(p_node);
    if (properties.size() > 0) {
        node_info += indent + "  Properties:\n";
        
        Array keys = properties.keys();
        for (int i = 0; i < keys.size(); i++) {
            String property = keys[i];
            Variant value = properties[property];
            node_info += indent + "    " + property + ": " + String(value) + "\n";
        }
    }
    
    // Recursively analyze child nodes
    for (int i = 0; i < p_node->get_child_count(); i++) {
        node_info += _analyze_node(p_node->get_child(i), p_indent_level + 1);
    }
    
    return node_info;
}

Dictionary SceneAnalyzer::_get_node_properties(Node *p_node) {
    Dictionary properties;
    
    if (!p_node) {
        return properties;
    }
    
    // Common properties for all nodes
    properties["visible"] = p_node->is_visible();
    
    // Type-specific properties
    String class_name = p_node->get_class();
    
    if (class_name == "Sprite2D") {
        Sprite2D *sprite = Object::cast_to<Sprite2D>(p_node);
        if (sprite) {
            properties["position"] = sprite->get_position();
            properties["scale"] = sprite->get_scale();
            properties["rotation"] = sprite->get_rotation();
            properties["modulate"] = sprite->get_modulate();
            
            if (sprite->get_texture().is_valid()) {
                properties["texture"] = sprite->get_texture()->get_path();
            }
        }
    } else if (class_name == "Label") {
        Label *label = Object::cast_to<Label>(p_node);
        if (label) {
            properties["text"] = label->get_text();
            properties["font_size"] = label->get_theme_font_size("font_size");
            properties["horizontal_alignment"] = label->get_horizontal_alignment();
            properties["vertical_alignment"] = label->get_vertical_alignment();
            properties["autowrap_mode"] = label->get_autowrap_mode();
        }
    } else if (class_name == "Button") {
        Button *button = Object::cast_to<Button>(p_node);
        if (button) {
            properties["text"] = button->get_text();
            properties["disabled"] = button->is_disabled();
            properties["toggle_mode"] = button->is_toggle_mode();
            properties["button_pressed"] = button->is_pressed();
        }
    } else if (class_name == "CollisionShape2D") {
        CollisionShape2D *shape = Object::cast_to<CollisionShape2D>(p_node);
        if (shape) {
            properties["position"] = shape->get_position();
            properties["rotation"] = shape->get_rotation();
            properties["disabled"] = shape->is_disabled();
            
            if (shape->get_shape().is_valid()) {
                properties["shape_type"] = shape->get_shape()->get_class();
            }
        }
    } else if (class_name == "Camera2D") {
        Camera2D *camera = Object::cast_to<Camera2D>(p_node);
        if (camera) {
            properties["position"] = camera->get_position();
            properties["zoom"] = camera->get_zoom();
            properties["current"] = camera->is_current();
            properties["offset"] = camera->get_offset();
        }
    } else if (class_name == "AnimatedSprite2D") {
        AnimatedSprite2D *animated_sprite = Object::cast_to<AnimatedSprite2D>(p_node);
        if (animated_sprite) {
            properties["position"] = animated_sprite->get_position();
            properties["scale"] = animated_sprite->get_scale();
            properties["rotation"] = animated_sprite->get_rotation();
            properties["modulate"] = animated_sprite->get_modulate();
            properties["animation"] = animated_sprite->get_animation();
            properties["playing"] = animated_sprite->is_playing();
            properties["speed_scale"] = animated_sprite->get_speed_scale();
        }
    } else if (class_name == "AudioStreamPlayer") {
        AudioStreamPlayer *audio_player = Object::cast_to<AudioStreamPlayer>(p_node);
        if (audio_player) {
            properties["volume_db"] = audio_player->get_volume_db();
            properties["pitch_scale"] = audio_player->get_pitch_scale();
            properties["playing"] = audio_player->is_playing();
            properties["autoplay"] = audio_player->is_autoplay_enabled();
            
            if (audio_player->get_stream().is_valid()) {
                properties["stream"] = audio_player->get_stream()->get_path();
            }
        }
    }
    
    // Add position for Node2D
    if (p_node->is_class("Node2D")) {
        Node2D *node_2d = Object::cast_to<Node2D>(p_node);
        if (node_2d) {
            properties["position"] = node_2d->get_position();
            properties["rotation"] = node_2d->get_rotation();
            properties["scale"] = node_2d->get_scale();
        }
    }
    
    // Add rect for Control
    if (p_node->is_class("Control")) {
        Control *control = Object::cast_to<Control>(p_node);
        if (control) {
            properties["position"] = control->get_position();
            properties["size"] = control->get_size();
            properties["anchors_preset"] = control->get_anchors_preset();
            properties["h_size_flags"] = control->get_h_size_flags();
            properties["v_size_flags"] = control->get_v_size_flags();
        }
    }
    
    return properties;
}

SceneAnalyzer::SceneAnalyzer() {
}

SceneAnalyzer::~SceneAnalyzer() {
}
