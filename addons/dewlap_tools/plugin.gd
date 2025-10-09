@tool
extends EditorPlugin

## Dewlap Tools plugin for Godot 4.5
## Provides utility classes for CSV parsing, resource management, logging, music, settings, and display


func _enter_tree() -> void:
	# Plugin initialization
	# All utility classes are used directly via class_name, no editor integration needed
	pass


func _exit_tree() -> void:
	# Plugin cleanup
	pass
