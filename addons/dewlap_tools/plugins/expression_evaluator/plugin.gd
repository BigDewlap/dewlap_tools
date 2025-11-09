@tool
extends EditorPlugin

var editor_panel: Control = null

func _enter_tree() -> void:
    # Load and instantiate the editor panel scene
    var panel_scene: PackedScene = preload("expression_panel.tscn")
    editor_panel = panel_scene.instantiate()

    # Add as bottom panel (always available)
    add_control_to_bottom_panel(editor_panel, "Expression Evaluator")

    # Connect to selection changes for hybrid mode (load from resources)
    get_editor_interface().get_selection().selection_changed.connect(_on_selection_changed)

    # Show panel by default (standalone mode)
    make_bottom_panel_item_visible(editor_panel)


func _exit_tree() -> void:
    # Disconnect signals
    if get_editor_interface().get_selection().selection_changed.is_connected(_on_selection_changed):
        get_editor_interface().get_selection().selection_changed.disconnect(_on_selection_changed)

    # Remove and cleanup panel
    if editor_panel:
        remove_control_from_bottom_panel(editor_panel)
        editor_panel.queue_free()
        editor_panel = null


func _on_selection_changed() -> void:
    #"""Handle editor selection changes - load expressions from selected resources."""
    var selection: EditorSelection = get_editor_interface().get_selection()
    var selected_nodes: Array[Node] = selection.get_selected_nodes()

# Check if a single node/resource is selected
    if selected_nodes.size() == 1:
        var selected: Node = selected_nodes[0]

    # Try to load expression from resource (e.g., Upgrade)
    # The panel will handle checking for expression properties
        if editor_panel.has_method("try_load_from_resource"):
            editor_panel.try_load_from_resource(selected)
