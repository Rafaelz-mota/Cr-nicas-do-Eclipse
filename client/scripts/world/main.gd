extends Node3D
## Cena principal: monta o mundo de demonstração (clareira + NPC + monstros),
## liga HUD, câmera 2.5D, jogador, combate e missões.

const ARENA_HALF := 22.0
const PLAYER_SPAWN := Vector3(0, 0.1, 6)

var data: GameDataStore
var hud: Hud
var camera: IsoCamera
var player: PlayerActor
var character: CharacterData
var spawn_points: Array = []  # {"id": String, "pos": Vector3}
var _dialog_npc: NpcActor = null
var _smoke_mode := false
var _save_enabled := true


func _ready() -> void:
	data = GameDataStore.load_default()
	var errs := data.validate()
	if not errs.is_empty():
		for e in errs:
			printerr("[dados] " + e)

	_build_environment()
	_build_ground()
	_build_props()

	hud = Hud.new()
	add_child(hud)
	_save_enabled = not ("--smoke" in OS.get_cmdline_user_args())
	hud.setup(data, _save_enabled and SaveService.exists())
	hud.character_chosen.connect(func(cls, clan): _start_game(CharacterData.create_new(data, "Viajante", cls, clan)))
	hud.continue_chosen.connect(_on_continue)
	hud.skill_pressed.connect(_on_skill_pressed)
	hud.interact_pressed.connect(_on_interact)
	hud.dialog_action.connect(_on_dialog_action)
	hud.equip_requested.connect(func(uid): _after(character.equip_item(uid)))
	hud.use_requested.connect(_on_use_item)
	hud.enhance_requested.connect(_on_enhance)
	hud.repair_requested.connect(func():
		hud.toast("Equipamento reparado" if character.repair_equipment() else "Gold insuficiente"); _refresh_bag())
	hud.point_requested.connect(func(a):
		character.allocate_point(a); player.refresh_stats(); _refresh_bag())

	camera = IsoCamera.new()
	add_child(camera)
	camera.current = true

	# Modo de verificação automática (CI): --smoke inicia sozinho e sai.
	if "--smoke" in OS.get_cmdline_user_args():
		_smoke_mode = true
		hud.select_panel.visible = false
		_start_game(CharacterData.create_new(data, "Viajante", "vanguarda", "veu_cinzento"))
		_run_smoke()


func _build_environment() -> void:
	var env := Environment.new()
	env.background_mode = Environment.BG_COLOR
	env.background_color = Color("#1b1840")
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color("#8c86c9")
	env.ambient_light_energy = 0.7
	var we := WorldEnvironment.new()
	we.environment = env
	add_child(we)
	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-55, 35, 0)
	sun.light_energy = 1.1
	sun.light_color = Color("#ffe2b8")
	sun.shadow_enabled = true  # sombras; desligável em aparelhos fracos
	sun.directional_shadow_max_distance = 40.0
	add_child(sun)


func _build_ground() -> void:
	var body := StaticBody3D.new()
	var col := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = Vector3(ARENA_HALF * 2.0, 1.0, ARENA_HALF * 2.0)
	col.shape = box
	col.position.y = -0.5
	body.add_child(col)
	var mesh := MeshInstance3D.new()
	var plane := PlaneMesh.new()
	plane.size = Vector2(ARENA_HALF * 8.0, ARENA_HALF * 8.0)  # bem maior que a área jogável: sem "buraco" nas bordas da tela
	mesh.mesh = plane
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color("#3d6b46")
	mat.roughness = 1.0
	mesh.material_override = mat
	body.add_child(mesh)
	add_child(body)

	# Paredes invisíveis delimitam a área de demonstração.
	for s in [[Vector3(0, 2, -ARENA_HALF), Vector3(ARENA_HALF * 2, 4, 1)], [Vector3(0, 2, ARENA_HALF), Vector3(ARENA_HALF * 2, 4, 1)],
			[Vector3(-ARENA_HALF, 2, 0), Vector3(1, 4, ARENA_HALF * 2)], [Vector3(ARENA_HALF, 2, 0), Vector3(1, 4, ARENA_HALF * 2)]]:
		var w := StaticBody3D.new()
		var wc := CollisionShape3D.new()
		var ws := BoxShape3D.new()
		ws.size = s[1]
		wc.shape = ws
		w.position = s[0]
		w.add_child(wc)
		add_child(w)


