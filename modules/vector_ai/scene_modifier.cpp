/**************************************************************************/
/*  scene_modifier.cpp                                                    */
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

#include "scene_modifier.h"

#include "editor/editor_node.h"
#include "editor/editor_undo_redo_manager.h"

void SceneModifier::_bind_methods() {
    ClassDB::bind_method(D_METHOD("apply_modifications", "modifications"), &SceneModifier::apply_modifications);
}

Dictionary SceneModifier::apply_modifications(const Dictionary &p_modifications) {
    Dictionary result;
    result["success"] = false;
    result["error"] = "";
    
    // Get the current scene root
    Node *current_scene = EditorNode::get_singleton()->get_edited_scene();
    
    if (!current_scene) {
        result["error"] = "No scene is currently open in the editor.";
        return result;
    }
    
    // Get the undo/redo manager
    EditorUndoRedoManager *undo_redo = EditorUndoRedoManager::get_singleton();
    
    if (!undo_redo) {
        result["error"] = "Could not access the undo/redo manager.";
        return result;
    }
    
    // Start the undo/redo action
    undo_redo->create_action("Vector AI Modifications");
    
    bool success = true;
    String error_message = "";
    
    // Apply each modification
    if (p_modifications.has("list") && p_modifications["list"].get_type() == Variant::ARRAY) {
        Array modifications = p_modifications["list"];
        
        for (int i = 0; i < modifications.size(); i++) {
            Dictionary modification = modifications[i];
            
            if (!modification.has("node_path") || !modification.has("property_value")) {
                continue;
            }
            
            String node_path = modification["node_path"];
            String property_value = modification["property_value"];
            
            // Find the node
            Node *node = current_scene->get_node_or_null(node_path);
            if (!node) {
                success = false;
                error_message = "Node not found: " + node_path;
                continue;
            }
            
            // Parse the property and value
            Vector<String> parts = property_value.split("=", true, 1);
            if (parts.size() < 2) {
                success = false;
                error_message = "Invalid property format: " + property_value;
                continue;
            }
            
            String property_name = parts[0].strip_edges();
            String property_value_str = parts[1].strip_edges();
            
            // Convert the value to the appropriate type
            Variant value = _parse_value(property_value_str);
            
            // Check if the property exists
            bool property_exists = false;
            List<PropertyInfo> properties;
            node->get_property_list(&properties);
            
            for (List<PropertyInfo>::Element *E = properties.front(); E; E = E->next()) {
                if (E->get().name == property_name) {
                    property_exists = true;
                    break;
                }
            }
            
            if (!property_exists) {
                success = false;
                error_message = "Property not found: " + property_name + " in node " + node_path;
                continue;
            }
            
            // Get the old value
            Variant old_value = node->get(property_name);
            
            // Add the undo/redo operation
            undo_redo->add_do_property(node, property_name, value);
            undo_redo->add_undo_property(node, property_name, old_value);
        }
    }
    
    // Commit the undo/redo action
    undo_redo->commit_action();
    
    // Return the result
    result["success"] = success;
    result["error"] = error_message;
    
    return result;
}

Variant SceneModifier::_parse_value(const String &p_value_str) {
    // Try to parse as a number
    if (p_value_str.is_valid_float()) {
        return p_value_str.to_float();
    }
    
    // Try to parse as a boolean
    if (p_value_str.to_lower() == "true") {
        return true;
    }
    if (p_value_str.to_lower() == "false") {
        return false;
    }
    
    // Try to parse as a Vector2
    if (p_value_str.begins_with("(") && p_value_str.ends_with(")")) {
        String vector_str = p_value_str.substr(1, p_value_str.length() - 2);
        Vector<String> components = vector_str.split(",");
        if (components.size() == 2) {
            float x = components[0].strip_edges().to_float();
            float y = components[1].strip_edges().to_float();
            return Vector2(x, y);
        }
    }
    
    // Try to parse as a Vector3
    if (p_value_str.begins_with("(") && p_value_str.ends_with(")")) {
        String vector_str = p_value_str.substr(1, p_value_str.length() - 2);
        Vector<String> components = vector_str.split(",");
        if (components.size() == 3) {
            float x = components[0].strip_edges().to_float();
            float y = components[1].strip_edges().to_float();
            float z = components[2].strip_edges().to_float();
            return Vector3(x, y, z);
        }
    }
    
    // Try to parse as a Color
    if (p_value_str.begins_with("#")) {
        return Color::html(p_value_str);
    }
    
    // Return as string
    return p_value_str;
}

SceneModifier::SceneModifier() {
}

SceneModifier::~SceneModifier() {
}
