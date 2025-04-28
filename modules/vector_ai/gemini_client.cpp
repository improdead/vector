/**************************************************************************/
/*  gemini_client.cpp                                                     */
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

#include "gemini_client.h"

#include "core/config/project_settings.h"
#include "core/io/file_access.h"
#include "core/io/http_request.h"
#include "core/io/json.h"
#include "editor/editor_paths.h"

void GeminiClient::_notification(int p_what) {
    switch (p_what) {
        case NOTIFICATION_READY: {
            http_request = memnew(HTTPRequest);
            http_request->connect("request_completed", callable_mp(this, &GeminiClient::_on_request_completed));
            add_child(http_request);
        } break;
    }
}

void GeminiClient::_bind_methods() {
    ClassDB::bind_method(D_METHOD("load_settings"), &GeminiClient::load_settings);
    ClassDB::bind_method(D_METHOD("save_settings", "settings"), &GeminiClient::save_settings);
    ClassDB::bind_method(D_METHOD("send_request", "user_input", "scene_info", "callback"), &GeminiClient::send_request);
    ClassDB::bind_method(D_METHOD("_on_request_completed"), &GeminiClient::_on_request_completed);
}

String GeminiClient::_get_settings_path() const {
    return EditorPaths::get_singleton()->get_config_dir().path_join("vector_ai_settings.json");
}

Dictionary GeminiClient::load_settings() {
    Dictionary settings;
    
    String settings_path = _get_settings_path();
    Ref<FileAccess> f = FileAccess::open(settings_path, FileAccess::READ);
    
    if (f.is_valid()) {
        String json_text = f->get_as_text();
        
        JSON json;
        Error err = json.parse(json_text);
        
        if (err == OK) {
            settings = json.get_data();
            
            if (settings.has("model")) {
                model = settings["model"];
            }
            
            if (settings.has("temperature")) {
                temperature = settings["temperature"];
            }
            
            if (settings.has("max_output_tokens")) {
                max_output_tokens = settings["max_output_tokens"];
            }
            
            if (settings.has("dev_mode")) {
                dev_mode = settings["dev_mode"];
            }
            
            if (settings.has("api_key")) {
                api_key = settings["api_key"];
            }
            
            if (settings.has("proxy_url")) {
                proxy_url = settings["proxy_url"];
            }
        }
    } else {
        // Create default settings
        settings["model"] = model;
        settings["temperature"] = temperature;
        settings["max_output_tokens"] = max_output_tokens;
        settings["dev_mode"] = dev_mode;
        settings["proxy_url"] = proxy_url;
        
        save_settings(settings);
    }
    
    return settings;
}

void GeminiClient::save_settings(const Dictionary &p_settings) {
    if (p_settings.has("model")) {
        model = p_settings["model"];
    }
    
    if (p_settings.has("temperature")) {
        temperature = p_settings["temperature"];
    }
    
    if (p_settings.has("max_output_tokens")) {
        max_output_tokens = p_settings["max_output_tokens"];
    }
    
    if (p_settings.has("dev_mode")) {
        dev_mode = p_settings["dev_mode"];
    }
    
    if (p_settings.has("api_key")) {
        api_key = p_settings["api_key"];
    }
    
    if (p_settings.has("proxy_url")) {
        proxy_url = p_settings["proxy_url"];
    }
    
    String settings_path = _get_settings_path();
    Ref<FileAccess> f = FileAccess::open(settings_path, FileAccess::WRITE);
    
    if (f.is_valid()) {
        Dictionary settings_to_save;
        settings_to_save["model"] = model;
        settings_to_save["temperature"] = temperature;
        settings_to_save["max_output_tokens"] = max_output_tokens;
        settings_to_save["dev_mode"] = dev_mode;
        settings_to_save["proxy_url"] = proxy_url;
        
        if (dev_mode && !api_key.is_empty()) {
            settings_to_save["api_key"] = api_key;
        }
        
        JSON json;
        String json_text = json.stringify(settings_to_save, "    ");
        f->store_string(json_text);
    }
}

