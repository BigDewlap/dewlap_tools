@tool
## Utility class for parsing CSV files into a collection of Resources.
##
## This class provides static helper methods to extract headers from a CSV file,
## and to convert CSV rows into instances of a specified Resource type.
class_name CSV extends EditorScript

## Returns the header row (column names) from a CSV file.[br][br]
##
## `csv_path` is the path to the CSV file to read.[br]
## Returns an array of strings representing the headers, or an empty array on failure.empty array on failure.
static func get_headers(csv_path:String) -> Array[String]:
    var file := FileAccess.open(csv_path, FileAccess.READ)
    if not file:
        push_error("CSVUtil: Failed to open file: %s" % csv_path)
        return []
    var header := file.get_line().strip_edges().split(",")
    var header_array:Array[String]
    header_array.assign(header)
    return header_array

## Parses a CSV file into a list of resource instances of a given class.[br][br]
##
## - `resource_class` must be a script that inherits from [Resource].[br]
## - `csv_path` is the path to the CSV file.[br]
## - `mapper` is an optional Callable that takes `(ehaders:[Array][[String]], row_values: [Array][[Variant]], resource: [Resource])`
##   and updates the resource's properties manually.[br][br]
##
## If no mapper is provided, the function tries to assign values to properties
## based on matching CSV headers with property names on the resource.[br][br]
##
## Returns an array of resource instances, or an empty array on failure.
static func parse_csv_to_resource_list(resource_class:Script, csv_path:String, mapper:Callable = Callable()) -> Array[Resource]:
    var resources:Array[Resource]

    if resource_class.get_instance_base_type() != "Resource":
        push_error("Class", resource_class.get_global_name(), "must inherit from Resource")
        return []

    var file := FileAccess.open(csv_path, FileAccess.READ)
    if not file:
        push_error("CSVUtil: Failed to open file: %s" % csv_path)
        return []

    var headers := file.get_line().strip_edges().split(",")
    print("Creating resources of type: " + resource_class.get_global_name() + " with the following properties: " + str(headers))
    var line_number:int = 0
    while not file.eof_reached():
        line_number += 1
        var line := file.get_line().strip_edges()
        if line == "":
            continue
        var values := line.split(",")
        var resource = resource_class.new()

        # Print data
        for i in headers.size():
                print("(" + str(line_number) + ") " + str(headers[i]) + ": " + str(values[i]))

        if mapper.is_null():
            # Read all columns into matching properties
            for i in headers.size():
                resource[headers[i]] = values[i]
        else:
            mapper.call(headers, values, resource)

        resources.push_back(resource)

    return resources
