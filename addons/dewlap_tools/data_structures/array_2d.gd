class_name Array2D
extends RefCounted

var _data: Array[Array]
var _width: int
var _height: int
var _is_dynamic: bool

func _init(width: int, height: int, is_dynamic: bool = true, default_value = null) -> void:
    _width = width
    _height = height
    _is_dynamic = is_dynamic
    _data = []

    _initialize_data(default_value)

static func from_array(source_array: Array[Array], is_dynamic: bool = true, fill_value = null) -> Array2D:
    if source_array.is_empty():
        push_error("Array2D: Cannot create from empty array")
        return null

    var max_width: int = 0
    var height: int = source_array.size()

    for row in source_array:
        if row.size() > max_width:
            max_width = row.size()

    if max_width == 0:
        push_error("Array2D: All rows in source array are empty")
        return null

    var array_2d: Array2D = Array2D.new(max_width, height, is_dynamic, fill_value)

    for y in range(height):
        var source_row: Array = source_array[y]
        for x in range(source_row.size()):
            array_2d.set_value(x, y, source_row[x])

    return array_2d

func _initialize_data(default_value) -> void:
    _data.clear()
    for y in range(_height):
        var row: Array = []
        for x in range(_width):
            row.append(default_value)
        _data.append(row)

func get_width() -> int:
    return _width

func get_height() -> int:
    return _height

func get_size() -> Vector2i:
    return Vector2i(_width, _height)

func is_valid_position(x: int, y: int) -> bool:
    return x >= 0 and x < _width and y >= 0 and y < _height

func resize(new_width: int, new_height: int, default_value = null) -> bool:
    if not _is_dynamic:
        push_error("Array2D: Cannot resize a fixed-size array")
        return false

    if new_width <= 0 or new_height <= 0:
        push_error("Array2D: Width and height must be positive values")
        return false

    var old_data: Array[Array] = _data.duplicate(true)
    var old_width: int = _width
    var old_height: int = _height

    _width = new_width
    _height = new_height
    _initialize_data(default_value)

    var copy_width: int = min(old_width, new_width)
    var copy_height: int = min(old_height, new_height)

    for y in range(copy_height):
        for x in range(copy_width):
            _data[y][x] = old_data[y][x]

    return true

func get_value(x: int, y: int) -> Variant:
    if not is_valid_position(x, y):
        push_error("Array2D: Position (%d, %d) is out of bounds" % [x, y])
        return null
    return _data[y][x]

func set_value(x: int, y: int, value) -> void:
    if not is_valid_position(x, y):
        push_error("Array2D: Position (%d, %d) is out of bounds" % [x, y])
        return
    _data[y][x] = value

func get_row(row_index: int, include_nulls: bool = false) -> Array:
    if row_index < 0 or row_index >= _height:
        push_error("Array2D: Row index %d is out of bounds" % row_index)
        return []

    var row: Array = _data[row_index].duplicate()

    if not include_nulls:
        row = row.filter(func(value): return value != null)

    return row

func get_column(column_index: int, include_nulls: bool = false) -> Array:
    if column_index < 0 or column_index >= _width:
        push_error("Array2D: Column index %d is out of bounds" % column_index)
        return []

    var column: Array = []
    for y in range(_height):
        var value = _data[y][column_index]
        if include_nulls or value != null:
            column.append(value)

    return column

func get_rows(include_nulls: bool = false) -> Array[Array]:
    var rows:Array[Array] = []
    for row_index in range(0, _height):
        rows.push_back(get_row(row_index, include_nulls))
    return rows

func get_columns(include_nulls: bool = false) -> Array[Array]:
    var columns:Array[Array] = []
    for column_index in range(0, _width):
        columns.push_back(get_column(column_index, include_nulls))
    return columns

func fill(value) -> void:
    for y in range(_height):
        for x in range(_width):
            _data[y][x] = value

func clear() -> void:
    fill(null)

func count_non_null() -> int:
    var count: int = 0
    for y in range(_height):
        for x in range(_width):
            if _data[y][x] != null:
                count += 1
    return count

func is_full() -> bool:
    return count_non_null() == _width * _height

func is_empty() -> bool:
    return count_non_null() == 0
