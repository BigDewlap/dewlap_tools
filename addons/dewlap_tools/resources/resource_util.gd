## Utility class with static functions for managing Resource files.
##
## This class provides a collection of static helper functions for:[br]
## - Loading `.tres` files from disk[br]
## - Mapping resources to dictionaries by ID[br]
## - Merging resource data[br]
## - Saving and deleting `.tres` files[br][br]
##
## Intended for use in the Godot Editor as part of custom content workflows.
class_name ResourceUtil extends EditorScript

## Loads all `.tres` resources of the given type from a directory, optionally recursively.
static func load_resources_in_editor(resource_type:Script, directory_path:String = "res://", recursive:bool=true) -> Array[Resource]:
    var result_array:Array[Resource] = []
    var dir_access:DirAccess = DirAccess.open(directory_path)

    if dir_access == null:
        push_error("ResourceUtil: Invalid Directory")
        return result_array

    for file_name in dir_access.get_files():
        if file_name.ends_with(".tres"):
            var file_path = directory_path.path_join(file_name)
            var resource = ResourceLoader.load(file_path)
            if is_instance_of(resource, resource_type):
                result_array.append(resource)

    if recursive:
        for subdiretory_name in dir_access.get_directories():
            var subdirectory_path = directory_path.path_join(subdiretory_name)
            var sub_resources = load_resources_in_editor(resource_type, subdirectory_path, recursive)
            result_array.append_array(sub_resources)

    return result_array

static func load_resources_from_directory(directory_path:String) -> Array[Resource]:
    var resources:Array[Resource] = []
    var file_paths := ResourceLoader.list_directory(directory_path)
    for file_path:String in file_paths:
        resources.push_back(ResourceLoader.load(directory_path + file_path))
    return resources


## Merges property values from resources [code]source_resources[/code] into matching resources in [code]target_resources[/code].
## Matches occur on the value of the id property.  Only the properties defined are merged. Optionally, enable removeal of
## resources that don't exist in the source
static func merge_resources_arrays(
    source_resources:Array,
    target_resources:Array,
    resource_id_property_name: String,
    properties_to_merge:Array[String],
    delete_removed_resources:bool = false) -> void:

    prints("ResourceUtil: MERGING STARTED")

    var source_dictionary = resources_to_id_dictionary(source_resources, resource_id_property_name)
    var target_dictionary = resources_to_id_dictionary(target_resources, resource_id_property_name)

    for resource_id in source_dictionary.keys():
        var source_resource:Resource = source_dictionary.get(resource_id)
        var target_resource:Resource = target_dictionary.get(resource_id)
        if target_resource == null:
            prints("ResourceUtil: New entity: ", resource_id )
            target_dictionary.set(resource_id, source_resource)
            target_resources.append(source_resource)
        else:
            prints("ResourceUtil: Merging entity: ", resource_id )
            merge_resource_properties(source_resource, target_resource, properties_to_merge)

    if delete_removed_resources:
        for i in range(target_resources.size() - 1, -1, -1):
            var resource_id = target_resources.get(i).get(resource_id_property_name)
            if !source_dictionary.has(resource_id):
                prints("ResourceUtil: Removing entity: ", resource_id)
                target_dictionary.erase(resource_id)
                target_resources.remove_at(i)

    prints("ResourceUtil: MERGING ENEDED")

## Converts a list of resources into a dictionary using a unique property (e.g., "id") as the key.
static func resources_to_id_dictionary(source_resources: Array[Variant], resource_id_property_name: String) -> Dictionary[Variant, Resource]:
    var result: Dictionary[Variant, Resource] = {}
    for resource in source_resources:
        var key = resource.get(resource_id_property_name)
        if key != null:
            if result.has(key):
                push_warning("ResourceUtil: Resource with id '%s' already exists" % key)
            else:
                result[key] = resource
        else:
            push_warning("ResourceUtil: Resource does not have property '%s'" % resource_id_property_name)
    return result

## Checks for duplicate values in a list of resources based on an identity property.
static func has_duplicate_ids(resources: Array[Variant], resource_id_property_name: String, case_sensitive_ids:bool = false) -> bool:
    var result: Dictionary[Variant, Resource] = {}
    for resource in resources:
        var key = resource.get(resource_id_property_name)
        if key != null:
            if !case_sensitive_ids and key is String:
                key = key.to_lower()
            if result.has(key):
                return true
            else:
                result[key] = resource
        else:
            push_warning("ResourceUtil: Resource does not have property '%s'" % resource_id_property_name)
    return false

## Copies a list of property values from one resource to another. Only the properties defined are merged.
static func merge_resource_properties(source:Resource, target:Resource, properties_to_merge:Array[String]) -> void:
    for property_name in properties_to_merge:
        prints("ResourceUtil: Merging property ", property_name, ", old:", target.get(property_name), ", new:", source.get(property_name))
        target.set(property_name, source.get(property_name))

## Saves a resource to a `.tres` file at the given path. Do not provide an extension to the file_name
static func save_resource_to_filesystem(resource:Resource, path:String, file_name:String) -> void:
    var save_path = path.path_join(file_name + ".tres")
    if !DirAccess.dir_exists_absolute(path):
        print("ResourceUtil: Creating directory: " + path)
        var result := DirAccess.make_dir_recursive_absolute(path)
        if result != OK:
            push_error("ResourceUtil: Error code: " + str(result) + ", Failed to create directory: " + path)

    print("ResourceUtil: Saving file: " + save_path)
    var result := ResourceSaver.save(resource, save_path)
    if result != OK:
        push_error("ResourceUtil: Error code: " + str(result) + ", Failed to save resource to: " + save_path)

## Find all resources of a given type, updates them based on matching id, and removed any that were not included
## New resources will be saved into the default path provided.
static func save_and_clean_all_resources_to_filesystem(
    resource_class:Script,
    new_resources:Array[Resource],
    default_path:String,
    id_property_name:String) -> void:

    print("ResourceUtil: SAVE AND CLEAN FILES STARTED")

    var existing_resources := load_resources_in_editor(resource_class)
    var new_resource_dict := resources_to_id_dictionary(new_resources, id_property_name)

    # Update existing resources
    for i in range(existing_resources.size() - 1, -1, -1):
        var resource:Resource = existing_resources.get(i) as Resource
        var resource_id := resource.get(id_property_name)
        print("ResourceUtil: resource id " + resource_id)
        var new_resource := new_resource_dict.get(resource_id)
        if new_resource != null:
            var existing_resouce_path = resource.resource_path.get_base_dir()
            save_resource_to_filesystem(new_resource, existing_resouce_path, resource_id)
            existing_resources.remove_at(i)
            new_resource_dict.erase(resource_id)

    # Delete removed resources
    for resource in existing_resources:
        delete_resource_from_filesystem(resource)

    #Save new resources
    for resource in new_resource_dict.values():
        save_resource_to_filesystem(resource, default_path, resource.get(id_property_name))

    print("ResourceUtil: SAVE AND CLEAN FILES ENDED")

## Deletes a resource `.tres` file from the file system.
static func delete_resource_from_filesystem(resource:Resource) -> void:
    var delete_path = resource.resource_path
    print("ResourceUtil: Deleting file: " + delete_path)
    var dirAccess = DirAccess.open("res://")
    var result = dirAccess.remove(delete_path)
    if result != OK:
        push_error("ResourceUtil: Failed to delete resource: " + delete_path)
