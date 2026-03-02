extends Node

@export var note_colors : Array[Color]

var notes = []

var midi_player: MidiPlayer
var asp: AudioStreamPlayer

@export var width: int = 160
@export var height: int = 20
@export var distance: int = 5
@export var note_offset: int = 30
@export var speed: int = 100

var playing: bool = false

# Called when the node enters the scene tree for the first time.
func _ready():
	midi_player = $MidiPlayer
	asp = $AudioStreamPlayer

	var midi_resource = MidiResource.new() 
	if midi_resource.load_file("res://thick_of_it.mid") != OK: 
		push_error("Failed to load midi file")  
	
	midi_player.midi = midi_resource
	midi_player.link_audio_stream_player([asp])
	
	var microseconds_per_tick = midi_resource.tempo / midi_resource.division;
	var speed_scale = 1
	
	var notes_on = []
	
	for track in midi_resource.tracks:
		var time: float = 0
		var last_note: Variant
		
		for event in track.events:
			if event['type'] == 'note':
				var event_delta: float = event['delta'] * microseconds_per_tick;
				var event_delta_seconds: float = event_delta / 1000000.0;
				event_delta_seconds /= speed_scale;
				time += event_delta_seconds
				
				if event.subtype == MIDI_MESSAGE_NOTE_ON:
					last_note = { "track": event.track, "note": event.note, "time": time, "duration": time - last_note.time if last_note else 0 }
					notes_on.append(last_note)
				
				if event.subtype == MIDI_MESSAGE_NOTE_OFF:
					last_note.duration = time - last_note.time
	
	for note_data in notes_on:
		var track = note_data.track
		var note = note_data.note
		var note_time = note_data.time
		var duration = note_data.duration
		
		var box = ColorRect.new()
		box.color = note_colors[track]
		box.size = Vector2(width * duration, height)
		self.add_child(box)
		
		box.position.x = self.size.x / 2 - (note_time * width)
		box.position.y = self.size.y - (note - note_offset) * (height + distance)
		notes.append(box)
	
	midi_player.play()

func _process(delta):
	for note in notes:
		note.position.x += delta * speed
		
		if note.position.x > self.size.x:
			notes.remove_at(notes.find(note))
			note.queue_free()
