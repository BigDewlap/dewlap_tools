@tool
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

## Merges property values from resources [code]source_resources[/code] into matching resources in [code]target_resources[/code].
## Matches occur on the value of the id property.  Only the properties defined are merged.
static func merge_resources_arrays(
	source_resources:Array,
	target_resources:Array,
	resource_id_property_name: String,
	properties_to_merge:Array[String]) -> void:

	var source_dictionary = resources_to_id_dictionary(source_resources, resource_id_property_name)
	var target_dictionary = resources_to_id_dictionary(target_resources, resource_id_property_name)

	for upgrade_id in source_dictionary.keys():
		var source_resource:Resource = source_dictionary.get(upgrade_id)
		var target_resource:Resource = target_dictionary.get(upgrade_id)
		if target_resource == null:
			prints("ResourceUtil: New entity: ", upgrade_id )
			target_dictionary.set(upgrade_id, source_resource)
			target_resources.append(source_resource)
		else:
			prints("ResourceUtil: Merging entity: ", upgrade_id )
			merge_resource_properties(source_resource, target_resource, properties_to_merge)

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
	var save_path = path + file_name + ".tres"
	print("ResourceUtil: Saving file: " + save_path)
	var result = ResourceSaver.save(resource, save_path)
	if result != OK:
		push_error("ResourceUtil: Failed to save resource to: " + save_path)

## Deletes a resource `.tres` file from the file system.
static func delete_resource_from_filesystem(resource:Resource) -> void:
	var delete_path = resource.resource_path
	print("ResourceUtil: Deleting file: " + delete_path)
	var dirAccess = DirAccess.open("res://")
	var result = dirAccess.remove(delete_path)
	if result != OK:
		push_error("ResourceUtil: Failed to delete resource: " + delete_path)
