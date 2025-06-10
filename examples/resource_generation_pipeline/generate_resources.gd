@tool
## Example script will generate a set of enemy resource files by mapping the
## enemies.csv into the enemies.gd resource script and save them into the /data folder
##
## Also, an example_enemy_ref.gd script will be generated providing static access to all ExampleEnemy resources.
extends EditorScript


# Paths are relative to this script
var ENEMIES_CSV_PATH:String  = rel_path("enemies.csv")
var SAVE_DIR:String = rel_path("example_output/data")
const ENEMY_ID_PARAM_NAME:String = "id"

# Resource script must have a class name defined
var CLASS_NAME = ExampleEnemy

func rel_path(path: String) -> String:
    var script_path: String = get_script().get_path().get_base_dir()
    return script_path.path_join(path)

## Entry point when the script is run from the Godot Editor.
##
## Loads CSV data into resource instances, validates it, merges with existing resources,
## saves new or updated resources, deletes obsolete ones, and refreshes the editor's file system.
func _run():

    # Parse and validate CSVs
    var csv_enemies:Array[ExampleEnemy]
    csv_enemies.assign(CSV.parse_csv_to_resource_list(CLASS_NAME, ENEMIES_CSV_PATH))
    assert( ResourceUtil.has_duplicate_ids(csv_enemies, ENEMY_ID_PARAM_NAME) == false, "Duplicate upgrade id detected, ending resource generation")

    #Create list of resource properties to merge, use the CSV headers
    var properties_to_merge := CSV.get_headers(ENEMIES_CSV_PATH)

    #Get all existing ExampleEnemy resources stored in the file system, merge CSV resource into existing ones
    var enemy_resources_to_update := ResourceUtil.load_resources_in_editor(CLASS_NAME)
    ResourceUtil.merge_resources_arrays(csv_enemies, enemy_resources_to_update, ENEMY_ID_PARAM_NAME, properties_to_merge, true)
    ResourceUtil.save_and_clean_all_resources_to_filesystem(CLASS_NAME, enemy_resources_to_update, SAVE_DIR, ENEMY_ID_PARAM_NAME)

    #Create refernece script for all Upgrades
    ResourceReferenceGenerator.create_reference_script(CLASS_NAME, ENEMY_ID_PARAM_NAME, SAVE_DIR)

    # Update editor after file changes
    EditorInterface.get_resource_filesystem().scan()
