class_name Hud
extends CanvasLayer
## HUD construído por código (sem dependência de editor): barras, habilidades,
## joystick, missões, inventário, diálogo de NPC e tela de criação.

signal skill_pressed(slot: int)
signal interact_pressed
signal joystick_moved(vec: Vector2)
signal character_chosen(class_id: String, clan_id: String)
signal continue_chosen
signal equip_requested(uid: String)
signal use_requested(uid: String)
signal enhance_requested(uid: String)
signal repair_requested
signal point_requested(attr: String)
signal dialog_action(action: String, quest_id: String)

var data: GameDataStore
var hp_bar: ProgressBar
var mp_bar: ProgressBar
var xp_bar: ProgressBar
var info_label: Label
var quest_label: Label
var toast_label: Label
var skill_buttons: Array[Button] = []
var interact_button: Button
var bag_button: Button
var joystick: TouchJoystick
var inv_panel: PanelContainer
var inv_list: VBoxContainer
var dialog_panel: PanelContainer
var dialog_text: Label
var dialog_buttons: VBoxContainer
var select_panel: PanelContainer
var _toast_tween: Tween


func setup(p_data: GameDataStore, p_has_save: bool = false) -> void:
	data = p_data
	_build_hud()
	_build_inventory()
	_build_dialog()
	_build_select(p_has_save)


func _build_hud() -> void:
	var root := Control.new()
	root.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(root)

	var top := VBoxContainer.new()
	top.position = Vector2(16, 12)
	top.custom_minimum_size = Vector2(340, 0)
	top.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(top)
	info_label = Label.new()
	top.add_child(info_label)
	hp_bar = _bar(Color("#d94a4a"))
	mp_bar = _bar(Color("#4a7fe0"))
	xp_bar = _bar(Color("#d9b84a"))
	xp_bar.custom_minimum_size.y = 8
	top.add_child(hp_bar)
	top.add_child(mp_bar)
	top.add_child(xp_bar)

	quest_label = Label.new()
	quest_label.set_anchors_preset(Control.PRESET_TOP_RIGHT)
	quest_label.anchor_left = 1.0
	quest_label.anchor_right = 1.0
	quest_label.offset_left = -420
	quest_label.offset_right = -16
	quest_label.offset_top = 12
	quest_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	quest_label.autowrap_mode = TextServer.AUTOWRAP_WORD
	root.add_child(quest_label)

	toast_label = Label.new()
	toast_label.set_anchors_preset(Control.PRESET_CENTER_TOP)
	toast_label.anchor_left = 0.5
	toast_label.anchor_right = 0.5
	toast_label.offset_left = -300
	toast_label.offset_right = 300
	toast_label.offset_top = 90
	toast_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	toast_label.add_theme_font_size_override("font_size", 22)
	toast_label.modulate.a = 0.0
	root.add_child(toast_label)

	joystick = TouchJoystick.new()
	joystick.anchor_top = 1.0
	joystick.anchor_bottom = 1.0
	joystick.offset_left = 48
	joystick.offset_top = -270
	joystick.offset_right = 264
	joystick.offset_bottom = -54
	joystick.moved.connect(func(v): joystick_moved.emit(v))
	root.add_child(joystick)

	var skills := HBoxContainer.new()
	skills.anchor_left = 1.0
	skills.anchor_right = 1.0
	skills.anchor_top = 1.0
	skills.anchor_bottom = 1.0
	skills.offset_left = -720
	skills.offset_right = -56
	skills.offset_top = -210
	skills.offset_bottom = -48
	skills.alignment = BoxContainer.ALIGNMENT_END
	skills.add_theme_constant_override("separation", 14)
	skills.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(skills)
	for i in range(4):
		var b := Button.new()
		b.custom_minimum_size = Vector2(150, 150)
		b.add_theme_font_size_override("font_size", 20)
		b.focus_mode = Control.FOCUS_NONE
		b.visible = false
		var slot := i
		b.pressed.connect(func(): skill_pressed.emit(slot))
		skills.add_child(b)
		skill_buttons.append(b)

	interact_button = Button.new()
	interact_button.text = "Falar"
	interact_button.focus_mode = Control.FOCUS_NONE
	interact_button.custom_minimum_size = Vector2(150, 80)
	interact_button.anchor_left = 0.5
	interact_button.anchor_right = 0.5
	interact_button.anchor_top = 1.0
	interact_button.anchor_bottom = 1.0
	interact_button.offset_left = -75
	interact_button.offset_right = 75
	interact_button.offset_top = -180
	interact_button.offset_bottom = -100
	interact_button.visible = false
	interact_button.pressed.connect(func(): interact_pressed.emit())
	root.add_child(interact_button)

	bag_button = Button.new()
	bag_button.text = "Mochila"
	bag_button.focus_mode = Control.FOCUS_NONE
	bag_button.custom_minimum_size = Vector2(130, 64)
	bag_button.anchor_left = 1.0
	bag_button.anchor_right = 1.0
	bag_button.offset_left = -186
	bag_button.offset_right = -56
	bag_button.offset_top = 150
	bag_button.offset_bottom = 214
	bag_button.pressed.connect(toggle_inventory)
	root.add_child(bag_button)


