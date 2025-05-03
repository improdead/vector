#!/bin/bash

# This script runs all validations for the Vector AI plugin
# It can be used in CI/CD pipelines to catch errors before they cause problems
# Usage: ./run_validations.sh

# Exit on error
set -e

# Get the script directory
SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"

# Get the project directory
PROJECT_DIR="$( cd "$SCRIPT_DIR/../../.." && pwd )"

# Print header
echo "Running validations for Vector AI plugin..."
echo "Project directory: $PROJECT_DIR"
echo

# Validate all GDScript files
echo "Validating GDScript files..."
find "$PROJECT_DIR" -name "*.gd" | while read -r file; do
    echo "  Validating $file"
    godot --headless --script "$SCRIPT_DIR/validate_code.gd" -- "$file"
done
echo "GDScript validation complete."
echo

# Validate all scene files
echo "Validating scene files..."
find "$PROJECT_DIR" -name "*.tscn" | while read -r file; do
    echo "  Validating $file"
    godot --headless --script "$SCRIPT_DIR/validate_scene.gd" -- "$file"
done
echo "Scene validation complete."
echo

# Run any additional validations here

echo "All validations passed!"