void GeminiClient::send_request(const String &p_user_input, const String &p_scene_info, const Callable &p_callback) {
    if (dev_mode && api_key.is_empty()) {
        Dictionary response;
        p_callback.call(response, "API key not set. Please set it in the settings.");
        return;
    }
    
    current_callback = p_callback;
    
    // Prepare the prompt
    String system_prompt = R"(
You are Vector AI, an AI assistant that helps users modify their Godot scenes based on natural language prompts.
You have access to the current scene structure and can suggest modifications to it.

When suggesting modifications, use the following format:

ANALYSIS:
[Your analysis of the current scene and what needs to be changed]

MODIFICATIONS:
[List of specific modifications to make, including node paths, property names, and new values]

EXPLANATION:
[Explanation of why these modifications were made and how they address the user's request]
)";
    
    String scene_prompt = "Current scene structure:\n" + p_scene_info;
    
    Dictionary request_data;
    String url;
    PackedStringArray headers;
    headers.push_back("Content-Type: application/json");
    
    if (dev_mode) {
        // Direct API call for development/testing
        url = "https://generativelanguage.googleapis.com/v1/models/" + model + ":generateContent?key=" + api_key;
        
        // Prepare the direct API request body
        Array contents;
        
        Dictionary system_message;
        system_message["role"] = "system";
        Array system_parts;
        Dictionary system_part;
        system_part["text"] = system_prompt;
        system_parts.push_back(system_part);
        system_message["parts"] = system_parts;
        contents.push_back(system_message);
        
        Dictionary scene_message;
        scene_message["role"] = "user";
        Array scene_parts;
        Dictionary scene_part;
        scene_part["text"] = scene_prompt;
        scene_parts.push_back(scene_part);
        scene_message["parts"] = scene_parts;
        contents.push_back(scene_message);
        
        Dictionary user_message;
        user_message["role"] = "user";
        Array user_parts;
        Dictionary user_part;
        user_part["text"] = p_user_input;
        user_parts.push_back(user_part);
        user_message["parts"] = user_parts;
        contents.push_back(user_message);
        
        Dictionary generation_config;
        generation_config["temperature"] = temperature;
        generation_config["maxOutputTokens"] = max_output_tokens;
        generation_config["topP"] = 0.95;
        generation_config["topK"] = 64;
        
        request_data["contents"] = contents;
        request_data["generationConfig"] = generation_config;
    } else {
        // Proxy server call for production
        url = proxy_url;
        
        request_data["model"] = model;
        request_data["temperature"] = temperature;
        request_data["max_output_tokens"] = max_output_tokens;
        request_data["system_prompt"] = system_prompt;
        request_data["scene_info"] = p_scene_info;
        request_data["user_input"] = p_user_input;
    }
    
    JSON json;
    String json_body = json.stringify(request_data);
    
    Error err = http_request->request(url, headers, HTTPClient::METHOD_POST, json_body);
    
    if (err != OK) {
        Dictionary response;
        p_callback.call(response, "HTTP Request Error: " + itos(err));
    }
}

void GeminiClient::_on_request_completed(int p_result, int p_code, const PackedStringArray &p_headers, const PackedByteArray &p_body) {
    if (current_callback.is_null()) {
        return;
    }
    
    if (p_result != HTTPRequest::RESULT_SUCCESS) {
        Dictionary response;
        current_callback.call(response, "HTTP Request Failed: " + itos(p_result));
        current_callback = Callable();
        return;
    }
    
    if (p_code != 200) {
        Dictionary response;
        current_callback.call(response, "HTTP Error: " + itos(p_code));
        current_callback.call(response, String::utf8((const char *)p_body.ptr(), p_body.size()));
        current_callback = Callable();
        return;
    }
    
    // Parse the response
    String response_text = String::utf8((const char *)p_body.ptr(), p_body.size());
    JSON json;
    Error err = json.parse(response_text);
    
    if (err != OK) {
        Dictionary response;
        current_callback.call(response, "JSON Parse Error: " + itos(err));
        current_callback = Callable();
        return;
    }
    
    Dictionary response_data = json.get_data();
    
    // Extract the response text
    String ai_response_text;
    
    // Check if this is a direct Gemini API response
    if (response_data.has("candidates") && response_data["candidates"].get_type() == Variant::ARRAY) {
        Array candidates = response_data["candidates"];
        if (candidates.size() > 0) {
            Dictionary candidate = candidates[0];
            if (candidate.has("content") && candidate["content"].get_type() == Variant::DICTIONARY) {
                Dictionary content = candidate["content"];
                if (content.has("parts") && content["parts"].get_type() == Variant::ARRAY) {
                    Array parts = content["parts"];
                    for (int i = 0; i < parts.size(); i++) {
                        Dictionary part = parts[i];
                        if (part.has("text")) {
                            ai_response_text += String(part["text"]);
                        }
                    }
                }
            }
        }
    }
    // Check if this is our proxy server response format
    else if (response_data.has("response")) {
        ai_response_text = response_data["response"];
    }
    
    if (ai_response_text.is_empty()) {
        Dictionary response;
        current_callback.call(response, "Empty response from API");
        current_callback = Callable();
        return;
    }
    
    // Parse modifications from the response
    Dictionary modifications = _parse_modifications(ai_response_text);
    
    // Create the response object
    Dictionary response;
    response["text"] = ai_response_text;
    response["modifications"] = modifications;
    
    // Call the callback
    current_callback.call(response, "");
    current_callback = Callable();
}

Dictionary GeminiClient::_parse_modifications(const String &p_response_text) {
    Dictionary modifications;
    Array mod_list;
    
    // Look for the MODIFICATIONS section
    int modifications_start = p_response_text.find("MODIFICATIONS:");
    int modifications_end = p_response_text.find("EXPLANATION:");
    
    if (modifications_start != -1 && modifications_end != -1) {
        String modifications_text = p_response_text.substr(modifications_start + 14, modifications_end - modifications_start - 14).strip_edges();
        Vector<String> lines = modifications_text.split("\n");
        
        for (int i = 0; i < lines.size(); i++) {
            String line = lines[i].strip_edges();
            if (line.is_empty() || line.begins_with("-") || line.begins_with("*")) {
                continue;
            }
            
            // Parse the modification
            Vector<String> parts = line.split(":", true, 1);
            if (parts.size() >= 2) {
                String node_path = parts[0].strip_edges();
                String property_value = parts[1].strip_edges();
                
                Dictionary mod;
                mod["node_path"] = node_path;
                mod["property_value"] = property_value;
                mod_list.push_back(mod);
            }
        }
    }
    
    modifications["list"] = mod_list;
    return modifications;
}

GeminiClient::GeminiClient() {
    load_settings();
}

GeminiClient::~GeminiClient() {
}
