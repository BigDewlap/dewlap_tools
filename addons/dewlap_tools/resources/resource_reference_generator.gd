## Utility for generating static reference scripts for Resource types.
##
## This class creates a new script for each Resource type that is stored as a standalone file in the project, exposing constants and
## static accessor methods for each resource based on its ID. The generated script
## allows accessing resources like:
##
## [codeblock]
## UpgradeRef.getr("wood_sword")
## UpgradeRef.getr_wood_sword()
## UpgradeRef.WOOD_SWORD
## [/codeblock]
##
## All resources are indexed at generation time using their identity property and path.
##
## [b]Example usage:[/b]
## [codeblock]
## ResourceReferenceGenerator.create_reference_script(Upgrade, "id")
## [/codeblock]
class_name ResourceReferenceGenerator extends EditorScript

const script_template = \
"""#DO NOT EDIT: Generated using ResourceReferenceGenerator
@tool
class_name [[RESOURCE_CLASS_NAME]]Ref extends Object

[[ID_CONSTANTS]]

static var resource_paths:Dictionary[StringName, String] = [[PATHS_DICTIONARY]]

static func getr(id: String, cache_mode: ResourceLoader.CacheMode = ResourceLoader.CacheMode.CACHE_MODE_REUSE) -> [[RESOURCE_CLASS_NAME]]:
    if !id:
        return null
    var path:String = resource_paths.get(id, "") as String
    if !path:
        return null
    return ResourceLoader.load(path, "", cache_mode)

static func getrall(cache_mode: ResourceLoader.CacheMode = ResourceLoader.CacheMode.CACHE_MODE_REUSE) -> Array[[[RESOURCE_CLASS_NAME]]]:
    var result_array: Array[[[RESOURCE_CLASS_NAME]]] = []
    for resource_path in resource_paths.values():
        result_array.append(ResourceLoader.load(resource_path, "", cache_mode))
    return result_array
"""

const getter_template = \
"""
static func getr_[[RESOURCE_ID]](cache_mode: ResourceLoader.CacheMode = ResourceLoader.CacheMode.CACHE_MODE_REUSE) -> [[RESOURCE_CLASS_NAME]]:
    return getr("[[RESOURCE_ID]]", cache_mode)
"""

## Generates a reference script for a [Resource] type with static access to its instances. If [code]target_path[/code]
## is not specified, the file be be a sibling to the [code]resource_class[/code]
static func create_reference_script(resource_class: Script, id_property_name:String, target_path: String = ""):
    # Validation
    print(resource_class.get_instance_base_type())
    if resource_class.get_instance_base_type() != "Resource":
        print_debug("Script base type must be a Resource")
        return

    var resource_class_name:String = resource_class.get_global_name()
    prints("Generating Refernce Class for", resource_class_name)

    # Get all resources
    var resources = ResourceUtil.load_resources_in_editor(resource_class)
    assert(!ResourceUtil.has_duplicate_ids(resources, id_property_name), "ResourceReferenceGenerator: DuplicateResourceIds detected")

    #Prepare File Name
    var resource_script_path:String = resource_class.resource_path
    var resource_script_directory: String = resource_script_path.get_base_dir()
    var resource_script_file_name: String = resource_script_path.get_file()
    var new_file_name: String = resource_script_file_name.trim_suffix(".gd") + "_ref" + ".gd"
    if !target_path:
        target_path = resource_script_directory
    var new_file_path: String = target_path.path_join(new_file_name)

    #Generate Script String and write to file
    prints("Creating/updating file: ", new_file_path)
    var file_access: FileAccess = FileAccess.open(new_file_path, FileAccess.WRITE)
    var script_string:String = _generate_reference_script_from_resources(resource_class, resources, id_property_name)
    file_access.store_line(script_string)
    file_access.close()

    # Update editor after file changes
    EditorInterface.get_resource_filesystem().scan()

## Generates the reference script text from a list of resources
static func _generate_reference_script_from_resources(resource_class: Script, resources: Array[Resource], id_property_name: String = "id") -> String:
    prints("Resources found: ", resources.size())
    #Get Class Name
    var resource_class_name = resource_class.get_global_name()

    #Prepare Replacement Variables
    var id_constants_string: String = ""
    var resource_paths: Dictionary[String, String] = {}
    var getter_strings: String = ""


    for resource in resources:
        var id: String = str(resource.get(id_property_name)) as String
        var normalized_id = id.replace(" ", "_")
        assert(id != null, "Resource id property is null")
        prints("Generating resource:", normalized_id)
        id_constants_string += "const " + normalized_id.to_upper() + " = \"" + normalized_id + "\"\n"
        resource_paths.set(normalized_id, resource.resource_path)
        # Append getter function template
        var getter_string = getter_template.replace("[[RESOURCE_CLASS_NAME]]", resource_class_name)
        getter_string = getter_string.replace("[[RESOURCE_ID]]", normalized_id)
        getter_strings += getter_string

    var reference_script_string: String = script_template
    reference_script_string = reference_script_string.replace("[[RESOURCE_CLASS_NAME]]", resource_class_name)
    reference_script_string = reference_script_string.replace("[[ID_CONSTANTS]]", id_constants_string)
    reference_script_string = reference_script_string.replace("[[PATHS_DICTIONARY]]", JSON.stringify(resource_paths, "\t"))
    reference_script_string += getter_strings

    return reference_script_string