func _build_props() -> void:
	# Cenário provisório: árvores e rochas simples (substituíveis por modelos reais).
	var rng := RandomNumberGenerator.new()
	rng.seed = 2026
	for i in range(34):
		var p := Vector3(rng.randf_range(-ARENA_HALF + 2, ARENA_HALF - 2), 0, rng.randf_range(-ARENA_HALF + 2, ARENA_HALF - 2))
		if Vector2(p.x, p.z).distance_to(Vector2(0, 6)) < 5.0 or Vector2(p.x, p.z).distance_to(Vector2(-4, 3)) < 3.0:
			continue
		if rng.randf() < 0.7:
			_add_tree(p, rng.randf_range(0.8, 1.4))
		else:
			_add_rock(p, rng.randf_range(0.6, 1.2))

	# Pontos de nascimento de monstros.
	for sp in [["gosmante_musgoso", Vector3(8, 0.1, -2)], ["gosmante_musgoso", Vector3(12, 0.1, 4)], ["gosmante_musgoso", Vector3(6, 0.1, -9)],
			["gosmante_musgoso", Vector3(-10, 0.1, -6)], ["lobo_cinzento", Vector3(-12, 0.1, -12)], ["lobo_cinzento", Vector3(14, 0.1, -12)]]:
		spawn_points.append({"id": sp[0], "pos": sp[1]})


func _add_tree(pos: Vector3, scale_f: float) -> void:
	var body := StaticBody3D.new()
	body.position = pos
	var trunk := MeshInstance3D.new()
	var cyl := CylinderMesh.new()
	cyl.top_radius = 0.2 * scale_f
	cyl.bottom_radius = 0.28 * scale_f
	cyl.height = 1.6 * scale_f
	trunk.mesh = cyl
	trunk.position.y = 0.8 * scale_f
	trunk.material_override = VisualSlot._material(Color("#6b4a2f"))
	body.add_child(trunk)
	var crown := MeshInstance3D.new()
	var cone := CylinderMesh.new()
	cone.top_radius = 0.0
	cone.bottom_radius = 1.2 * scale_f
	cone.height = 2.6 * scale_f
	crown.mesh = cone
	crown.position.y = 2.6 * scale_f
	crown.material_override = VisualSlot._material(Color("#2c6b3a"))
	body.add_child(crown)
	var col := CollisionShape3D.new()
	var shape := CylinderShape3D.new()
	shape.radius = 0.5 * scale_f
	shape.height = 3.0
	col.shape = shape
	col.position.y = 1.5
	body.add_child(col)
	add_child(body)


func _add_rock(pos: Vector3, scale_f: float) -> void:
	var body := StaticBody3D.new()
	body.position = pos
	var m := MeshInstance3D.new()
	var s := SphereMesh.new()
	s.radius = 0.8 * scale_f
	s.height = 1.2 * scale_f
	m.mesh = s
	m.position.y = 0.4 * scale_f
	m.material_override = VisualSlot._material(Color("#7a7a85"))
	body.add_child(m)
	var col := CollisionShape3D.new()
	var shape := SphereShape3D.new()
	shape.radius = 0.8 * scale_f
	col.shape = shape
	col.position.y = 0.4 * scale_f
	body.add_child(col)
	add_child(body)


func _on_continue() -> void:
	var loaded := SaveService.load_character(data)
	if loaded == null:
		# Save ausente ou inválido: não deixa o jogador preso numa tela vazia.
		hud.select_panel.visible = true
		hud.toast("Não foi possível carregar o salvamento. Crie um novo personagem.")
		return
	_start_game(loaded)
	hud.toast("Personagem carregado.")


func _save_now() -> void:
	if _save_enabled and character != null:
		SaveService.save(character)


