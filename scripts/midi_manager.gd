extends MidiPlayer
class_name MidiManager

const KEY = preload("res://scenes/objects/key_running.tscn")
const KEY_BAD = preload("res://scenes/objects/key_running_bad.tscn")
const KEY_SWITCH = preload("res://scenes/objects/key_running_switch.tscn")
const KEY_COMBO = preload("res://scenes/objects/key_running_combo.tscn")

#@export var note_colors : Array[Color] = [
	#Color.hex(0xff4747),
	#Color.hex(0x2cff2c),
	#Color.hex(0x4343ff),
#]

@onready var running_parent = $Running

@export var audio: AudioStream
@export var approach_duration: float = 2 #11.25
@export var note_height: int = 16
@export var note_width: int = 16
@export var trigger_line_x: float = 70
@export var perfect_line_x: float = 66.0
@export var play_line_x: float = 64.0
@export var play_line_y: float = 144.0
@export var switch_line_x: float = 160.0
@export var debug: bool = false

@export var perfect_threshold: float = 1
@export var fear: int = 5
@export var combo_heal: int = 3
@export var faith_penalty: int = 2

@export var keys: Array[String] = ["up", "down"]

const NONE = 0
const PRESSED = 1
const HOLDING = 2
const RELEASED = 3

var key_state = {}
var notes: Array = []
var _next_combo_id: int = 0
var key_lockout: Dictionary = {}

const MISS_LOCKOUT_DURATION: float = 0.16
const SWITCH_TELEGRAPH_DISTANCE: float = 30.0

@onready var key_listeners: Array = [$UpKey, $DownKey]

func _ready() -> void:
	self.finished.connect(_on_finished)

	for key in keys:
		self.key_state[key] = NONE

const NOTE_OFFSET = 48

func start() -> void:
	is_finished = false
	var asp = $AudioStreamPlayer
	asp.stream = self.audio
	
	self.link_audio_stream_player([asp])
	
	var microseconds_per_tick: float = float(self.midi.tempo) / float(self.midi.division)
	var seconds_per_tick: float = microseconds_per_tick / 1000000.0
	
	var temp_notes = []
	
	for track in self.midi.tracks:
		var last_note: Variant = null
		var last_combo_notes: Array = []
		var time: float = 0
		
		for event in track.events:
			time += event.delta * seconds_per_tick
			if event['type'] == 'note':
				if event.subtype == MIDI_MESSAGE_NOTE_ON:
					if event.note < NOTE_OFFSET or event.note > NOTE_OFFSET + 8:
						push_warning("Note ", event.note, " is out of range!")
						continue
					
					var is_long = event.note >= NOTE_OFFSET + 2 and event.note < NOTE_OFFSET + 4 # 26-27
					var is_bad = event.note >= NOTE_OFFSET + 6 and event.note < NOTE_OFFSET + 8 # 28-29
					var is_switch = event.note >= NOTE_OFFSET + 4 and event.note < NOTE_OFFSET + 6 # 30-31
					var is_combo = event.note == NOTE_OFFSET + 8 # 32
					
					print(event.note, " long: ", is_long, "; bad: ", is_bad, "; switch: ", is_switch, "; combo: ", is_combo)
					var lane: int = (event.note % 2) + 1
					var target_lane: int = lane
					
					if is_switch:
						target_lane = 2 if lane == 1 else 1

					if is_combo:
						var combo_id = _next_combo_id
						_next_combo_id += 1
						last_combo_notes = []
						for combo_lane in range(len(self.keys)):
							var combo_note = {
								"time": time,
								"duration": 1,
								"bad": false,
								"lane": combo_lane + 1,
								"target_lane": combo_lane + 1,
								"combo_id": combo_id,
							}
							temp_notes.append(combo_note)
							last_combo_notes.append(combo_note)
						last_note = last_combo_notes[0]
					else:
						last_note = {
							"time": time,
							"duration": 0 if is_long else 1,
							"bad": is_bad,
							"lane": lane,
							"target_lane": target_lane,
							"combo_id": -1,
						}
						temp_notes.append(last_note)

				if event.subtype == MIDI_MESSAGE_NOTE_OFF and last_note != null:
					if last_combo_notes.size() > 0:
						#for cn in last_combo_notes:
						#	cn.duration = 1 #time - cn.time
						last_combo_notes = []
					#else:
					#	if last_note.is_long:
					#		last_note.duration = time - last_note.time
					if not last_note.duration:
						var spawn_x = get_viewport().get_visible_rect().size.x
						var target_x = play_line_x + note_width / 2.0
						var seconds_per_pixel = approach_duration / (spawn_x - target_x)
						var seconds_per_part = note_width * seconds_per_pixel
						var duration = time - last_note.time
						var middle_count = max(0, floori((duration - seconds_per_part) / seconds_per_part))
						var part_count = middle_count + 2
						last_note.duration = seconds_per_part * part_count
					last_note = null
	
	temp_notes.sort_custom(func(a, b): return a.time < b.time)

	if temp_notes.size() > 0:
		var last = temp_notes[-1]
		song_duration = last.time + last.duration
	else:
		song_duration = 0.0

	for note in temp_notes:
		create_note(note)
	
	if debug:
		$NoteHider.hide()
		draw_play_line()
	
	self.play()