func _bar(color: Color) -> ProgressBar:
	var b := ProgressBar.new()
	b.custom_minimum_size = Vector2(300, 18)
	b.show_percentage = false
	var fill := StyleBoxFlat.new()
	fill.bg_color = color
	b.add_theme_stylebox_override("fill", fill)
	return b


func _panel_style() -> StyleBoxFlat:
	var s := StyleBoxFlat.new()
	s.bg_color = Color(0.06, 0.05, 0.12, 0.92)
	s.set_corner_radius_all(10)
	s.set_content_margin_all(14)
	return s


func _build_inventory() -> void:
	inv_panel = PanelContainer.new()
	inv_panel.add_theme_stylebox_override("panel", _panel_style())
	inv_panel.anchor_left = 0.5
	inv_panel.anchor_right = 0.5
	inv_panel.anchor_top = 0.5
	inv_panel.anchor_bottom = 0.5
	inv_panel.offset_left = -330
	inv_panel.offset_right = 330
	inv_panel.offset_top = -280
	inv_panel.offset_bottom = 280
	inv_panel.visible = false
	add_child(inv_panel)
	var scroll := ScrollContainer.new()
	inv_panel.add_child(scroll)
	inv_list = VBoxContainer.new()
	inv_list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	inv_list.add_theme_constant_override("separation", 6)
	scroll.add_child(inv_list)


func _build_dialog() -> void:
	dialog_panel = PanelContainer.new()
	dialog_panel.add_theme_stylebox_override("panel", _panel_style())
	dialog_panel.anchor_left = 0.5
	dialog_panel.anchor_right = 0.5
	dialog_panel.anchor_top = 1.0
	dialog_panel.anchor_bottom = 1.0
	dialog_panel.offset_left = -330
	dialog_panel.offset_right = 330
	dialog_panel.offset_top = -330
	dialog_panel.offset_bottom = -20
	dialog_panel.visible = false
	add_child(dialog_panel)
	var v := VBoxContainer.new()
	dialog_panel.add_child(v)
	dialog_text = Label.new()
	dialog_text.autowrap_mode = TextServer.AUTOWRAP_WORD
	dialog_text.custom_minimum_size.x = 620
	v.add_child(dialog_text)
	dialog_buttons = VBoxContainer.new()
	v.add_child(dialog_buttons)


