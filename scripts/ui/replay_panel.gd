class_name ReplayPanel
extends VBoxContainer

var timeline := ReplayTimeline.new()
var map: ReplayMap
var slider: HSlider
var event_list: ItemList
var details: Label
var clock_label: Label
var play_button: Button
var report: MissionReport

func configure(data: Dictionary) -> void:
	timeline.configure(data.get("replay_frames", []), data.get("events", []))
	report = data.get("report") as MissionReport
	map = ReplayMap.new()
	map.world_size = data.get("world_size", Vector2(2000, 1200))
	map.custom_minimum_size.y = 290
	add_child(map)
	var controls := HBoxContainer.new()
	add_child(controls)
	play_button = Button.new()
	play_button.text = "ABSPIELEN / PAUSE"
	play_button.pressed.connect(func() -> void: timeline.playing = not timeline.playing)
	controls.add_child(play_button)
	var speed := OptionButton.new()
	for value in [1, 2, 4]:
		speed.add_item("%d×" % value, value)
	speed.item_selected.connect(func(index: int) -> void: timeline.speed = float(speed.get_item_id(index)))
	controls.add_child(speed)
	var reset := Button.new()
	reset.text = "GANZE KARTE"
	reset.pressed.connect(func() -> void: map.focus_position = null; map.queue_redraw())
	controls.add_child(reset)
	clock_label = Label.new()
	controls.add_child(clock_label)
	slider = HSlider.new()
	slider.max_value = maxf(timeline.duration, 0.1)
	slider.step = 0.1
	slider.value_changed.connect(func(value: float) -> void: timeline.seek(value); refresh())
	add_child(slider)
	event_list = ItemList.new()
	event_list.custom_minimum_size.y = 140
	for event in timeline.events:
		event_list.add_item("T+%06.1f  %s" % [float(event.simulation_time), ReplayTimeline.label(event)])
	event_list.item_selected.connect(select_event)
	add_child(event_list)
	details = Label.new()
	details.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	details.text = "Ereignis wählen: Die Karte fokussiert den betroffenen Kontakt oder Standort."
	add_child(details)
	refresh()

func _process(delta: float) -> void:
	if timeline.playing:
		timeline.advance(delta)
		refresh()

func select_event(index: int) -> void:
	if index < 0 or index >= timeline.events.size():
		return
	var event: Dictionary = timeline.events[index]
	timeline.playing = false
	timeline.seek(float(event.simulation_time))
	map.focus_position = timeline.event_position(event)
	details.text = ReplayTimeline.label(event)
	if report != null and event.type == &"infrastructure_damaged":
		var chain := report.build_causal_chain(int(event.index))
		var labels: PackedStringArray = []
		for cause in chain:
			var label := ReplayTimeline.label(cause)
			if not labels.has(label):
				labels.append(label)
		details.text += "\nVerlauf: " + " → ".join(labels)
	var cause: Variant = ReplayTimeline.nested(event, "cause")
	if cause != null:
		var reason: String = {"connection_disabled": "Leitung abgeschaltet", "source_unavailable": "Quelle nicht verfügbar", "recovering": "Versorgung wird wiederhergestellt", "no_connection": "Keine Verbindung", "": "Versorgung wiederhergestellt"}.get(String(cause), String(cause))
		details.text += "\n%s → %s: %s" % [str(ReplayTimeline.nested(event, "source_id")), str(ReplayTimeline.nested(event, "consumer_id")), reason]
	refresh()

func refresh() -> void:
	if map == null:
		return
	slider.set_value_no_signal(timeline.time)
	clock_label.text = "%05.1f / %05.1fs%s" % [timeline.time, timeline.duration, " ▶" if timeline.playing else " Ⅱ"]
	map.frame = timeline.get_frame()
	map.queue_redraw()
