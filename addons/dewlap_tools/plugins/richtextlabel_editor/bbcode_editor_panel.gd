@tool
extends VBoxContainer

# UI Controls
@onready var font_dropdown: OptionButton = %FontDropdown
@onready var font_size_spinner: SpinBox = %FontSizeSpinner
@onready var apply_to_node_checkbox: CheckBox = %ApplyToNodeCheckbox
@onready var scale_1x_button: Button = %Scale1xButton
@onready var scale_2x_button: Button = %Scale2xButton
@onready var scale_3x_button: Button = %Scale3xButton
@onready var scale_4x_button: Button = %Scale4xButton

# Editor and Preview
@onready var text_edit: TextEdit = %TextEdit
@onready var preview_texture_rect: TextureRect = %PreviewTextureRect
@onready var sub_viewport: SubViewport = %SubViewport
@onready var preview_label: RichTextLabel = %PreviewLabel

# State
var current_node: RichTextLabel = null
var updating: bool = false
var available_fonts: Array[Dictionary] = []
var current_scale: int = 1


func _ready() -> void:
    _scan_fonts()
    _connect_signals()
    _initialize_viewport()


func _scan_fonts() -> void:
    #Scan assets/fonts directory for available fonts.#
    var fonts_dir: String = "res://assets/fonts/"
    var dir: DirAccess = DirAccess.open(fonts_dir)

    if not dir:
        push_error("Cannot open fonts directory: " + fonts_dir)
        return

    dir.list_dir_begin()
    var file_name: String = dir.get_next()

    while file_name != "":
        if not dir.current_is_dir() and file_name.ends_with(".ttf"):
            var font_path: String = fonts_dir + file_name
            var font_resource: FontFile = load(font_path)

            if font_resource:
                available_fonts.append({
                    "name": file_name.get_basename(),
                    "path": font_path,
                    "resource": font_resource
                })

        file_name = dir.get_next()

    dir.list_dir_end()

    # Sort fonts alphabetically
    available_fonts.sort_custom(func(a, b): return a.name < b.name)

    # Populate dropdown
    font_dropdown.clear()
    font_dropdown.add_item("(Default)", 0)

    for i in range(available_fonts.size()):
        font_dropdown.add_item(available_fonts[i].name, i + 1)


func _connect_signals() -> void:
    #Connect all control signals.#
    text_edit.text_changed.connect(_on_text_changed)
    font_dropdown.item_selected.connect(_on_font_selected)
    font_size_spinner.value_changed.connect(_on_font_size_changed)
    scale_1x_button.pressed.connect(_on_scale_button_pressed.bind(1))
    scale_2x_button.pressed.connect(_on_scale_button_pressed.bind(2))
    scale_3x_button.pressed.connect(_on_scale_button_pressed.bind(3))
    scale_4x_button.pressed.connect(_on_scale_button_pressed.bind(4))


func _initialize_viewport() -> void:
    #Initialize SubViewport to base game resolution.#
    var base_size: Vector2i = Vector2i(480, 360)

    # Set SubViewport to constant resolution (never changes)
    sub_viewport.size = base_size
    sub_viewport.canvas_item_default_texture_filter = Viewport.DEFAULT_CANVAS_ITEM_TEXTURE_FILTER_NEAREST

    # Set up TextureRect to display the viewport
    var viewport_texture: ViewportTexture = sub_viewport.get_texture()
    preview_texture_rect.texture = viewport_texture
    preview_texture_rect.custom_minimum_size = Vector2(base_size)

    current_scale = 1


func set_edited_node(node: RichTextLabel) -> void:
    #Load a RichTextLabel node for editing.#
    if current_node == node:
        return

    current_node = node
    _load_settings_from_node()


func clear_editor() -> void:
    #Clear the editor when no node is selected.#
    current_node = null
    updating = true
    text_edit.text = ""
    preview_label.text = ""
    updating = false


func _load_settings_from_node() -> void:
    #Load text and settings from the currently selected node.#
    if not current_node:
        clear_editor()
        return

    updating = true

    # Load text
    text_edit.text = current_node.text
    preview_label.text = current_node.text

    # Load font
    var current_font: Font = current_node.get_theme_font("normal_font")
    _set_font_dropdown_from_font(current_font)

    # Load font size
    var current_size: int = current_node.get_theme_font_size("normal_font_size")
    if current_size > 0:
        font_size_spinner.value = current_size

    updating = false


func _set_font_dropdown_from_font(font: Font) -> void:
    #Set font dropdown selection based on current font.#
    if not font:
        font_dropdown.selected = 0
        return

    # Try to match font resource path
    for i in range(available_fonts.size()):
        if available_fonts[i].resource == font:
            font_dropdown.selected = i + 1
            return

    font_dropdown.selected = 0


func _on_text_changed() -> void:
    #Update preview and sync to node when text changes.#
    if updating:
        return

    var new_text: String = text_edit.text

    # Update preview
    preview_label.text = new_text

    # Sync to the actual node if apply checkbox is checked
    if apply_to_node_checkbox.button_pressed and current_node and is_instance_valid(current_node):
        current_node.text = new_text


func _on_font_selected(index: int) -> void:
    #Handle font selection change.#
    if updating:
        return

    if index == 0:
        # Default font
        preview_label.remove_theme_font_override("normal_font")
        if apply_to_node_checkbox.button_pressed and current_node and is_instance_valid(current_node):
            current_node.remove_theme_font_override("normal_font")
    else:
        # Selected font
        var font_index: int = index - 1
        if font_index < available_fonts.size():
            var font: FontFile = available_fonts[font_index].resource
            preview_label.add_theme_font_override("normal_font", font)

            if apply_to_node_checkbox.button_pressed and current_node and is_instance_valid(current_node):
                current_node.add_theme_font_override("normal_font", font)


func _on_font_size_changed(value: float) -> void:
    #Handle font size change.#
    if updating:
        return

    var size: int = int(value)
    preview_label.add_theme_font_size_override("normal_font_size", size)

    if apply_to_node_checkbox.button_pressed and current_node and is_instance_valid(current_node):
        current_node.add_theme_font_size_override("normal_font_size", size)


func _on_scale_button_pressed(scale: int) -> void:
    #Handle resolution scale button press.#
    current_scale = scale

    # Update ONLY the TextureRect display size, NOT the SubViewport render size
    # SubViewport stays constant at 480x360, TextureRect scales the display
    var base_size: Vector2i = Vector2i(480, 360)
    var scaled_size: Vector2i = base_size * scale
    preview_texture_rect.custom_minimum_size = Vector2(scaled_size)

    # Update button states
    scale_1x_button.button_pressed = (scale == 1)
    scale_2x_button.button_pressed = (scale == 2)
    scale_3x_button.button_pressed = (scale == 3)
    scale_4x_button.button_pressed = (scale == 4)
