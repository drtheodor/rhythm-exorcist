extends MidiPlayer
class_name MidiManager

const KEY = preload("res://scenes/objects/key_running.tscn")
const KEY_BAD = preload("res://scenes/objects/key_running_bad.tscn")
const KEY_SWITCH = preload("res://scenes/objects/key_running_switch.tscn")
const KEY_COMBO = preload("res://scenes/objects/key_running_combo.tscn")
const KEY_LONG_START = preload("res://scenes/objects/key_running_long_start.tscn")
const KEY_LONG_MIDDLE = preload("res://scenes/objects/key_running_long_middle.tscn")
const KEY_LONG_END = preload("res://scenes/objects/key_running_long_end.tscn")

enum { NONE, PRESSED, HOLDING, RELEASED }

const TRIGGER_NOTE = 57
const NOTE_OFFSET = 48

const NOTE_HIT_SIZE = Vector2(1.3, 1.3)
const NOTE_HIT_COLOR = Color(1.3, 1.3, 1.3, 1.)
const NOTE_FLASH_COLOR = Color(2., 2., 2., 1.)

@onready var running_parent = $Running

@export var audio: AudioStream
@export var approach_duration: float = 2 #11.25
@export var note_height: int = 16
@export var note_width: int = 16
@export var trigger_line_x: float = 70
@export var bad_trigger_line_x: float = 70
@export var play_line_x: float = 64.0
@export var play_line_y: float = 144.0
@export var switch_line_x: float = 160.0
@export var debug: bool = false

@export var perfect_threshold: float = 1
@export var fear: int = 5
@export var combo_heal: int = 8
@export var faith_penalty: int = 1
@export var miss_lockout_duration: float = 0.16
@export var switch_telegraph_distance: float = 30.0

@export var keys: Array[StringName] = [&"up", &"down"]
var key_state: Array[int] = []
var key_lockout: Array[float] = []
var key_listeners: Array[KeyListener] = []

signal flash_trigger

var _flash_trigger_time: float = -1.0
var _flash_triggered: bool = false

var song_duration: float = 0.0
var is_finished : bool = false

var notes: Array[Sprite2D] = []
var last_note_hits: Array[float] = []

var _next_combo_id: int = 0

func _init() -> void:
	self.key_listeners.resize(self.keys.size())
	
	for _key in self.keys:
		self.key_state.append(NONE)
		self.key_lockout.append(0)
		self.last_note_hits.append(0)

func _ready() -> void:
	self.finished.connect(self._on_finished)
	GameManager.on_game_over.connect(self._on_game_over)

@onready var note_spawn_x: float = get_viewport().get_visible_rect().size.x
@onready var note_target_x: float = self.play_line_x + self.note_width / 2.0
@onready var note_seconds_per_pixel: float = self.approach_duration / (self.note_spawn_x - self.note_target_x)
@onready var note_seconds_per_part: float = self.note_width * self.note_seconds_per_pixel
@onready var note_hit_helper_threshold: float = self.note_seconds_per_part

class PlayNote:
	var time: float
	var length: int = 1
	var lane: int
	var target_lane: int
	var combo_id: int = -1
	var bad: bool = false
	
	func _init(_time: float, _lane: int) -> void:
		self.time = _time
		self.lane = _lane
		self.target_lane = _lane

func _generate_notes(events: Array, all_notes: Array[PlayNote], seconds_per_tick: float) -> void:
	var unresolved: Dictionary[int, PlayNote] = {}
	var last_combo_notes: Array[PlayNote] = []
	var time: float = 0
	
	for event: Variant in events:
		time += event.delta * seconds_per_tick
		if event.type == 'note':
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
				
				var new_note: PlayNote
				
				if is_combo:
					var combo_id: int = _next_combo_id
					_next_combo_id += 1
					last_combo_notes = []
					
					for combo_lane in range(1, len(self.keys) + 1):
						var combo_note: PlayNote = PlayNote.new(time, combo_lane)
						combo_note.target_lane = combo_lane
						combo_note.combo_id = combo_id

						all_notes.append(combo_note)
						last_combo_notes.append(combo_note)
					
					new_note = last_combo_notes[0]
				else:
					var lane: int = (event.note % 2) + 1
					new_note = PlayNote.new(time, lane)
					
					if is_switch:
						new_note.target_lane = 2 if lane == 1 else 1
					
					if is_long:
						new_note.length = 0
					
					if is_bad:
						new_note.bad = true

					all_notes.append(new_note)

				if unresolved.has(event.note):
					push_warning("Resorting to overriding note ", event.note)

				unresolved[event.note] = new_note

			if event.subtype == MIDI_MESSAGE_NOTE_OFF:
				var resolving: PlayNote = unresolved.get(event.note)
				if resolving == null:
					push_warning("Skipping not unresolved note ", event.note)
					continue

				unresolved.erase(event.note)
				
				if not resolving.length:
					var duration = time - resolving.time
					var middle_count = max(0, floori((duration - self.note_seconds_per_part) / self.note_seconds_per_part))
					resolving.length = middle_count + 2

	if unresolved:
		print("Unresolved notes left!")

