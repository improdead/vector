/**************************************************************************/
/*  gemini_client.h                                                       */
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

#include "core/io/http_client.h"
#include "core/io/json.h"
#include "scene/main/node.h"

class GeminiClient : public Node {
    GDCLASS(GeminiClient, Node);

private:
    // Gemini API configuration
    String model = "gemini-1.5-pro";
    double temperature = 0.7;
    int max_output_tokens = 2048;
    bool dev_mode = false;
    String api_key;
    String proxy_url = "https://vector-ai-proxy.example.com/api/gemini";

    // HTTP request
    HTTPClient *http_client = nullptr;
    HTTPRequest *http_request = nullptr;

    // Callback for response
    Callable current_callback;

    String _get_settings_path() const;
    Dictionary _parse_modifications(const String &p_response_text);

protected:
    void _notification(int p_what);
    static void _bind_methods();

    void _on_request_completed(int p_result, int p_code, const PackedStringArray &p_headers, const PackedByteArray &p_body);

public:
    Dictionary load_settings();
    void save_settings(const Dictionary &p_settings);
    void send_request(const String &p_user_input, const String &p_scene_info, const Callable &p_callback);

    GeminiClient();
    ~GeminiClient();
};
