class_name Log extends Node

static var log_level:LEVEL = LEVEL.DEBUG

enum LEVEL{
    DEBUG,
    INFO,
    WARN,
    ERROR,
    FATEL,
    OFF,
}

static func debug(message:String):
    var prev_line := _get_previous_code_line()
    if log_level <= LEVEL.DEBUG:
        prints("[DEBUG] ", prev_line, message)

static func info(message:String):
    var prev_line := _get_previous_code_line()
    if log_level <= LEVEL.INFO:
        prints("[INFO]  ", prev_line, message)

static func warn(message:String):
    var prev_line := _get_previous_code_line()
    if log_level <= LEVEL.WARN:
        prints("[WARN]  ", prev_line, message)
        push_warning("[WARN] ", prev_line, message)

static func not_implemented():
    error("Not Implemented")

static func error(message:String):
    var prev_line := _get_previous_code_line()
    if log_level <= LEVEL.ERROR:
        prints("[ERROR] ", prev_line, message)
        push_error("[ERROR] ", prev_line, message)

static func fatal(message:String):
    var prev_line := _get_previous_code_line()
    if log_level <= LEVEL.ERROR:
        prints("[FATAL] ", prev_line, message)
        push_error("[FATAL] ", prev_line, message)

static func _get_previous_code_line() -> String:
    var stack := get_stack()
    if stack && !stack.is_empty() && stack.size() > 2:
        return _pretty_stack(stack[2])
    return ""

static func _pretty_stack(stack_dict:Dictionary) -> String:
    var file_name := stack_dict.get("source").get_file().rstrip(".gd") as String
    return file_name + "." + stack_dict.get("function") + "(" + str(stack_dict.get("line")) + "): "
