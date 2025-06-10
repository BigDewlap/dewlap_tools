# Dewlap Tools

Collection of scripts that provide helpful functionality or enabled improved workflows

## Classes
### CSV
Utility class for parsing CSV files into a collection of Resources.

### ResourceUtil
This class provides a collection of static helper functions for managing project resources
  - Loading `.tres` files from disk
  - Mapping resources to dictionaries by ID
  - Merging resource data
  - Saving and deleting `.tres` files

### ResourceReferenceGenerator
 Utility for generating static reference scripts for Resource types.

 This class creates a new script for each Resource type that is stored as a standalone file in the project, exposing constants and
 static accessor methods for each resource based on its ID. The generated script
 allows accessing resources like:

 ```
 UpgradeRef.getr("wood_sword")
 UpgradeRef.getr_wood_sword()
 UpgradeRef.WOOD_SWORD
 ```

 All resources are indexed at generation time using their identity property and path.

 **Example usage:**
 ```
 ResourceReferenceGenerator.create_reference_script(Upgrade, "id")
 ```
