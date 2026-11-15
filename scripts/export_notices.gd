extends SceneTree
## Generate notices from the exact Godot version bundled in each release.

func _initialize() -> void:
	var args := OS.get_cmdline_user_args()
	if args.size() != 1:
		push_error("Expected output notice path")
		quit(1)
		return
	var output := FileAccess.open(args[0], FileAccess.WRITE)
	if output == null:
		push_error("Cannot write third-party notices")
		quit(1)
		return
	output.store_string("Godot Engine\n=============\n\n" + Engine.get_license_text() + "\n\n")
	output.store_string("Third-party component copyrights\n================================\n\n")
	output.store_string(JSON.stringify(Engine.get_copyright_info(), "  ") + "\n\n")
	var licenses := Engine.get_license_info()
	var names := licenses.keys()
	names.sort()
	for name in names:
		output.store_string(str(name) + "\n" + "=".repeat(str(name).length()) + "\n\n" + str(licenses[name]) + "\n\n")
	output.close()
	quit()