func _build_select(has_save: bool = false) -> void:
	select_panel = PanelContainer.new()
	select_panel.add_theme_stylebox_override("panel", _panel_style())
	select_panel.set_anchors_preset(Control.PRESET_CENTER)
	select_panel.anchor_left = 0.5
	select_panel.anchor_right = 0.5
	select_panel.anchor_top = 0.5
	select_panel.anchor_bottom = 0.5
	select_panel.offset_left = -300
	select_panel.offset_right = 300
	select_panel.offset_top = -300
	select_panel.offset_bottom = 300
	add_child(select_panel)
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 10)
	select_panel.add_child(v)
	var title := Label.new()
	title.text = "Crônicas do Eclipse"
	title.add_theme_font_size_override("font_size", 28)
	v.add_child(title)
	if has_save:
		var cont := Button.new()
		cont.text = "Continuar personagem salvo"
		cont.custom_minimum_size.y = 90
		cont.pressed.connect(func():
			select_panel.visible = false
			continue_chosen.emit())
		v.add_child(cont)
	var note := Label.new()
	note.text = "Novo personagem (substitui o salvo). Qualquer classe combina com qualquer clã." if has_save \
		else "Criar personagem. Qualquer classe combina com qualquer clã."
	note.autowrap_mode = TextServer.AUTOWRAP_WORD
	v.add_child(note)

	var class_opt := OptionButton.new()
	for cid in data.classes:
		class_opt.add_item("%s — %s" % [data.classes[cid]["name"], data.classes[cid]["role"]])
		class_opt.set_item_metadata(class_opt.item_count - 1, cid)
	class_opt.custom_minimum_size.y = 64
	var clan_opt := OptionButton.new()
	for kid in data.clans:
		clan_opt.add_item("%s — %s" % [data.clans[kid]["name"], data.clans[kid]["theme"]])
		clan_opt.set_item_metadata(clan_opt.item_count - 1, kid)
	clan_opt.custom_minimum_size.y = 64
	var l1 := Label.new()
	l1.text = "Classe"
	var l2 := Label.new()
	l2.text = "Clã"
	v.add_child(l1)
	v.add_child(class_opt)
	v.add_child(l2)
	v.add_child(clan_opt)
	var go := Button.new()
	go.text = "Entrar no mundo"
	go.custom_minimum_size.y = 80
	go.pressed.connect(func():
		select_panel.visible = false
		character_chosen.emit(class_opt.get_item_metadata(class_opt.selected), clan_opt.get_item_metadata(clan_opt.selected)))
	v.add_child(go)


func configure_skill_buttons(character: CharacterData) -> void:
	var ids := character.skill_ids()
	for i in range(skill_buttons.size()):
		var b := skill_buttons[i]
		if i < ids.size():
			b.visible = true
			b.text = data.skills[ids[i]]["name"]
		else:
			b.visible = false


func update_hud(character: CharacterData, combatant: Combatant) -> void:
	var nxt := character.xp_curve.xp_to_next(character.level)
	info_label.text = "%s  Nv%d  %s / %s  |  Gold %d%s" % [
		character.char_name, character.level,
		data.classes[character.class_id]["name"], data.clans[character.clan_id]["name"],
		character.gold, ("  |  Pontos: %d" % character.free_points) if character.free_points > 0 else ""]
	hp_bar.max_value = combatant.get_stat("max_hp")
	hp_bar.value = combatant.hp
	mp_bar.max_value = maxf(1.0, combatant.get_stat("max_mp"))
	mp_bar.value = combatant.mp
	xp_bar.max_value = maxf(1.0, float(nxt))
	xp_bar.value = float(character.xp)
	var ids := character.skill_ids()
	for i in range(mini(ids.size(), skill_buttons.size())):
		var sk: Dictionary = data.skills[ids[i]]
		var cd: float = float(combatant.cooldowns.get(ids[i], 0.0))
		var locked: bool = character.level < int(sk.get("level_required", 1))
		var suffix := ""
		if locked:
			suffix = "\nNv%d" % int(sk["level_required"])
		elif cd > 0.0:
			suffix = "\n%.1fs" % cd
		skill_buttons[i].text = str(sk["name"]) + suffix
		skill_buttons[i].disabled = locked or cd > 0.0

	var lines: PackedStringArray = []
	for qid in character.quest_log.active:
		var t := character.quest_log.progress_text(qid)
		if character.quest_log.is_ready(qid):
			t += "  [pronta]"
		lines.append(t)
	quest_label.text = "\n".join(lines)


func toast(text: String) -> void:
	toast_label.text = text
	toast_label.modulate.a = 1.0
	if _toast_tween != null and _toast_tween.is_valid():
		_toast_tween.kill()
	_toast_tween = create_tween()
	_toast_tween.tween_interval(2.2)
	_toast_tween.tween_property(toast_label, "modulate:a", 0.0, 0.6)


