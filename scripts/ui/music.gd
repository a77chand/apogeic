extends Node
## Background music, made in code like the sound effects (no audio files to license).
## An upbeat space loop, 16 seconds long at 120 beats a minute: a bright plucked arpeggio,
## a pulsing bass, soft pad chords and a light beat (kick on the beat, a tick in between).
## It is built a little at a time over the first second (so start-up does not freeze),
## then loops forever. main.gd creates one and stores it in GameState.music.
## The volume comes from GameState (menu slider); it is kept low even at full volume.

const RATE: int = 11025           # low sample rate: the music has no high notes, and it builds faster
const CHORD_SECONDS: float = 2.0      # one bar at 120 bpm
const BEAT: float = 0.5
const CHUNK: int = 6000           # samples built per frame
const MAX_DB: float = -14.0       # full volume is still quiet behind the game

## Eight chords, each as four notes (Hz): C, G, Am, F, C, G, F, Gsus. Bright and hopeful.
const CHORDS: Array = [
	[130.81, 164.81, 196.00, 261.63],
	[98.00, 123.47, 146.83, 196.00],
	[110.00, 130.81, 164.81, 220.00],
	[87.31, 110.00, 130.81, 174.61],
	[130.81, 164.81, 196.00, 261.63],
	[98.00, 123.47, 146.83, 196.00],
	[87.31, 110.00, 130.81, 174.61],
	[98.00, 130.81, 146.83, 196.00],
]
const ARP: Array = [0, 1, 2, 3, 2, 3, 1, 2]   # which chord note each eighth note plays


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
	var chord: Array = CHORDS[k]
	# soft pad underneath, short fade at each chord change so the loop has no clicks
	var edge: float = minf(1.0, minf(local / 0.05, (CHORD_SECONDS - local) / 0.05))
	var out: float = _pad(chord, local) * 0.10 * edge
	# plucked arpeggio: an eighth note every quarter second, two octaves up, bright and short
	var step: int = int(floor(local / (BEAT * 0.5)))
	var tn: float = local - float(step) * BEAT * 0.5
	var note: float = float(chord[int(ARP[step % ARP.size()])]) * 4.0
	var pluck: float = minf(1.0, tn / 0.004) * exp(-11.0 * tn)
	var tri: float = 2.0 * absf(2.0 * fposmod(note * tn, 1.0) - 1.0) - 1.0
	out += (0.7 * tri + 0.3 * sin(TAU * note * 2.0 * tn)) * pluck * 0.085
	# pulsing bass: the root on every eighth note, octave jump on the off-beats
	var root: float = float(chord[0]) * 0.5 * (2.0 if step % 2 == 1 else 1.0)
	var benv: float = minf(1.0, tn / 0.006) * exp(-7.0 * tn)
	out += sin(TAU * root * tn) * benv * 0.16
	# the beat: a soft kick on each beat, a quiet tick on the off-beats
	var bt: float = fposmod(local, BEAT)
	var kick_f: float = 110.0 * exp(-18.0 * bt) + 45.0
	out += sin(TAU * kick_f * bt) * exp(-14.0 * bt) * 0.22
	var off: float = fposmod(local - BEAT * 0.5, BEAT)
	var noise: float = fposmod(sin(t * 91234.5678) * 43758.5453, 1.0) * 2.0 - 1.0
	out += noise * exp(-60.0 * off) * 0.035
	return out


## Soft chord: each note plus a slightly detuned copy (a gentle chorus) and a quiet octave.
static func _pad(chord: Array, t: float) -> float:
	var sum: float = 0.0
	for i in range(chord.size()):
		var f: float = float(chord[i])
		sum += sin(TAU * f * t) + 0.5 * sin(TAU * f * 1.003 * t) + 0.2 * sin(TAU * f * 2.0 * t)
	return sum / (1.7 * float(chord.size()))
