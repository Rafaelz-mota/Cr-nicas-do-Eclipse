class_name XpCurve
extends RefCounted
## Curva de experiência configurável (balance.json -> xp.base / xp.exponent).

var base: float = 100.0
var exponent: float = 1.9
var max_level: int = 50


static func from_balance(balance: Dictionary) -> XpCurve:
	var curve := XpCurve.new()
	var xp: Dictionary = balance.get("xp", {})
	curve.base = float(xp.get("base", 100.0))
	curve.exponent = float(xp.get("exponent", 1.9))
	curve.max_level = int(balance.get("max_level", 50))
	return curve


## XP necessário para sair de `level` e ir para `level + 1`. 0 no nível máximo.
func xp_to_next(level: int) -> int:
	if level >= max_level:
		return 0
	return int(round(base * pow(float(level), exponent)))


## XP total acumulado necessário para alcançar `level` a partir do nível 1.
func total_xp_for_level(level: int) -> int:
	var total := 0
	for l in range(1, mini(level, max_level)):
		total += xp_to_next(l)
	return total