func toggle_inventory() -> void:
	inv_panel.visible = not inv_panel.visible
	dialog_panel.visible = false


func refresh_inventory(character: CharacterData) -> void:
	for c in inv_list.get_children():
		c.queue_free()
	var head := Label.new()
	head.text = "Mochila %d/%d   Gold: %d   Pontos livres: %d" % [character.inventory.slots.size(), character.inventory.capacity, character.gold, character.free_points]
	inv_list.add_child(head)

	if character.free_points > 0:
		var row := HBoxContainer.new()
		for a in CombatStats.ATTRIBUTES:
			var b := Button.new()
			b.text = "+%s" % a.substr(0, 3).to_upper()
			b.custom_minimum_size = Vector2(90, 56)
			var attr: String = a
			b.pressed.connect(func(): point_requested.emit(attr))
			row.add_child(b)
		inv_list.add_child(row)

	var sep1 := Label.new()
	sep1.text = "— Equipado —"
	inv_list.add_child(sep1)
	for slot in character.equipment.worn:
		inv_list.add_child(_item_row(character.equipment.worn[slot], slot))
	var cost := character.equipment.repair_cost(data)
	if cost > 0:
		var rb := Button.new()
		rb.text = "Reparar equipamento (%d gold)" % cost
		rb.custom_minimum_size.y = 56
		rb.pressed.connect(func(): repair_requested.emit())
		inv_list.add_child(rb)

	var sep2 := Label.new()
	sep2.text = "— Mochila —"
	inv_list.add_child(sep2)
	for inst in character.inventory.slots:
		inv_list.add_child(_item_row(inst, ""))


func _item_row(inst: ItemInstance, worn_slot: String) -> Control:
	var def: Dictionary = data.items[inst.item_id]
	var row := HBoxContainer.new()
	var name_label := Label.new()
	var txt: String = def["name"]
	if inst.enhance > 0:
		txt += " +%d" % inst.enhance
	if inst.count > 1:
		txt += " x%d" % inst.count
	if int(def.get("durability_max", 0)) > 0:
		txt += "  [%d/%d]" % [inst.durability, int(def["durability_max"])]
	name_label.text = txt
	name_label.modulate = Color(data.rarities[def["rarity"]]["color"])
	name_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(name_label)
	var type: String = def.get("type", "")
	if worn_slot == "" and (type == "weapon" or type == "armor"):
		var eb := Button.new()
		eb.text = "Equipar"
		eb.custom_minimum_size = Vector2(110, 52)
		var uid := inst.uid
		eb.pressed.connect(func(): equip_requested.emit(uid))
		row.add_child(eb)
	if worn_slot == "" and type == "consumable":
		var ub := Button.new()
		ub.text = "Usar"
		ub.custom_minimum_size = Vector2(110, 52)
		var uid2 := inst.uid
		ub.pressed.connect(func(): use_requested.emit(uid2))
		row.add_child(ub)
	if type == "weapon" or type == "armor":
		var step := Enhancement.next_step(inst, data)
		if not step.is_empty():
			var nb := Button.new()
			nb.text = "+%d (%dg, %d%%)" % [inst.enhance + 1, int(step["gold"]), int(float(step["success"]) * 100.0)]
			nb.custom_minimum_size = Vector2(190, 52)
			var uid3 := inst.uid
			nb.pressed.connect(func(): enhance_requested.emit(uid3))
			row.add_child(nb)
	return row


func show_dialog(text: String, actions: Array) -> void:
	inv_panel.visible = false
	dialog_text.text = text
	for c in dialog_buttons.get_children():
		c.queue_free()
	for a in actions:
		var b := Button.new()
		b.text = a["label"]
		b.custom_minimum_size.y = 60
		var act: String = a["action"]
		var qid: String = a.get("quest", "")
		b.pressed.connect(func(): dialog_action.emit(act, qid))
		dialog_buttons.add_child(b)
	dialog_panel.visible = true


func hide_dialog() -> void:
	dialog_panel.visible = false
