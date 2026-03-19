extends MidiPlayer
class_name MidiManager

const KEY = preload("res://scenes/objects/key_running.tscn")

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
@export var scroll_speed: float = 100.0
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
	
	var maxx = get_viewport().get_visible_rect().size.x
	var timing_factor = (maxx + 2.0 * play_line_x) / (maxx + play_line_x)

	var temp_notes = []

	for track in self.midi.tracks:
		var last_note: Variant = null
		var time: float = 0
		
		for event in track.events:
			time += event.delta * seconds_per_tick
			if event['type'] == 'note':
				if event.subtype == MIDI_MESSAGE_NOTE_ON:
					last_note = {
						"track": event.track,
						"note": event.note,
						"time": time,
						"duration": 0,#(time - last_note.time if last_note else 0.1)
						"timing_factor": timing_factor,
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
		note.position.x = play_line_x + (note_start_time - current_time) * scroll_speed
	
	self.notes = notes.filter(func(note):
		if note.position.x + note_width < trigger_line_x:
			if Input.is_action_just_pressed(keys[note.get_meta("track") - 1]):
				var distance = abs(perfect_line_x - note.position.x)
				
				if distance <= perfect_threshold:
					GameManager.fear -= self.perfect_heal
				
				note.queue_free()
				return false
			
			if note.position.x + note_width < play_line_x:
				GameManager.fear += self.fear
				GameManager.faith -= faith_penalty
				note.queue_free()
				return false
		return true
	)

func create_note(note_data: Dictionary):
	#var box: ColorRect = ColorRect.new()
	#box.color = note_colors[note_data.track % note_colors.size()]
	
	# Width based on duration and pixels per second
	#box.size = Vector2(note_data.duration * pixels_per_second, note_height)
	var box = KEY.instantiate()
	self.running_parent.add_child(box)
	
	# Store metadata
	box.set_meta("start_time", note_data.time * note_data.timing_factor)
	box.set_meta("duration", note_data.duration)
	box.set_meta("track", note_data.track)
	box.set_meta("note", note_data.note)
	
	# Initial position (will be updated in _process)
	box.position.y = (note_data.track - 1) * note_height + play_line_y
	
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

func _on_finished():
	for note in self.notes:
		note.queue_free()
	notes.clear()
	GameManager.level_completed()
