@tool
extends VBoxContainer

## Expression Evaluator Panel
## Provides a UI for testing Godot Expression objects with variables and range testing

# UI Controls
@onready var parse_button: Button = %ParseButton
@onready var clear_button: Button = %ClearButton
@onready var load_from_resource_button: Button = %LoadFromResourceButton
@onready var expression_edit: TextEdit = %ExpressionEdit
@onready var variables_container: VBoxContainer = %VariablesContainer
@onready var add_variable_button: Button = %AddVariableButton
@onready var evaluate_button: Button = %EvaluateButton
@onready var test_range_button: Button = %TestRangeButton
@onready var result_value: RichTextLabel = %ResultValue
@onready var errors_display: RichTextLabel = %ErrorsDisplay
@onready var range_results_label: Label = %RangeResultsLabel
@onready var range_results_display: TextEdit = %RangeResultsDisplay
@onready var range_dialog: AcceptDialog = %RangeDialog
@onready var variable_option: OptionButton = %VariableOption
@onready var start_spin_box: SpinBox = %StartSpinBox
@onready var end_spin_box: SpinBox = %EndSpinBox
@onready var step_spin_box: SpinBox = %StepSpinBox

# State
var expression: Expression = Expression.new()
var variable_rows: Array[Dictionary] = []  # {name_edit: LineEdit, value_spin: SpinBox, container: HBoxContainer}
var updating: bool = false
var last_selected_resource: Resource = null

# Variable row scene (created programmatically)
const VARIABLE_ROW_HEIGHT: int = 30


func _ready() -> void:
	_connect_signals()
	_add_default_variable()


func _connect_signals() -> void:
	"""Connect all control signals."""
	parse_button.pressed.connect(_on_parse_button_pressed)
	clear_button.pressed.connect(_on_clear_button_pressed)
	load_from_resource_button.pressed.connect(_on_load_from_resource_pressed)
	add_variable_button.pressed.connect(_on_add_variable_pressed)
	evaluate_button.pressed.connect(_on_evaluate_button_pressed)
	test_range_button.pressed.connect(_on_test_range_button_pressed)
	range_dialog.confirmed.connect(_on_range_dialog_confirmed)
	expression_edit.text_changed.connect(_on_expression_text_changed)


func _add_default_variable() -> void:
	"""Add the default 'L' variable on startup."""
	_add_variable_row("L", 1)


func _on_add_variable_pressed() -> void:
	"""Add a new variable row."""
	_add_variable_row("", 0)


func _add_variable_row(var_name: String = "", var_value: float = 0) -> void:
	"""Create a new variable input row."""
	var row: HBoxContainer = HBoxContainer.new()
	row.custom_minimum_size.y = VARIABLE_ROW_HEIGHT

	# Variable name input
	var name_label: Label = Label.new()
	name_label.text = "Name:"
	name_label.custom_minimum_size.x = 50
	row.add_child(name_label)

	var name_edit: LineEdit = LineEdit.new()
	name_edit.text = var_name
	name_edit.placeholder_text = "variable"
	name_edit.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	name_edit.text_changed.connect(_on_variable_name_changed)
	row.add_child(name_edit)

	# Variable value input
	var value_label: Label = Label.new()
	value_label.text = "Value:"
	value_label.custom_minimum_size.x = 50
	row.add_child(value_label)

	var value_spin: SpinBox = SpinBox.new()
	value_spin.min_value = -10000
	value_spin.max_value = 10000
	value_spin.step = 0.1
	value_spin.value = var_value
	value_spin.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(value_spin)

	# Remove button
	var remove_button: Button = Button.new()
	remove_button.text = "Remove"
	remove_button.pressed.connect(_on_remove_variable_pressed.bind(row))
	row.add_child(remove_button)

	variables_container.add_child(row)

	# Track this row
	variable_rows.append({
		"name_edit": name_edit,
		"value_spin": value_spin,
		"container": row
	})


func _on_remove_variable_pressed(row: HBoxContainer) -> void:
	"""Remove a variable row."""
	# Find and remove from tracking array
	for i in range(variable_rows.size()):
		if variable_rows[i].container == row:
			variable_rows.remove_at(i)
			break

	# Remove from scene
	row.queue_free()


func _on_variable_name_changed(_new_text: String) -> void:
	"""Handle variable name changes - clear parse status."""
	_clear_errors()


func _on_expression_text_changed() -> void:
	"""Handle expression text changes."""
	_clear_errors()


func _on_parse_button_pressed() -> void:
	"""Parse the expression."""
	var expr_text: String = expression_edit.text.strip_edges()

	if expr_text.is_empty():
		_show_error("Expression is empty")
		return

	# Get variable names
	var var_names: PackedStringArray = _get_variable_names()

	# Parse expression
	expression = Expression.new()
	var error: int = expression.parse(expr_text, var_names)

	if error != OK:
		_show_error("Parse error: " + expression.get_error_text())
		return

	_show_success("Expression parsed successfully!")


func _on_evaluate_button_pressed() -> void:
	"""Evaluate the expression with current variable values."""
	# Auto-parse if needed
	if not _ensure_parsed():
		return

	# Get variable values
	var var_values: Array = _get_variable_values()

	# Execute expression
	var result: Variant = expression.execute(var_values)

	if expression.has_execute_failed():
		_show_error("Execution error: Expression failed to execute")
		return

	# Display result
	_show_result(result)
	_show_success("Evaluation successful")


