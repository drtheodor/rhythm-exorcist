extends MidiPlayer
class_name MidiManager

const KEY = preload("res://scenes/objects/key_running.tscn")
const KEY_BAD = preload("res://scenes/objects/key_running_bad.tscn")
const KEY_SWITCH = preload("res://scenes/objects/key_running_switch.tscn")

#@export var note_colors : Array[Color] = [
	#Color.hex(0xff4747),
	#Color.hex(0x2cff2c),
	#Color.hex(0x4343ff),
#]

@onready var running_parent = $Running

@export var audio: AudioStream
@export var note_height: int = 16
@export var note_width: int = 4
@export var trigger_line_x: float = 70
@export var perfect_line_x: float = 66.0
@export var play_line_x: float = 64.0
@export var play_line_y: float = 144.0
@export var switch_line_x: float = 160.0
@export var debug: bool = false

@export var perfect_threshold: float = 1
@export var fear: int = 5
@export var perfect_heal: int = 1
@export var faith_penalty: int = 2

@export var keys: Array[String] = ["up", "down"]

var notes: Array = []

func start() -> void:
	var asp = $AudioStreamPlayer
	asp.stream = self.audio
	
	self.link_audio_stream_player([asp])
	
	# Calculate tempo-based pixels per second
	#var beats_per_second = 1000000.0 / self.midi.tempo
	
	var microseconds_per_tick: float = (self.midi.tempo as float) / self.midi.division
	var seconds_per_tick: float = microseconds_per_tick / 1000000.0
	
	var temp_notes = []
	
	for track in self.midi.tracks:
		var last_note: Variant = null
		var time: float = 0
		
		for event in track.events:
			time += event.delta * seconds_per_tick
			if event['type'] == 'note':
				if event.subtype == MIDI_MESSAGE_NOTE_ON:
					var is_bad = event.track >= 3 and event.track <= 4
					var is_switch = event.track >= 5 and event.track <= 6
					var lane: int
					var target_lane: int
					if event.track <= 2:
						lane = event.track
						target_lane = lane
					elif event.track <= 4:
						lane = event.track - 2
						target_lane = lane
					else:
						lane = event.track - 4
						target_lane = (2 if lane == 1 else 1)
					last_note = {
						"track": event.track,
						"note": event.note,
						"time": time,
						"duration": 0,
						"bad": is_bad,
						"lane": lane,
						"target_lane": target_lane,
						"switch": is_switch,
					}

					temp_notes.append(last_note)
				
				if event.subtype == MIDI_MESSAGE_NOTE_OFF and last_note != null:
					last_note.duration = time - last_note.time
					last_note = null
	
	temp_notes.sort_custom(func(a, b): return a.time < b.time)
	
	for note in temp_notes:
		create_note(note)
	
	if debug:
		$NoteHider.hide()
		draw_play_line()
	
	self.play()
	
	self.finished.connect(_on_finished)

func _process(_delta: float) -> void:
	if self.get_state() != 0: # only when playing
		return

	for note in notes:
		var note_start_time = note.get_meta("start_time")
		
		var d: float = (current_time) / (note_start_time) if note_start_time else 0.
		var maxx = get_viewport().get_visible_rect().size.x
		
		# Do not question.
		note.position.x = (maxx + play_line_x) * (1 - d) + 2*play_line_x
		#note.position.x = lerpf(maxx, play_line_x, current_time / note_start_time)

		if note.get_meta("switch") and not note.get_meta("switched") and note.position.x <= switch_line_x:
			var target = note.get_meta("target_lane")
			note.set_meta("lane", target)
			note.set_meta("switched", true)
			var target_y = (target - 1) * note_height + play_line_y
			var tween = create_tween()
			tween.tween_property(note, "position:y", target_y, 0.3)
		
		#print(note.get_meta("note"), "/", "start: ", note_start_time, "; cur: ", current_time, "; d: ", d, "; x: ", note.position.x)
	
	self.notes = notes.filter(func(note):
		if note.position.x + note_width < trigger_line_x:
			var lane = note.get_meta("lane")
			var is_bad = note.get_meta("bad")

			if Input.is_action_just_pressed(keys[lane - 1]):
				if is_bad:
					GameManager.fear += self.fear
					GameManager.faith -= faith_penalty
				else:
					var distance = abs(perfect_line_x - note.position.x)
					if distance <= perfect_threshold:
						GameManager.fear -= self.perfect_heal

				note.queue_free()
				return false

			if note.position.x + note_width < play_line_x:
				if not is_bad:
					GameManager.fear += self.fear
					GameManager.faith -= faith_penalty
				note.queue_free()
				return false
		return true
	)

func create_note_box(note_data: Dictionary, offset: float) -> Sprite2D:
	var scene = KEY
	if note_data.bad:
		scene = KEY_BAD
	elif note_data["switch"]:
		scene = KEY_SWITCH
	var box: Sprite2D = scene.instantiate()
	self.running_parent.add_child(box)

	box.set_meta("start_time", note_data.time + offset)
	box.set_meta("duration", note_data.duration)
	box.set_meta("track", note_data.track)
	box.set_meta("note", note_data.note)
	box.set_meta("bad", note_data.bad)
	box.set_meta("lane", note_data.lane)
	box.set_meta("target_lane", note_data.target_lane)
	box.set_meta("switch", note_data["switch"])
	box.set_meta("switched", false)
	return box

func create_note(note_data: Dictionary):
	var len = int(note_data.duration)
	var box: Sprite2D
	
	if len > 1:
		#for dur in range(len):
		box = create_note_box(note_data, 0)
		box.region_rect.position.x += 16
		box.region_rect.size.x = 16 * len

	var d = (current_time) / (note_data.time) if note_data.time else 0.
	var maxx = get_viewport().get_visible_rect().size.x
	
	# Do not question.
	box.position.x = (maxx + play_line_x) * (1 - d) + 2*play_line_x
	box.position.y = (note_data.lane - 1) * note_height + play_line_y

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

func _on_finished():
	for note in self.notes:
		note.queue_free()
	notes.clear()
	GameManager.level_completed()
