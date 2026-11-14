extends Node
## Background music, made in code like the sound effects (no audio files to license).
## A calm, spacey loop: soft pad chords with a quiet bell arpeggio on top, 32 seconds long.
## It is built a little at a time over the first second (so start-up does not freeze),
## then loops forever. main.gd creates one and stores it in GameState.music.
## The volume comes from GameState (menu slider); it is kept low even at full volume.

const RATE: int = 11025           # low sample rate: the music has no high notes, and it builds faster
const CHORD_SECONDS: float = 4.0
const CHUNK: int = 6000           # samples built per frame
const MAX_DB: float = -14.0       # full volume is still quiet behind the game

## Eight chords, each as four notes (Hz): Cmaj7, Am7, Fmaj7, G6, Em7, Am7, Dm7, Gsus.
const CHORDS: Array = [
	[130.81, 164.81, 196.00, 246.94],
	[110.00, 130.81, 164.81, 196.00],
	[87.31, 110.00, 130.81, 164.81],
	[98.00, 146.83, 196.00, 220.00],
	[164.81, 196.00, 246.94, 293.66],
	[110.00, 130.81, 164.81, 196.00],
	[146.83, 174.61, 220.00, 261.63],
	[98.00, 130.81, 146.83, 196.00],
]
const ARP: Array = [0, 1, 2, 3, 2, 1, 2, 3]   # which chord note each half-second plays

var _player: AudioStreamPlayer = null
var _samples: PackedFloat32Array = PackedFloat32Array()
var _built: int = 0
var _total: int = 0
var _volume: float = 0.5


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS   # keeps playing while the menu pauses the game
	_player = AudioStreamPlayer.new()
	add_child(_player)
	_total = int(CHORD_SECONDS * float(CHORDS.size()) * float(RATE))
	_samples.resize(_total)
	set_volume(_volume)


func _process(_delta: float) -> void:
	if _built >= _total:
		return
	var stop: int = mini(_total, _built + CHUNK)
	for i in range(_built, stop):
		_samples[i] = sample_at(float(i) / float(RATE))
	_built = stop
	if _built >= _total:
		_start()


## volume is 0..1. 0 stops the music; anything else plays it at that level.
func set_volume(volume: float) -> void:
	_volume = clampf(volume, 0.0, 1.0)
	if _player == null:
		return
	if _volume <= 0.001:
		_player.volume_db = -80.0
		if _player.playing:
			_player.stop()
		return
	_player.volume_db = MAX_DB + linear_to_db(_volume)
	if _built >= _total and not _player.playing:
		_player.play()


func _start() -> void:
	var data: PackedByteArray = PackedByteArray()
	data.resize(_total * 2)
	for i in range(_total):
		data.encode_s16(i * 2, int(clampf(_samples[i], -1.0, 1.0) * 32000.0))
	var s: AudioStreamWAV = AudioStreamWAV.new()
	s.format = AudioStreamWAV.FORMAT_16_BITS
	s.mix_rate = RATE
	s.stereo = false
	s.data = data
	s.loop_mode = AudioStreamWAV.LOOP_FORWARD
	s.loop_begin = 0
	s.loop_end = _total
	_player.stream = s
	_samples = PackedFloat32Array()   # no longer needed
	if _volume > 0.001:
		_player.play()


## One sample of the loop at time t (seconds). Public so a test could check it is quiet.
static func sample_at(t: float) -> float:
	var count: int = CHORDS.size()
	var k: int = int(floor(t / CHORD_SECONDS)) % count
	var local: float = t - floor(t / CHORD_SECONDS) * CHORD_SECONDS
	var prev: int = (k - 1 + count) % count
	# pad: the new chord fades in while the last one fades out, so the loop has no seams
	var fade_in: float = minf(1.0, local / 0.9)
	var fade_out: float = maxf(0.0, 1.0 - local / 0.9)
	var swell: float = 0.85 + 0.15 * sin(TAU * 0.25 * t)
	# each chord's notes are timed from the start of that chord, so the end of the loop
	# joins the start without a click
	var out: float = _pad(CHORDS[k], local) * fade_in + _pad(CHORDS[prev], local + CHORD_SECONDS) * fade_out
	out *= 0.20 * swell
	# a very low hum on the root
	var root: float = float((CHORDS[k] as Array)[0]) * 0.5
	var prev_root: float = float((CHORDS[prev] as Array)[0]) * 0.5
	out += (sin(TAU * root * local) * fade_in + sin(TAU * prev_root * (local + CHORD_SECONDS)) * fade_out) * 0.05
	# the arpeggio: one soft bell note every half second, two octaves up
	var step: int = int(floor(local / 0.5))
	var tn: float = local - float(step) * 0.5
	var note: float = float((CHORDS[k] as Array)[int(ARP[step % ARP.size()])]) * 4.0
	var env: float = minf(1.0, tn / 0.01) * exp(-5.0 * tn) * minf(1.0, (0.5 - tn) / 0.04)
	out += (sin(TAU * note * tn) + 0.25 * sin(TAU * note * 2.0 * tn)) * env * 0.07
	return out


## Soft chord: each note plus a slightly detuned copy (a gentle chorus) and a quiet octave.
static func _pad(chord: Array, t: float) -> float:
	var sum: float = 0.0
	for i in range(chord.size()):
		var f: float = float(chord[i])
		sum += sin(TAU * f * t) + 0.5 * sin(TAU * f * 1.003 * t) + 0.2 * sin(TAU * f * 2.0 * t)
	return sum / (1.7 * float(chord.size()))
