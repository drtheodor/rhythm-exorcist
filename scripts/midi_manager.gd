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
@export var approach_duration: float = 11.25
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

func _ready() -> void:
	self.finished.connect(_on_finished)

func start() -> void:
	is_finished = false
	var asp = $AudioStreamPlayer
	asp.stream = self.audio
	
	self.link_audio_stream_player([asp])
	
	var microseconds_per_tick: float = (self.midi.tempo as float) / self.midi.division
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
					var is_normal = event.track <= 2
					var is_bad = event.track >= 3 and event.track <= 4
					var is_switch = event.track >= 5 and event.track <= 6
					var is_combo = event.track == 7
					
					var lane: int = 1
					var target_lane: int = lane
					
					if is_normal:
						lane = event.track
						target_lane = lane
					elif is_bad:
						lane = event.track - 2
						target_lane = lane
					elif is_switch:
						lane = event.track - 4
						target_lane = (2 if lane == 1 else 1)

					if is_combo:
						var combo_id = _next_combo_id
						_next_combo_id += 1
						last_combo_notes = []
						for combo_lane in range(len(self.keys)):
							var combo_note = {
								"time": time,
								"duration": -1,
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
							"duration": -1,
							"bad": is_bad,
							"lane": lane,
							"target_lane": target_lane,
							"combo_id": -1,
						}
						temp_notes.append(last_note)

				if event.subtype == MIDI_MESSAGE_NOTE_OFF and last_note != null:
					if last_combo_notes.size() > 0:
						for cn in last_combo_notes:
							cn.duration = time - cn.time
						last_combo_notes = []
					else:
						last_note.duration = time - last_note.time
					last_note = null
	
	temp_notes.sort_custom(func(a, b): return a.time < b.time)
	
	for note in temp_notes:
		create_note(note)
	
	if debug:
		$NoteHider.hide()
		draw_play_line()
	
	self.play()

func _process(_delta: float) -> void:
	if self.get_state() != 0: # only when playing
		return

	for note in notes:
		var note_start_time = note.get_meta("start_time")

		var spawn_x = get_viewport().get_visible_rect().size.x
		var target_x = play_line_x + note_width
		
		note.position.x = lerp(spawn_x, target_x, (current_time - note_start_time + approach_duration) / approach_duration)

		if note.position.x <= switch_line_x:
			var lane = note.get_meta("lane")
			var target = note.get_meta("target_lane")
			if lane != target:
				note.set_meta("lane", target)
				var target_y = (target - 1) * note_height + play_line_y
				var tween = create_tween()
				tween.tween_property(note, "position:y", target_y, 0.3)
		
	
	# Track which combo_ids were hit or missed this frame
	var _combo_hit_ids: Array = []
	var _combo_miss_ids: Array = []
	
	for key in keys:
		if Input.is_action_just_pressed(key) and self.key_state.get(key, NONE) == NONE:
			self.key_state[key] = PRESSED
		elif Input.is_action_pressed(key):
			self.key_state[key] = HOLDING
		elif Input.is_action_just_released(key):
			self.key_state[key] = RELEASED
		else:
			self.key_state[key] = NONE

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
					GameManager.fear -= combo_heal
					GameManager.combos_hit += 1
					GameManager.on_combo.emit()
					note.queue_free()
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
					if is_bad:
						GameManager.fear += self.fear
						GameManager.faith -= faith_penalty
					else:
						GameManager.notes_hit += 1

					note.queue_free()
					
					if part != 0:
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
					if is_bad:
						GameManager.fear += self.fear
						GameManager.faith -= faith_penalty
					else:
						GameManager.notes_hit += 1

					note.queue_free()
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

func create_note_box(note_data: Dictionary, offset: float = 0.) -> Sprite2D:
	var scene = KEY
	if note_data.bad:
		scene = KEY_BAD
	elif note_data.lane != note_data.target_lane:
		scene = KEY_SWITCH
	elif note_data.get("combo", false):
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
	var len = ceili(note_data.duration)
	print(note_data.duration)
	var box: Sprite2D
	
	if len > 1:
		for dur in range(len):
			box = create_note_box(note_data, dur)
			box.set_meta("part", dur)
			var sprite_x
			if dur == 0:
				sprite_x = LONG_START
			elif dur == len - 1:
				sprite_x = LONG_END
			else:
				sprite_x = LONG_MIDDLE
			box.region_rect.position.x = sprite_x
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
