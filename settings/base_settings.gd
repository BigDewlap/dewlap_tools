## BaseSettings is an extendable settings manager.
## It handles saving and loading user-defined script variables to/from config files.
## To use it, extend this class and define properties with getters/setters as needed.
##
## Only script-defined variables (not internal or default-prefixed ones) are serialized.
class_name BaseSettings extends RefCounted

## Subclass must emit everytime a property is updated
signal settings_updated(settings:BaseSettings)

const DEFAULT_SETTINGS_FILE_PATH:String = "user://default_settings.cfg"
const SETTINGS_FILE_PATH:String = "user://user_settings.cfg"

var section_name:String

## Constructor. Initializes the section name based on the class name of the script.
func _init():
    var name_of_class = get_script().get_global_name()
    if name_of_class:
        section_name = name_of_class

## Saves the current settings to the given configuration file path.
func save_to_file(settings_file_path:String) -> BaseSettings:
    var config_file:ConfigFile = ConfigFile.new()
    if FileAccess.file_exists(settings_file_path):
        var err := config_file.load(settings_file_path)
        if err != OK:
            push_error("Failed to load config file: %s (Error code: %d)" % [settings_file_path, err])
            return
    _write_to_config(config_file)
    config_file.save(settings_file_path)
    return self

## Loads settings from the given configuration file path.
func load_from_file(settings_file_path:String) -> bool:
    var config_file:ConfigFile = ConfigFile.new()
    if !FileAccess.file_exists(settings_file_path):
        push_warning("BaseSettings: file does not exist - " + settings_file_path)
        return false
    var err := config_file.load(settings_file_path)
    if err != OK:
        push_error("Failed to load config file: %s (Error code: %d)" % [settings_file_path, err])
        return false
    _update_from_config(config_file)
    return true

## Saves the current settings to the user-specific settings file.
func save_to_user_settings_file():
    save_to_file(SETTINGS_FILE_PATH)

## Loads settings from the user-specific settings file.
func load_from_user_settings_file():
    load_from_file(SETTINGS_FILE_PATH)

## Saves the current settings to the default settings file.
func save_to_defaults_file():
    save_to_file(DEFAULT_SETTINGS_FILE_PATH)

## Loads settings from the default settings file.
func load_from_defaults_file():
    load_from_file(DEFAULT_SETTINGS_FILE_PATH)

## Emits the settings_updated signal with this instance as an argument.
func emit_update_signal():
    settings_updated.emit(self)

## Internal method to write settings to a given ConfigFile.
## Only valid script-defined variables are written.
func _write_to_config(config:ConfigFile):
    for property_name in _get_valid_property_list():
        config.set_value(section_name, property_name, self[property_name])

## Internal method to update properties from a ConfigFile.
## Only properties that exist and are script-defined are updated.
func _update_from_config(config:ConfigFile):
    #Cancel if section doesn't exist
    if !config.has_section(section_name):
        return
    var valid_properties := _get_valid_property_list()
    for property_name in config.get_section_keys(section_name):
        if valid_properties.has(property_name):
            self[property_name] = config.get_value(section_name, property_name)

## Returns a list of property names that are considered valid for saving/loading.
## These include script-defined variables excluding internal, default-prefixed, and ignored ones.
func _get_valid_property_list() -> Array[String]:
    var property_names:Array[String]
    for property in get_property_list():
        if property["usage"] & PROPERTY_USAGE_SCRIPT_VARIABLE:
            var property_name:String = property["name"]
            if property_name != "section_name":
                property_names.push_back(property_name)
    return property_names