func start() -> void:
	self.is_finished = false
	self._flash_trigger_time = -1.0
	self._flash_triggered = false
	
	var asp = $AudioStreamPlayer
	asp.stream = self.audio
	
	self.link_audio_stream_player([asp])
	
	var microseconds_per_tick: float = float(self.midi.tempo) / float(self.midi.division)
	var seconds_per_tick: float = microseconds_per_tick / 1000000.0
	
	var temp_notes: Array[PlayNote] = []
	for track in self.midi.tracks:
		self._generate_notes(track.events, temp_notes, seconds_per_tick)
	
	if temp_notes:
		temp_notes.sort_custom(func(a: PlayNote, b: PlayNote) -> bool: return a.time < b.time)
		
		var last = temp_notes[-1]
		song_duration = last.time + last.length * self.note_seconds_per_part
	else:
		song_duration = 0.0

	for play_note: PlayNote in temp_notes:
		self._create_note(play_note)
	
	if debug:
		$NoteHider.hide()
		draw_play_line()
	
	self.play()

func _process(_delta: float) -> void:
	if self.get_state() != 0: # only when playing
		return

	if self._flash_trigger_time >= 0.0 and self.current_time >= self._flash_trigger_time and not self._flash_triggered and not GameManager.is_game_over:
		self._flash_triggered = true

		# Clear all key states
		for key in range(self.key_state.size()):
			self.key_state[key] = NONE

		self.key_lockout.clear()

		# Clear all remaining notes from screen
		for note_box in notes:
			note_box.queue_free()

		self._reset()
		flash_trigger.emit()
		return

	for note_box: Sprite2D in self.notes:
		var note_start_time = note_box.get_meta("start_time")
		note_box.position.x = lerp(self.note_spawn_x, self.note_target_x, (self.current_time - note_start_time + self.approach_duration) / self.approach_duration)

		# Switch note telegraph flash
		var lane = note_box.get_meta("lane")
		var target = note_box.get_meta("target_lane")
		if lane != target:
			var dist_to_switch = note_box.position.x - switch_line_x

			if dist_to_switch <= 0:
				note_box.modulate = Color.WHITE
				note_box.set_meta("lane", target)
				var target_y = (target - 1) * note_height + play_line_y
				self.create_tween().tween_property(note_box, "position:y", target_y, 0.3)
			elif dist_to_switch < self.switch_telegraph_distance:
				var flash = sin(current_time * 30.0) > 0.0
				note_box.modulate = NOTE_FLASH_COLOR if flash else Color.WHITE

	for key: int in range(self.keys.size()):
		if self.key_lockout[key] > 0.0:
			self.key_lockout[key] -= _delta
			self.key_state[key] = NONE
			continue
		
		var action: StringName = self.keys[key]
		if Input.is_action_just_pressed(action) and self.key_state[key] == NONE:
			self.key_state[key] = PRESSED
		elif Input.is_action_pressed(action):
			self.key_state[key] = HOLDING
		elif Input.is_action_just_released(action):
			self.key_state[key] = RELEASED
		else:
			self.key_state[key] = NONE

	var hit_keys: Array[bool] = []
	hit_keys.resize(self.keys.size())
	
	# Track which combo_ids were hit or missed this frame
	var triggered_combos = []

	self.notes = notes.filter(func(note_box: Sprite2D) -> bool:
		if note_box.position.x >= self.trigger_line_x: return true
		
		var is_bad: bool = note_box.get_meta("bad")
		
		if is_bad and note_box.position.x < self.bad_trigger_line_x:
			return true
		
		var lane: int = note_box.get_meta("lane")
		
		var missed: bool = note_box.position.x + self.note_width < self.play_line_x
		var key: int = lane - 1

		if note_box.has_meta("combo_id"): # is combo
			var combo_id = note_box.get_meta("combo_id")
			
			# Skip if this combo pair was already resolved this frame
			if combo_id in triggered_combos:
				note_box.queue_free()
				return false

			# Combo notes require both keys pressed simultaneously
			var all_pressed: bool = self.key_state.all(func (state: int) -> bool: return state == PRESSED)
			
			if all_pressed:
				triggered_combos.append(combo_id)
				self.hit_combo()
				
				for i in range(self.keys.size()):
					# No need to add to hit keys, since the key is not pressed anymore!
					self.key_state[i] = RELEASED
					self.key_listeners[i].hit()
				
				self._play_hit_glow(note_box, 0.15)
				return false

			if missed:
				triggered_combos.append(combo_id)
		elif note_box.has_meta("part"): # is long
			var part: int = note_box.get_meta("part")
			
			if self.key_state[key] == HOLDING:
				if is_bad:
					self.miss_note(true)
					
					self.key_listeners[key].shake()
					self._lock_key(key)
					
					note_box.queue_free()
				else:
					GameManager.notes_hit += 1
					self._play_hit_glow(note_box)

				# Release on tail (last part)
				if part == 0:
					self.key_state[key] = RELEASED
				else:
					hit_keys[key] = true
				
				return false
		else:
			if self.key_state[key] == PRESSED:
				hit_keys[key] = true
				self.key_state[key] = RELEASED
				
				if is_bad:
					self.miss_note(true)
					
					key_listeners[key].shake()
					self._lock_key(key)
					
					note_box.queue_free()
				else:
					self.last_note_hits[key] = self.current_time
					GameManager.notes_hit += 1
					
					self.key_listeners[key].hit()
					self._play_hit_glow(note_box)
				
				return false
		
		if missed:
			if is_bad:
				GameManager.notes_hit += 1
			else:
				self.miss_note()
			
			note_box.queue_free()
			return false
		
		return true
	)

	# Whiff detection: key pressed but no note was hit
	for key: int in range(self.keys.size()):
		if not hit_keys[key] and self.key_state[key] == PRESSED:
			self.key_listeners[key].shake()
			
			if self.current_time - self.last_note_hits[key] >= self.note_hit_helper_threshold:
				self._lock_key(key)

