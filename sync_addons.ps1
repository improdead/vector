# PowerShell script to update settings in the test_project/addons directory

# Define destination path
$destDir = "test_project/addons/vector_ai"

# Create destination directory if it doesn't exist
if (-not (Test-Path $destDir)) {
    New-Item -ItemType Directory -Path $destDir -Force
}

# Remove old files that are no longer needed
Write-Host "Removing old files..."
$oldFiles = @(
    "$destDir/scripts/code_executor.gd",
    "$destDir/scripts/code_executor.gd.uid",
    "$destDir/scripts/scene_analyzer.gd",
    "$destDir/scripts/scene_analyzer.gd.uid",
    "$destDir/scripts/scene_modifier.gd",
    "$destDir/scripts/scene_modifier.gd.uid",
    "$destDir/scripts/sidebar.gd",
    "$destDir/scripts/sidebar.gd.uid",
    "$destDir/scenes/sidebar.tscn"
)

foreach ($file in $oldFiles) {
    if (Test-Path $file) {
        Remove-Item -Path $file -Force
        Write-Host "Removed: $file"
    }
}

# Update settings.json to use Gemini 2.5 Flash
$settingsPath = "$destDir/settings.json"
if (Test-Path $settingsPath) {
    $settings = Get-Content $settingsPath | ConvertFrom-Json
    $settings.model = "gemini-2.5-flash-preview-04-17"
    $settings | ConvertTo-Json | Set-Content $settingsPath
    Write-Host "Updated settings.json to use Gemini 2.5 Flash"
}

Write-Host "Sync complete!"
Write-Host "Now you can open the test_project in Godot and the changes will be reflected."