func _notification(what: int) -> void:
	# Fechar o jogo no PC ou mandá-lo para segundo plano no Android também salva.
	if what == NOTIFICATION_WM_CLOSE_REQUEST or what == NOTIFICATION_APPLICATION_PAUSED:
		_save_now()


func _start_game(p_character: CharacterData) -> void:
	character = p_character
	player = PlayerActor.new()
	add_child(player)
	player.setup(data, character)
	player.global_position = PLAYER_SPAWN
	player.hit_dealt.connect(func(_t, _r): _refresh_bag_if_open())
	player.skill_failed.connect(_on_skill_failed)
	player.died.connect(_on_player_died)
	character.leveled_up.connect(func(lv): hud.toast("Nível %d!" % lv); _refresh_bag_if_open(); _save_now())
	var autosave := Timer.new()
	autosave.wait_time = 20.0
	autosave.autostart = true
	autosave.timeout.connect(_save_now)
	add_child(autosave)
	_save_now()
	hud.joystick_moved.connect(func(v): player.touch_move = v)
	hud.configure_skill_buttons(character)

	for nid in data.npcs:
		var npc := NpcActor.new()
		add_child(npc)
		npc.setup(data.npcs[nid])
	for sp in spawn_points:
		_spawn_monster(sp["id"], sp["pos"])

	camera.target = player
	camera.snap_to_target()
	hud.toast("Fale com Maren para receber a primeira missão.")


func _spawn_monster(monster_id: String, pos: Vector3) -> void:
	var mon := MonsterActor.new()
	add_child(mon)
	mon.setup(data.monsters[monster_id], data, pos)
	mon.died.connect(func(m, killer): _on_monster_died(m, killer, pos))


func _on_monster_died(monster: MonsterActor, killer: Node3D, pos: Vector3) -> void:
	if killer is PlayerActor:
		var summary := RewardService.grant_kill(character, monster.def, player.rng)
		var parts: PackedStringArray = ["+%d XP" % summary["xp"], "+%d Gold" % summary["gold"]]
		for it in summary["items"]:
			parts.append("%s x%d" % [data.items[it["id"]]["name"], it["count"]])
		hud.toast(", ".join(parts))
		player.refresh_stats()
		_refresh_bag_if_open()
	var delay: float = float(data.balance.get("respawn", {}).get("monster_seconds", 10.0))
	get_tree().create_timer(delay).timeout.connect(func(): _spawn_monster(monster.def["id"], pos))


func _on_player_died() -> void:
	hud.toast("Você caiu... renascendo.")
	var delay: float = float(data.balance.get("respawn", {}).get("player_seconds", 3.0))
	get_tree().create_timer(delay).timeout.connect(func(): player.revive_at(PLAYER_SPAWN))


func _on_skill_failed(reason: String) -> void:
	var msgs := {"mana": "Mana insuficiente", "recarga": "Em recarga", "nivel": "Nível insuficiente", "sem_alvo": "Sem alvo ao alcance", "morto": ""}
	var m: String = msgs.get(reason, "")
	if m != "":
		hud.toast(m)


func _on_skill_pressed(slot: int) -> void:
	if player != null:
		player.use_skill_slot(slot)


func _unhandled_input(event: InputEvent) -> void:
	if player == null or not (event is InputEventKey) or not event.pressed or event.echo:
		return
	match event.physical_keycode:
		KEY_1, KEY_J: player.use_skill_slot(0)
		KEY_2, KEY_K: player.use_skill_slot(1)
		KEY_3: player.use_skill_slot(2)
		KEY_4: player.use_skill_slot(3)
		KEY_E: _on_interact()
		KEY_I: hud.toggle_inventory(); _refresh_bag()


func _nearby_npc() -> NpcActor:
	if player == null:
		return null
	for n in get_tree().get_nodes_in_group("npcs"):
		if n.global_position.distance_to(player.global_position) < 3.2:
			return n
	return null


func _process(_delta: float) -> void:
	if player == null or character == null:
		return
	hud.update_hud(character, player.combatant)
	hud.interact_button.visible = _nearby_npc() != null and not hud.dialog_panel.visible
	if hud.dialog_panel.visible and _dialog_npc != null and _dialog_npc.global_position.distance_to(player.global_position) > 5.0:
		hud.hide_dialog()