func _on_test_range_button_pressed() -> void:
	"""Open dialog for range testing configuration."""
	# Auto-parse if needed
	if not _ensure_parsed():
		return

	# Populate variable dropdown
	variable_option.clear()
	var var_names: PackedStringArray = _get_variable_names()

	if var_names.size() == 0:
		_show_error("No variables defined for range testing")
		return

	for var_name in var_names:
		variable_option.add_item(var_name)

	# Show dialog
	range_dialog.popup_centered()


func _on_range_dialog_confirmed() -> void:
	"""Execute range testing."""
	if variable_option.selected == -1:
		return

	var test_var_name: String = variable_option.get_item_text(variable_option.selected)
	var start_val: float = start_spin_box.value
	var end_val: float = end_spin_box.value
	var step_val: float = step_spin_box.value

	if step_val <= 0:
		_show_error("Step must be greater than 0")
		return

	if start_val > end_val:
		_show_error("Start value must be less than or equal to end value")
		return

	# Get variable names and find index of test variable
	var var_names: PackedStringArray = _get_variable_names()
	var test_var_index: int = -1
	for i in range(var_names.size()):
		if var_names[i] == test_var_name:
			test_var_index = i
			break

	if test_var_index == -1:
		_show_error("Test variable not found")
		return

	# Execute range test
	var results: String = ""
	var current_val: float = start_val
	var iteration_count: int = 0
	var max_iterations: int = 1000  # Safety limit

	while current_val <= end_val and iteration_count < max_iterations:
		# Get variable values and override test variable
		var var_values: Array = _get_variable_values()
		var_values[test_var_index] = current_val

		# Execute
		var result: Variant = expression.execute(var_values)

		if expression.has_execute_failed():
			results += "%s=%s: ERROR\n" % [test_var_name, str(current_val)]
		else:
			results += "%s=%s: %s\n" % [test_var_name, str(current_val), str(result)]

		current_val += step_val
		iteration_count += 1

	# Display results
	range_results_display.text = results
	range_results_label.visible = true
	range_results_display.visible = true
	_show_success("Range test completed: %d iterations" % iteration_count)


func _on_clear_button_pressed() -> void:
	"""Clear all inputs and outputs."""
	expression_edit.text = ""
	result_value.text = "[color=gray]No result yet[/color]"
	errors_display.text = "[color=gray]No errors[/color]"
	range_results_display.text = ""
	range_results_label.visible = false
	range_results_display.visible = false

	# Clear all variables except keep empty array for manual addition
	for row_data in variable_rows:
		row_data.container.queue_free()
	variable_rows.clear()

	# Add default variable back
	_add_default_variable()


func _on_load_from_resource_pressed() -> void:
	"""Manually trigger loading from last selected resource."""
	if last_selected_resource:
		try_load_from_resource(last_selected_resource)
	else:
		_show_error("No resource selected. Select an Upgrade or similar resource in the editor.")


func try_load_from_resource(resource: Resource) -> void:
	"""Attempt to load expression from a resource (called by plugin on selection change)."""
	if not resource:
		return

	last_selected_resource = resource

	# Check if this is an Upgrade resource
	if resource.get_class() == "Resource" and resource.get("level_cost_exp") != null:
		var expr_str: String = resource.get("level_cost_exp")

		if expr_str and not expr_str.is_empty():
			updating = true
			expression_edit.text = expr_str

			# Check if "L" variable exists, if not add it
			var has_l_var: bool = false
			for row_data in variable_rows:
				if row_data.name_edit.text == "L":
					has_l_var = true
					break

			if not has_l_var:
				_add_variable_row("L", 1)

			updating = false
			var resource_name: String = resource.get("name") if resource.get("name") else "Unknown"
			_show_success("Loaded expression from resource: " + resource_name)


func _ensure_parsed() -> bool:
	"""Ensure expression is parsed, auto-parse if not."""
	var expr_text: String = expression_edit.text.strip_edges()

	if expr_text.is_empty():
		_show_error("Expression is empty")
		return false

	# Try to parse
	var var_names: PackedStringArray = _get_variable_names()
	expression = Expression.new()
	var error: int = expression.parse(expr_text, var_names)

	if error != OK:
		_show_error("Parse error: " + expression.get_error_text())
		return false

	return true


func _get_variable_names() -> PackedStringArray:
	"""Get array of variable names from the UI."""
	var names: PackedStringArray = []
	for row_data in variable_rows:
		var name: String = row_data.name_edit.text.strip_edges()
		if not name.is_empty():
			names.append(name)
	return names


func _get_variable_values() -> Array:
	"""Get array of variable values from the UI."""
	var values: Array = []
	for row_data in variable_rows:
		var name: String = row_data.name_edit.text.strip_edges()
		if not name.is_empty():
			values.append(row_data.value_spin.value)
	return values


func _show_result(result: Variant) -> void:
	"""Display evaluation result."""
	result_value.text = "[color=green][b]%s[/b][/color]" % str(result)


func _show_error(message: String) -> void:
	"""Display error message."""
	errors_display.text = "[color=red]Error: %s[/color]" % message


func _show_success(message: String) -> void:
	"""Display success message."""
	errors_display.text = "[color=green]%s[/color]" % message


func _clear_errors() -> void:
	"""Clear error/success messages."""
	if not updating:
		errors_display.text = "[color=gray]No errors[/color]"
