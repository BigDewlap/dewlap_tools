@tool
class_name Clip extends Resource

@export var name:String
@export var stream:AudioStream:
    set(value):
        stream = value
        name = stream.resource_path.get_file().get_basename().replace("-", "_").capitalize()
    get:
        return stream
