extends MidiPlayer
class_name MidiManager

const KEY = preload("res://scenes/objects/key_running.tscn")
const KEY_BAD = preload("res://scenes/objects/key_running_bad.tscn")
const KEY_SWITCH = preload("res://scenes/objects/key_running_switch.tscn")
const KEY_COMBO = preload("res://scenes/objects/key_running_combo.tscn")

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
@export var faith_penalty: int = 1

@export var keys: Array[String] = ["up", "down"]

const NONE = 0
const PRESSED = 1
const HOLDING = 2
const RELEASED = 3

const TRIGGER_NOTE = 57

signal flash_trigger

var key_state = {}
var notes: Array = []
var _next_combo_id: int = 0
var key_lockout: Dictionary = {}
var _flash_trigger_time: float = -1.0
var _flash_triggered: bool = false

const MISS_LOCKOUT_DURATION: float = 0.16
const SWITCH_TELEGRAPH_DISTANCE: float = 30.0

@onready var key_listeners: Array = [$UpKey, $DownKey]

var _game_over_slowing: bool = false

func _ready() -> void:
	self.finished.connect(_on_finished)
	GameManager.on_game_over.connect(_on_game_over)

	for key in keys:
		self.key_state[key] = NONE

const NOTE_OFFSET = 48

@onready var note_spawn_x = get_viewport().get_visible_rect().size.x
@onready var note_target_x = self.play_line_x + self.note_width / 2.0
@onready var note_seconds_per_pixel = self.approach_duration / (self.note_spawn_x - self.note_target_x)
@onready var note_seconds_per_part = self.note_width * self.note_seconds_per_pixel

func start() -> void:
	is_finished = false
	_flash_trigger_time = -1.0
	_flash_triggered = false
	var asp = $AudioStreamPlayer
	asp.stream = self.audio
	
	self.link_audio_stream_player([asp])
	
	var microseconds_per_tick: float = float(self.midi.tempo) / float(self.midi.division)
	var seconds_per_tick: float = microseconds_per_tick / 1000000.0
	
	var temp_notes = []
	
	for track in self.midi.tracks:
		var unresolved = {}
		var last_combo_notes: Array = []
		var time: float = 0
		
		for event in track.events:
			time += event.delta * seconds_per_tick
			if event['type'] == 'note':
				if event.subtype == MIDI_MESSAGE_NOTE_ON:
					if event.note == TRIGGER_NOTE:
						_flash_trigger_time = time
						continue
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

					var new_note
					if is_combo:
						var combo_id = _next_combo_id
						_next_combo_id += 1
						last_combo_notes = []
						for combo_lane in range(1, len(self.keys) + 1):
							var combo_note = {
								"time": time,
								"length": 1,
								"bad": false,
								"lane": combo_lane,
								"target_lane": combo_lane,
								"combo_id": combo_id,
							}
							temp_notes.append(combo_note)
							last_combo_notes.append(combo_note)
						new_note = last_combo_notes[0]
					else:
						new_note = {
							"time": time,
							"length": 0 if is_long else 1,
							"bad": is_bad,
							"lane": lane,
							"target_lane": target_lane,
							"combo_id": -1,
						}
						temp_notes.append(new_note)

					if unresolved.has(event.note):
						push_warning("Resorting to overriding note ", event.note)

					unresolved[event.note] = new_note

				if event.subtype == MIDI_MESSAGE_NOTE_OFF:
					var resolving = unresolved.get(event.note)
					if resolving == null: continue

					unresolved.erase(event.note)
					
					if not resolving.length:
						var duration = time - resolving.time
						var middle_count = max(0, floori((duration - self.note_seconds_per_part) / self.note_seconds_per_part))
						resolving.length = middle_count + 2
	
		if unresolved:
			print("Unresolved notes left!")
	
	temp_notes.sort_custom(func(a, b): return a.time < b.time)

	if temp_notes.size() > 0:
		var last = temp_notes[-1]
		song_duration = last.time + last.length * self.note_seconds_per_part
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

	if _flash_trigger_time >= 0.0 and current_time >= _flash_trigger_time and not _flash_triggered and not _game_over_slowing:
		_flash_triggered = true
		flash_trigger.emit()
		$AudioStreamPlayer.stop()
		self.stop()
		return

	# Tick down key lockouts
	for key in keys:
		if key_lockout.get(key, 0.0) > 0.0:
			key_lockout[key] -= _delta

	for note in notes:
		var note_start_time = note.get_meta("start_time")
		note.position.x = lerp(self.note_spawn_x, self.note_target_x, (current_time - note_start_time + self.approach_duration) / self.approach_duration)

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
	
	box.position.x = self.note_spawn_x
	box.position.y = (note_data.lane - 1) * self.note_height + self.play_line_y

	return box

const LONG_START = 48
const LONG_MIDDLE = 57
const LONG_END = 64

func create_note(note_data: Dictionary):
	var box: Sprite2D

	if note_data.length > 1:
		box = create_note_box(note_data, 0)
		box.region_rect.position.x = LONG_START
		box.set_meta("part", note_data.length - 1)
		notes.append(box)

		for i in range(1, note_data.length - 1):
			box = create_note_box(note_data, i * self.note_seconds_per_part)
			box.region_rect.position.x = LONG_MIDDLE
			box.set_meta("part", note_data.length - i - 1)
			notes.append(box)

		box = create_note_box(note_data, (note_data.length - 1) * self.note_seconds_per_part)
		box.region_rect.position.x = LONG_END
		box.set_meta("part", 0)
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

func _on_game_over() -> void:
	_game_over_slowing = true
	var asp = $AudioStreamPlayer
	var tween = create_tween()
	tween.tween_property(asp, "pitch_scale", 0.0, 5.0) \
		.set_ease(Tween.EASE_IN).set_trans(Tween.TRANS_QUAD)
	tween.tween_callback(_stop_after_game_over)

func _stop_after_game_over() -> void:
	for note in self.notes:
		note.queue_free()
	notes.clear()
	self.stop()
	$AudioStreamPlayer.stop()

func _on_finished():
	if is_finished:
		return

	is_finished = true
	for note in self.notes:
		note.queue_free()
	notes.clear()
	self.stop()
	if not _game_over_slowing and not _flash_triggered:
		GameManager.level_completed()
