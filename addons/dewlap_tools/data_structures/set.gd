class_name Set
extends RefCounted
## A hash set implementation using Dictionary for O(1) add, remove, and lookup operations.
## Elements are stored as dictionary keys with true as the value.

var _data: Dictionary


## Creates a new Set, optionally initialized with elements from an array.
func _init(initial_values: Array = []) -> void:
    _data = {}
    for element in initial_values:
        _data[element] = true


## Creates a new Set from an array of elements.
static func from_array(arr: Array) -> Set:
    return Set.new(arr)


## Adds an element to the set. If the element already exists, this has no effect.
func add(element: Variant) -> void:
    _data[element] = true


## Removes an element from the set. Returns true if the element was present.
func remove(element: Variant) -> bool:
    if _data.has(element):
        _data.erase(element)
        return true
    return false


## Returns true if the element exists in the set.
func has(element: Variant) -> bool:
    return _data.has(element)


## Removes all elements from the set.
func clear() -> void:
    _data.clear()


## Returns the number of elements in the set.
func size() -> int:
    return _data.size()


## Returns true if the set contains no elements.
func is_empty() -> bool:
    return _data.is_empty()


## Returns all elements as an array.
func to_array() -> Array:
    return _data.keys()


## Returns all elements as an array. Alias for to_array().
func values() -> Array:
    return to_array()


## Returns a new set containing all elements from both sets.
func union(other: Set) -> Set:
    var result: Set = duplicate()
    result.merge(other)
    return result


## Returns a new set containing only elements present in both sets.
func intersection(other: Set) -> Set:
    var result: Set = Set.new()
    for element in _data.keys():
        if other.has(element):
            result.add(element)
    return result


## Returns a new set containing elements in this set but not in the other set.
func difference(other: Set) -> Set:
    var result: Set = Set.new()
    for element in _data.keys():
        if not other.has(element):
            result.add(element)
    return result


## Returns a new set containing elements in either set but not in both.
func symmetric_difference(other: Set) -> Set:
    var result: Set = Set.new()
    for element in _data.keys():
        if not other.has(element):
            result.add(element)
    for element in other.to_array():
        if not has(element):
            result.add(element)
    return result


## Returns true if all elements in this set are also in the other set.
func is_subset(other: Set) -> bool:
    for element in _data.keys():
        if not other.has(element):
            return false
    return true


## Returns true if this set contains all elements from the other set.
func is_superset(other: Set) -> bool:
    return other.is_subset(self)


## Returns true if this set has no elements in common with the other set.
func is_disjoint(other: Set) -> bool:
    for element in _data.keys():
        if other.has(element):
            return false
    return true


## Returns a copy of this set.
func duplicate() -> Set:
    return Set.new(_data.keys())


## Adds all elements from the other set to this set (in-place union).
func merge(other: Set) -> void:
    for element in other.to_array():
        _data[element] = true
