# Dewlap Tools

A Godot 4.5+ plugin providing utility classes for resource management, logging, music playback, display handling, settings, and CSV parsing.

## Installation

1. Copy the `addons/dewlap_tools` folder to your project's `addons/` directory
2. Enable the plugin in Project Settings > Plugins > Dewlap Tools

## Features

### Resources
**ResourceUtil** - Static helper functions for managing project resources:
- Loading `.tres` files from disk
- Mapping resources to dictionaries by ID
- Merging resource data
- Saving and deleting `.tres` files

**ResourceReferenceGenerator** - Generates static reference scripts for Resource types.

Creates a script for each Resource type that exposes constants and static accessor methods based on resource IDs:

```gdscript
# Example generated code usage:
UpgradeRef.getr("wood_sword")
UpgradeRef.getr_wood_sword()
UpgradeRef.WOOD_SWORD

# Generate reference script:
ResourceReferenceGenerator.create_reference_script(Upgrade, "id")
```

**CSV** - Parse CSV files into collections of Resources.

### Logging
**Log** - Configurable logging utility with multiple log levels:

```gdscript
Log.debug("Debug message")
Log.info("Information")
Log.warn("Warning message")
Log.error("Error occurred")
Log.fatal("Fatal error")

# Configure log level
Log.log_level = Log.LEVEL.WARN  # Only show WARN and above
```

Features:
- Automatic stack trace formatting showing file, function, and line number
- Log levels: DEBUG, INFO, WARN, ERROR, FATAL, OFF
- Integration with Godot's push_warning() and push_error()

### Music
**PlaylistStreamPlayer** - AudioStreamPlayer extension for playlist management:

```gdscript
# Play specific tracks
player.play_track(0)
player.play_track_by_name("song_name")

# Playlist controls
player.play_next_song()
player.play_previous_song()
player.toggle_pause()

# Configuration
player.shuffle = true
player.loop = true
player.set_excluded_track_names(["menu_theme"])
```

Features:
- Shuffle and loop support
- Track exclusion
- Editor tool buttons for testing
- Signals for song events

**MusicPlaylist** & **Clip** - Additional music management resources

### Display
**GameAspectRatioManager** - Manages aspect ratio constraints for different screen orientations:

```gdscript
# Configure aspect ratio ranges
manager.landscape_range_min = 4.0/3.0  # 4:3
manager.landscape_range_max = 20.0/9.0  # Ultrawide
manager.portrait_range_min = 9.0/20.0
manager.portrait_range_max = 3.0/4.0

# Check orientation
if manager.is_landscape():
    # Handle landscape layout
```

Features:
- Automatic content scale adjustment
- Min/max aspect ratio clamping
- Landscape and portrait mode support
- Emits `content_scale_size_changed` signal

**AspectRatioRefGuides** - Visual reference guides for aspect ratio design

### Settings
**BaseSettings** - Extendable settings manager for saving/loading user preferences:

```gdscript
class_name MyGameSettings extends BaseSettings

var volume: float = 1.0:
    set(value):
        volume = value
        emit_update_signal()

var fullscreen: bool = false:
    set(value):
        fullscreen = value
        emit_update_signal()

# Usage
var settings = MyGameSettings.new()
settings.load_from_user_settings_file()
settings.volume = 0.5
settings.save_to_user_settings_file()
```

Features:
- Automatic serialization of script variables
- ConfigFile-based storage
- Default settings support
- Settings update signals

## Examples

The `examples/` directory contains sample implementations demonstrating resource generation pipelines.

## Requirements

- Godot 4.5 or newer

## License

See LICENSE file for details.
