extends Node

@export var note_colors : Array[Color]

var notes = []
var notes_on = {}
var all_notes = []

var midi_player: MidiPlayer
var midi_player2: MidiPlayer
var asp: AudioStreamPlayer

@export var width: int = 2
@export var height: int = 20
@export var distance: int = 5
@export var note_offset: int = 30
@export var speed: int = 70

var playing: bool = false

# Called when the node enters the scene tree for the first time.
func _ready():
	midi_player = $MidiPlayer
	midi_player2 = $MidiPlayer2
	asp = $AudioStreamPlayer

	var midi_resource = MidiResource.new() 
	if midi_resource.load_file("res://thick_of_it.mid") != OK: 
		push_error("Failed to load midi file")  
	
	midi_player.midi = midi_resource
	midi_player2.midi = midi_resource

	# linking an ASP allows for async playback of audio with midi events
	# for better syncing
	#midi_player.note.connect(on_note)
	#midi_player.play()
	
	midi_player2.link_audio_stream_player([asp])
	#return
	
	var microseconds_per_tick = midi_resource.tempo / midi_resource.division;
	var speed_scale = 1
	
	for track in midi_resource.tracks:
		
		var time = 0
		for event in track.events:
			if event['type'] == 'note':
				var event_delta = event['delta'] * microseconds_per_tick;
				var event_delta_seconds = event_delta / 1000000.0;
				event_delta_seconds /= speed_scale;
				time += event_delta_seconds
				if event['subtype'] == MIDI_MESSAGE_NOTE_ON:
					all_notes.append({ "track": event["track"], "note": event['note'], "time": time, "end": time + 0.1 })
				
				if event['subtype'] == MIDI_MESSAGE_NOTE_OFF:
					print("off")
					all_notes[-1]["end"] = time
	#print(midi_resource.tempo)
	#print(midi_resource.division)
	for i in range(all_notes.size()):
		var note_data = all_notes[i]
		var track = note_data.track
		var note = note_data.note
		var note_time = note_data.time
		var note_end = note_data.end
		
		var box = ColorRect.new()
		box.color = note_colors[track]
		box.size = Vector2(75 * (note_end - note_time), height)
		self.add_child(box)
		
		box.position.x = self.size.x / 2 - (note_time * 75)
		box.position.y = (note - note_offset) * (height + distance)
		notes.append(box)

# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta):
	# remove notes when they go off screen
	for note in notes:
		note.position.x += delta * speed
		
		if not playing and note.position.x > self.size.x / 2:
			midi_player2.play()
			self.playing = true
		
		if note.position.x > self.size.x:
			notes.remove_at(notes.find(note))
			note.queue_free()
	
	# spawn notes
	for note in notes_on:
		var box = ColorRect.new()
		box.color = note_colors[notes_on[note]]
		box.size = Vector2(width, height)
		self.add_child(box)
		
		box.position.x = 100
		box.position.y = (note - note_offset) * (height + distance)
		notes.append(box)

# Called when a "note" type event is played
func on_note(event, track):
	if (event['subtype'] == MIDI_MESSAGE_NOTE_ON): # note on
		notes_on[event['note']] = track
		#print(event)
		#$SFX.play()
	elif (event['subtype'] == MIDI_MESSAGE_NOTE_OFF): # note off
		notes_on.erase(event['note'])
	#print("[Track: " + str(track) + "] Note on: " + str(event['note']))
