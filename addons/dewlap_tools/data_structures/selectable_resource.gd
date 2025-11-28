class_name SelectableResource extends Resource

@export var id:String
@export var name:String
@export_multiline var description:String

func _get_configuration_warning():
    if id == null:
        return "The 'id' variable must be assigned."
    if name == null:
        return "The 'name' variable must be assigned."
    return ""
