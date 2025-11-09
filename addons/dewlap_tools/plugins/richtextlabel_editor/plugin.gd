@tool
extends EditorPlugin

var editor_panel: Control = null


func _enter_tree() -> void:
    # Load and instantiate the editor panel scene
    var panel_scene: PackedScene = preload("bbcode_editor_panel.tscn")
    editor_panel = panel_scene.instantiate()

    # Add as bottom panel (always available)
    add_control_to_bottom_panel(editor_panel, "BBCode Editor")

    # Show panel by default (standalone mode)
    make_bottom_panel_item_visible(editor_panel)


func _exit_tree() -> void:
    # Remove and cleanup panel
    if editor_panel:
        remove_control_from_bottom_panel(editor_panel)
        editor_panel.queue_free()
        editor_panel = null
