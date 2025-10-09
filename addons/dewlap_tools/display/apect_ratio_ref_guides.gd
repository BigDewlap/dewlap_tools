@tool
extends Node

@export var base_size:int = 360:
    set(value):
        base_size = value
        _update_reference_rects()
@export var landscape_range_min:float = 4.0/3.0:
    set(value):
        landscape_range_min = value
        _update_reference_rects()
@export var landscape_range_max:float = 20.0/9.0:
    set(value):
        landscape_range_max = value
        _update_reference_rects()
@export var portrait_range_max:float = 3.0/4.0:
    set(value):
        portrait_range_max = value
        _update_reference_rects()
@export var portrait_range_min:float = 9.0/20.0:
    set(value):
        portrait_range_min = value
        _update_reference_rects()

@onready var h_reference_rect_max: ReferenceRect = %HReferenceRectMax
@onready var h_reference_rect_min: ReferenceRect = %HReferenceRectMin
@onready var v_reference_rect_max: ReferenceRect = %VReferenceRectMax
@onready var v_reference_rect_min: ReferenceRect = %VReferenceRectMin

func _ready() -> void:
    call_deferred("_update_reference_rects")

func _update_reference_rects() -> void:
    if not is_node_ready():
        return

    if h_reference_rect_min and h_reference_rect_max and v_reference_rect_min and v_reference_rect_max:
        # Calculate horizontal (landscape) reference rects
        # For landscape: width = base_size * aspect_ratio, height = base_size
        var h_min_width: int = int(base_size * landscape_range_min)
        var h_max_width: int = int(base_size * landscape_range_max)

        h_reference_rect_min.size = Vector2i(h_min_width, base_size)
        h_reference_rect_max.size = Vector2i(h_max_width, base_size)

        # Calculate vertical (portrait) reference rects
        # For portrait: width = base_size, height = base_size / aspect_ratio
        var v_max_height: int = int(base_size / portrait_range_max)
        var v_min_height: int = int(base_size / portrait_range_min)

        v_reference_rect_max.size = Vector2i(base_size, v_max_height)
        v_reference_rect_min.size = Vector2i(base_size, v_min_height)