func _process(_delta: float) -> void:
	if self.get_state() != 0: # only when playing
		return

	# Tick down key lockouts
	for key in keys:
		if key_lockout.get(key, 0.0) > 0.0:
			key_lockout[key] -= _delta

	for note in notes:
		var note_start_time = note.get_meta("start_time")

		var spawn_x = get_viewport().get_visible_rect().size.x
		var target_x = play_line_x + note_width / 2.0

		note.position.x = lerp(spawn_x, target_x, (current_time - note_start_time + approach_duration) / approach_duration)

		# Switch note telegraph flash
		var lane = note.get_meta("lane")
		var target = note.get_meta("target_lane")
		if lane != target:
			var dist_to_switch = note.position.x - switch_line_x
			if dist_to_switch > 0 and dist_to_switch < SWITCH_TELEGRAPH_DISTANCE:
				var flash = sin(current_time * 30.0) > 0.0
				note.modulate = Color(2.0, 2.0, 2.0, 1.0) if flash else Color(1, 1, 1, 1)

		if note.position.x <= switch_line_x:
			if lane != target:
				note.modulate = Color(1, 1, 1, 1)
				note.set_meta("lane", target)
				var target_y = (target - 1) * note_height + play_line_y
				var tween = create_tween()
				tween.tween_property(note, "position:y", target_y, 0.3)


	# Track which combo_ids were hit or missed this frame
	var _combo_hit_ids: Array = []
	var _combo_miss_ids: Array = []

	for key in keys:
		if key_lockout.get(key, 0.0) > 0.0:
			self.key_state[key] = NONE
			continue
		if Input.is_action_just_pressed(key) and self.key_state.get(key, NONE) == NONE:
			self.key_state[key] = PRESSED
		elif Input.is_action_pressed(key):
			self.key_state[key] = HOLDING
		elif Input.is_action_just_released(key):
			self.key_state[key] = RELEASED
		else:
			self.key_state[key] = NONE

	var _keys_that_hit: Array = []

	self.notes = notes.filter(func(note):
		if note.position.x < trigger_line_x:
			var lane = note.get_meta("lane")
			var is_bad = note.get_meta("bad")
			var combo_id = note.get_meta("combo_id")
			var is_combo = combo_id >= 0
			var is_long = note.has_meta("part")

			if is_combo:
				# Skip if this combo pair was already resolved this frame
				if combo_id in _combo_hit_ids or combo_id in _combo_miss_ids:
					note.queue_free()
					return false

				# Combo notes require both keys pressed simultaneously
				if Input.is_action_just_pressed(keys[0]) and Input.is_action_just_pressed(keys[1]):
					_combo_hit_ids.append(combo_id)
					_keys_that_hit.append(keys[0])
					_keys_that_hit.append(keys[1])
					GameManager.fear -= combo_heal
					GameManager.combos_hit += 1
					GameManager.on_combo.emit()
					self.key_state[keys[0]] = RELEASED
					self.key_state[keys[1]] = RELEASED
					key_listeners[0].hit()
					key_listeners[1].hit()
					_play_hit_glow(note, 0.15)
					return false

				if note.position.x + note_width < play_line_x:
					_combo_miss_ids.append(combo_id)
					GameManager.notes_missed += 1
					GameManager.fear += self.fear
					GameManager.faith -= faith_penalty
					note.queue_free()
					return false
			elif is_long:
				var key = keys[lane - 1]
				var part = note.get_meta("part")
				
				if self.key_state[key] == HOLDING:
					_keys_that_hit.append(key)
					if is_bad:
						GameManager.fear += self.fear
						GameManager.faith -= faith_penalty
						key_listeners[lane - 1].shake()
						_lock_key(lane)
						note.queue_free()
					else:
						GameManager.notes_hit += 1
						_play_hit_glow(note)

					# Release on tail (last part)
					if part == 0:
						self.key_state[key] = RELEASED

					return false

				if note.position.x + note_width < play_line_x:
					if not is_bad:
						GameManager.notes_missed += 1
						GameManager.fear += self.fear
						GameManager.faith -= faith_penalty
					note.queue_free()
					return false
			else:
				var key = keys[lane - 1]
				if self.key_state[key] == PRESSED:
					_keys_that_hit.append(key)
					self.key_state[key] = RELEASED
					if is_bad:
						GameManager.fear += self.fear
						GameManager.faith -= faith_penalty
						key_listeners[lane - 1].shake()
						_lock_key(lane)
						note.queue_free()
					else:
						GameManager.notes_hit += 1
						key_listeners[lane - 1].hit()
						_play_hit_glow(note)
					return false

				if note.position.x + note_width < play_line_x:
					if not is_bad:
						GameManager.notes_missed += 1
						GameManager.fear += self.fear
						GameManager.faith -= faith_penalty
					note.queue_free()
					return false
		return true
	)

	# Whiff detection: key pressed but no note was hit
	for i in range(keys.size()):
		var key = keys[i]
		if self.key_state[key] == PRESSED and key not in _keys_that_hit:
			key_listeners[i].shake()
			_lock_key(i + 1)