func _on_interact() -> void:
	var npc := _nearby_npc()
	if npc == null:
		return
	_dialog_npc = npc
	_open_dialog(npc)


func _open_dialog(npc: NpcActor) -> void:
	var log := character.quest_log
	var text: String = "\n".join(npc.def.get("dialogue", []))
	var actions: Array = []
	for qid in log.ready_for_npc(npc.npc_id):
		actions.append({"label": "Entregar: %s" % data.quests[qid]["title"], "action": "turn_in", "quest": qid})
	for qid in log.available_for_npc(npc.npc_id, character.level):
		var q: Dictionary = data.quests[qid]
		text += "\n\n[%s] %s" % [q["title"], q["description"]]
		actions.append({"label": "Aceitar: %s" % q["title"], "action": "accept", "quest": qid})
	actions.append({"label": "Fechar", "action": "close"})
	hud.show_dialog(text, actions)


func _on_dialog_action(action: String, quest_id: String) -> void:
	match action:
		"accept":
			character.quest_log.accept(quest_id, character.level)
			hud.toast("Missão aceita: %s" % data.quests[quest_id]["title"])
			_open_dialog(_dialog_npc)
		"turn_in":
			var rewards := character.quest_log.turn_in(quest_id)
			var summary := character.grant_rewards(rewards)
			player.refresh_stats()
			hud.toast("Missão concluída! +%d XP, +%d Gold" % [summary["xp"], summary["gold"]])
			_save_now()
			_open_dialog(_dialog_npc)
		_:
			hud.hide_dialog()


func _on_use_item(uid: String) -> void:
	var effect := character.use_consumable(uid)
	if effect.has("heal"):
		player.combatant.heal(int(effect["heal"]))
		hud.toast("+%d vida" % int(effect["heal"]))
	_refresh_bag()


func _on_enhance(uid: String) -> void:
	var r := character.enhance_item(uid, player.rng)
	if not r["ok"]:
		hud.toast("Não foi possível amplificar (%s)" % r["reason"])
	elif r["success"]:
		hud.toast("Amplificação bem-sucedida!")
	else:
		hud.toast("A amplificação falhou (o item está seguro).")
	player.refresh_stats()
	_refresh_bag()


func _after(result: Dictionary) -> void:
	if not result["ok"]:
		var msgs := {"nivel": "Nível insuficiente", "tipo_de_arma": "Sua classe não usa esta arma", "nao_equipavel": "Não equipável"}
		hud.toast(msgs.get(result["reason"], "Não foi possível equipar"))
	player.refresh_stats()
	_refresh_bag()


func _refresh_bag() -> void:
	if hud.inv_panel.visible:
		hud.refresh_inventory(character)


func _refresh_bag_if_open() -> void:
	_refresh_bag()


## Verificação automática para CI: roda alguns segundos de simulação e sai.
func _run_smoke() -> void:
	await get_tree().create_timer(0.5).timeout
	var ok := true
	var monsters := get_tree().get_nodes_in_group("monsters")
	if monsters.size() != spawn_points.size():
		printerr("SMOKE FALHOU: monstros=%d esperados=%d" % [monsters.size(), spawn_points.size()])
		ok = false
	# Teleporta ao lado do primeiro monstro e ataca até matar.
	var m: MonsterActor = monsters[0]
	player.global_position = m.global_position + Vector3(0, 0, 2.0)
	var guard := 0
	while is_instance_valid(m) and m.combatant.is_alive() and guard < 400:
		player.use_skill_slot(0)
		await get_tree().create_timer(0.1).timeout
		guard += 1
	if character.xp <= 0 and character.level == 1:
		printerr("SMOKE FALHOU: sem XP após matar monstro")
		ok = false
	if character.gold <= 0:
		printerr("SMOKE FALHOU: sem gold após matar monstro")
		ok = false
	print("SMOKE: monstros=%d xp=%d gold=%d nivel=%d camera_y=%.1f" % [monsters.size(), character.xp, character.gold, character.level, camera.global_position.y])
	get_tree().quit(0 if ok else 1)
