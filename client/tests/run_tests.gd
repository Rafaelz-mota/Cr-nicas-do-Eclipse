extends SceneTree
## Executa todos os tests/unit/test_*.gd.
## Uso: godot --headless --path client -s res://tests/run_tests.gd
## Código de saída 0 = tudo passou; 1 = alguma falha.

const UNIT_DIR := "res://tests/unit/"


func _initialize() -> void:
	var files: Array[String] = []
	for f in DirAccess.get_files_at(UNIT_DIR):
		if f.begins_with("test_") and f.ends_with(".gd"):
			files.append(f)
	files.sort()

	var total_tests := 0
	var total_asserts := 0
	var all_failures: Array[String] = []

	for f in files:
		var script: GDScript = load(UNIT_DIR + f)
		if script == null:
			all_failures.append("%s: não foi possível carregar o script" % f)
			continue
		var tc: TestCase = script.new()
		for m in script.get_script_method_list():
			var mname: String = m["name"]
			if mname.begins_with("test_"):
				tc.set_current("%s::%s" % [f, mname])
				total_tests += 1
				tc.call(mname)
		total_asserts += tc.assertions
		all_failures.append_array(tc.failures)

	print("")
	print("Testes executados: %d | Asserções: %d | Falhas: %d" % [total_tests, total_asserts, all_failures.size()])
	for fl in all_failures:
		printerr("FALHA  " + fl)
	quit(1 if all_failures.size() > 0 or total_tests == 0 else 0)