func _play_hit_glow(note: Sprite2D, duration: float = 0.06) -> void:
	note.z_index = 10
	note.modulate = Color(1, 1, 1, 1)
	var tween = create_tween().set_parallel(true)
	tween.tween_property(note, "scale", Vector2(1.3, 1.3), duration).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tween.tween_property(note, "modulate:a", 0.0, duration)
	tween.tween_property(note, "self_modulate", Color(1.3, 1.3, 1.3, 1.0), duration)
	tween.finished.connect(note.queue_free)

func _lock_key(lane: int) -> void:
	key_lockout[keys[lane - 1]] = MISS_LOCKOUT_DURATION

func create_note_box(note_data: Dictionary, offset: float = 0.) -> Sprite2D:
	var scene = KEY
	if note_data.bad:
		scene = KEY_BAD
	elif note_data.lane != note_data.target_lane:
		scene = KEY_SWITCH
	elif note_data.combo_id != -1:
		scene = KEY_COMBO
	
	var box: Sprite2D = scene.instantiate()
	self.running_parent.add_child(box)

	box.set_meta("start_time", note_data.time + offset)
	box.set_meta("bad", note_data.bad)
	box.set_meta("lane", note_data.lane)
	box.set_meta("target_lane", note_data.target_lane)
	box.set_meta("combo_id", note_data.get("combo_id", -1))
	
	var maxx = get_viewport().get_visible_rect().size.x
	
	box.position.x = maxx
	box.position.y = (note_data.lane - 1) * note_height + play_line_y

	return box

const LONG_START = 48
const LONG_MIDDLE = 57
const LONG_END = 64

func create_note(note_data: Dictionary):
	var box: Sprite2D

	if note_data.duration > 1.:
		var spawn_x = get_viewport().get_visible_rect().size.x
		var target_x = play_line_x + note_width / 2.0
		var seconds_per_pixel = approach_duration / (spawn_x - target_x)
		var seconds_per_part = note_width * seconds_per_pixel
		var middle_count = max(0, floori((note_data.duration - seconds_per_part) / seconds_per_part))
		var part_count = middle_count + 2

		for i in range(part_count):
			var offset = i * seconds_per_part
			box = create_note_box(note_data, offset)
			box.set_meta("part", part_count - i - 1)
			if i == 0:
				box.region_rect.position.x = LONG_START
			elif i == part_count - 1:
				box.region_rect.position.x = LONG_END
			else:
				box.region_rect.position.x = LONG_MIDDLE
			notes.append(box)
	else:
		box = create_note_box(note_data)
		notes.append(box)

func draw_play_line():
	var y = play_line_y - note_height / 2.
	var h = keys.size() * note_height
	
	# Create a visual line at the play position
	var line = ColorRect.new()
	line.color = Color.WHITE
	line.size = Vector2(2, h)
	line.position = Vector2(play_line_x - 2, y)
	add_child(line)

	line = ColorRect.new()
	line.color = Color.PURPLE
	line.size = Vector2(2, h)
	line.position = Vector2(trigger_line_x - 2, y)
	add_child(line)
	
	line = ColorRect.new()
	line.color = Color.GREEN
	line.size = Vector2(2, h)
	line.position = Vector2(perfect_line_x - 2, y)
	add_child(line)

	line = ColorRect.new()
	line.color = Color.YELLOW
	line.size = Vector2(2, h)
	line.position = Vector2(switch_line_x - 2, y)
	add_child(line)

var song_duration: float = 0.0
var is_finished : bool = false

func _on_finished():
	if is_finished:
		return
	
	is_finished = true
	for note in self.notes:
		note.queue_free()
	notes.clear()
	self.stop()
	GameManager.level_completed()
