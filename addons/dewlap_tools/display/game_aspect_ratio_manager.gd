extends Node

var base_size

@export var landscape_range_min:float = 16.0/10.0
@export var landscape_range_max:float = 20.0/9.0
@export var portrait_range_max:float = 10.0/16.0
@export var portrait_range_min:float = 9.0/20.0

var root_window:Window
var internal_change = false
var _previous_is_landscape: bool = true

signal content_scale_size_changed
signal orientation_changed(is_landscape: bool)

func _ready():
    #Set the root window node to it's extension script
    $"/root".set_script(load("res://common/global/window.gd"))
    root_window = get_tree().root
    base_size = min(root_window.content_scale_size.x, root_window.content_scale_size.y)
    SignalBus.window_resized.connect(_on_window_resized)
    call_deferred("_on_window_resized")

func is_landscape():
    var window_size: Vector2i = get_window().size
    var window_aspect_ratio: float = float(window_size.x) / float(window_size.y)
    return window_aspect_ratio > 1.0

func _on_window_resized():
    if internal_change:
        internal_change = false
        return
    var window_size: Vector2i = get_window().size
    var window_aspect_ratio: float = float(window_size.x) / float(window_size.y)
    var target_aspect_ratio: float

    var new_size := Vector2i(base_size, base_size)
    var new_svc_scale := Vector2.ONE

    var is_landscape := window_aspect_ratio > 1.0

    if is_landscape:
        target_aspect_ratio = clampf(window_aspect_ratio, landscape_range_min, landscape_range_max)
        new_size.x = base_size * target_aspect_ratio
        if window_aspect_ratio < target_aspect_ratio:
            new_svc_scale = Vector2.ONE * (window_aspect_ratio / target_aspect_ratio)
            var scaled_height:float = new_size.y * new_svc_scale.y
            var new_y_pos:int = (new_size.y - scaled_height) / 2
        elif window_aspect_ratio > target_aspect_ratio:
            var new_x_pos:int = (((window_aspect_ratio / target_aspect_ratio) * new_size.x) - new_size.x) / 2
    else:
        target_aspect_ratio = clampf(window_aspect_ratio, portrait_range_min, portrait_range_max)
        # Reverse ratio to make calculations easier/symetrical with landscape
        target_aspect_ratio = 1/target_aspect_ratio
        window_aspect_ratio = 1/window_aspect_ratio

        new_size.y = base_size * target_aspect_ratio
        if window_aspect_ratio < target_aspect_ratio:
            new_svc_scale = Vector2.ONE * (window_aspect_ratio / target_aspect_ratio)
            var scaled_width:float = new_size.x * new_svc_scale.x
            var new_x_pos:int = (new_size.x - scaled_width) / 2
        elif window_aspect_ratio > target_aspect_ratio:
            var new_y_pos:int = (((window_aspect_ratio / target_aspect_ratio) * new_size.y) - new_size.y) / 2

    internal_change = true
    root_window.content_scale_size = new_size
    content_scale_size_changed.emit()

    # Emit orientation change signal if orientation has changed
    if is_landscape != _previous_is_landscape:
        _previous_is_landscape = is_landscape
        orientation_changed.emit(is_landscape)