func hit_combo() -> void:
	GameManager.notes_hit += self.keys.size()
	GameManager.combos_hit += 1
	GameManager.fear -= combo_heal

func miss_note(real: bool = true) -> void:
	if real:
		GameManager.notes_missed += 1
	GameManager.fear += self.fear
	GameManager.faith -= faith_penalty

func _lock_key(key: int) -> void:
	self.key_lockout[key] = self.miss_lockout_duration

func _play_hit_glow(note_box: Sprite2D, duration: float = 0.06) -> void:
	note_box.z_index = 10
	note_box.modulate = Color.WHITE
	var tween = create_tween().set_parallel(true)
	tween.tween_property(note_box, "scale", NOTE_HIT_SIZE, duration).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tween.tween_property(note_box, "modulate:a", 0.0, duration)
	tween.tween_property(note_box, "self_modulate", NOTE_HIT_COLOR, duration)
	tween.finished.connect(note_box.queue_free)

func _create_note_box(play_note: PlayNote, scene: PackedScene, part: int = 0) -> Sprite2D:	
	var box: Sprite2D = scene.instantiate()
	self.running_parent.add_child(box)

	box.set_meta("start_time", play_note.time + part * self.note_seconds_per_part)
	box.set_meta("bad", play_note.bad)
	box.set_meta("lane", play_note.lane)
	box.set_meta("target_lane", play_note.target_lane)
	
	if play_note.combo_id != -1:
		box.set_meta("combo_id", play_note.combo_id)
	
	box.position.x = self.note_spawn_x
	box.position.y = (play_note.lane - 1) * self.note_height + self.play_line_y
	
	self.notes.append(box)
	return box

func _create_note(play_note: PlayNote) -> void:
	var scene: PackedScene
	var box: Sprite2D

	if play_note.length > 1:
		for i in range(play_note.length):
			scene = KEY_LONG_MIDDLE
			
			if i == 0:
				scene = KEY_LONG_START
			elif i == play_note.length - 1:
				scene = KEY_LONG_END
			
			box = self._create_note_box(play_note, scene, i)
			box.set_meta("part", play_note.length - i - 1)
	else:
		scene = KEY
		
		if play_note.bad:
			scene = KEY_BAD
		elif play_note.lane != play_note.target_lane:
			scene = KEY_SWITCH
		elif play_note.combo_id != -1:
			scene = KEY_COMBO
		
		box = self._create_note_box(play_note, scene)

func draw_play_line() -> void:
	var y: float = play_line_y - note_height / 2.
	var h: float = keys.size() * note_height
	
	# Create a visual line at the play position
	var line: ColorRect = ColorRect.new()
	line.color = Color.WHITE
	line.size = Vector2(2, h)
	line.position = Vector2(play_line_x - 2, y)
	self.running_parent.add_child(line)

	line = ColorRect.new()
	line.color = Color.PURPLE
	line.size = Vector2(2, h)
	line.position = Vector2(trigger_line_x - 2, y)
	self.running_parent.add_child(line)
	
	line = ColorRect.new()
	line.color = Color.RED
	line.size = Vector2(2, h)
	line.position = Vector2(bad_trigger_line_x - 2, y)
	self.running_parent.add_child(line)

	line = ColorRect.new()
	line.color = Color.YELLOW
	line.size = Vector2(2, h)
	line.position = Vector2(switch_line_x - 2, y)
	self.running_parent.add_child(line)

func _on_game_over() -> void:
	var asp = $AudioStreamPlayer
	var tween: Tween = self.create_tween()
	tween.tween_property(asp, "pitch_scale", 0.0, 5.0).set_ease(Tween.EASE_IN).set_trans(Tween.TRANS_QUAD)
	tween.tween_callback(self._reset)

func _on_finished():
	if self.is_finished:
		return

	self.is_finished = true
	self._reset()
	
	if not GameManager.is_game_over and not self._flash_triggered:
		GameManager.level_completed()

func _reset() -> void:
	self.notes.clear()
	self.stop()
	
	$AudioStreamPlayer.stop()
