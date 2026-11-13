class_name TestCase
extends RefCounted
## Base mínima de testes (sem dependências externas, roda em CI sem rede).
## Métodos que começam com "test_" são executados por tests/run_tests.gd.

var failures: Array[String] = []
var assertions: int = 0
var _current: String = ""


func set_current(test_name: String) -> void:
	_current = test_name


func _fail(msg: String) -> void:
	failures.append("%s: %s" % [_current, msg])


func assert_true(cond: bool, msg: String = "esperado verdadeiro") -> void:
	assertions += 1
	if not cond:
		_fail(msg)


func assert_false(cond: bool, msg: String = "esperado falso") -> void:
	assert_true(not cond, msg)


func assert_eq(actual: Variant, expected: Variant, msg: String = "") -> void:
	assertions += 1
	if actual != expected:
		_fail("%s (obtido=%s, esperado=%s)" % [msg, str(actual), str(expected)])


func assert_approx(actual: float, expected: float, eps: float = 0.0001, msg: String = "") -> void:
	assertions += 1
	if absf(actual - expected) > eps:
		_fail("%s (obtido=%s, esperado=%s)" % [msg, str(actual), str(expected)])


func assert_empty(list: Array, msg: String = "") -> void:
	assertions += 1
	if not list.is_empty():
		_fail("%s %s" % [msg, str(list)])
