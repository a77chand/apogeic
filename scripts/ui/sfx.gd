extends Node
## Sound effects, made in code. There are no audio files, so nothing to license and
## nothing to load: every sound is built once at start-up as a small WAV in memory.
## main.gd creates one of these and stores it in GameState.sfx.
## Play a sound from anywhere with  GameState.play_sound("click").
## A web browser only allows sound after the first click, which is fine: every sound
## here answers a click or follows one.

const RATE: int = 22050
const VOICES: int = 6          # how many sounds can overlap

var _streams: Dictionary = {}  # name -> AudioStreamWAV
var _players: Array = []
var _next: int = 0


func _ready() -> void:
	_streams = build_streams()
	for i in range(VOICES):
		var p: AudioStreamPlayer = AudioStreamPlayer.new()
		p.volume_db = -6.0
		add_child(p)
		_players.append(p)


func play(id: String) -> void:
	if not _streams.has(id):
		return
	var p: AudioStreamPlayer = _players[_next]
	_next = (_next + 1) % _players.size()
	p.stream = _streams[id]
	p.play()


## Every sound the game has. Public so a test can check them without playing.
static func build_streams() -> Dictionary:
	var out: Dictionary = {}
	out["click"] = _wav(_tone(1100.0, 0.04, 0.35, 60.0))
	out["fit"] = _wav(_join([_tone(520.0, 0.07, 0.35, 25.0), _tone(780.0, 0.10, 0.35, 22.0)]))
	out["ping"] = _wav(_tone(1500.0, 0.14, 0.30, 16.0))
	out["alert"] = _wav(_join([_tone(880.0, 0.12, 0.35, 14.0), _silence(0.05), _tone(880.0, 0.12, 0.35, 14.0)]))
	# three rising notes: C5, E5, G5
	out["chime"] = _wav(_join([_tone(523.25, 0.14, 0.35, 9.0), _tone(659.25, 0.14, 0.35, 9.0), _tone(783.99, 0.55, 0.35, 5.0)]))
	out["fail"] = _wav(_slide(420.0, 170.0, 0.55, 0.32))
	out["rumble"] = _wav(_rumble(2.4, 0.5))
	return out


# ---------------------------------------------------------------- building blocks

static func _wav(samples: PackedFloat32Array) -> AudioStreamWAV:
	var data: PackedByteArray = PackedByteArray()
	data.resize(samples.size() * 2)
	for i in range(samples.size()):
		data.encode_s16(i * 2, int(clampf(samples[i], -1.0, 1.0) * 32000.0))
	var s: AudioStreamWAV = AudioStreamWAV.new()
	s.format = AudioStreamWAV.FORMAT_16_BITS
	s.mix_rate = RATE
	s.stereo = false
	s.data = data
	return s


## A sine tone that fades out. `decay` is how fast it dies (bigger = shorter ring).
static func _tone(freq: float, seconds: float, volume: float, decay: float) -> PackedFloat32Array:
	var n: int = int(seconds * float(RATE))
	var out: PackedFloat32Array = PackedFloat32Array()
	out.resize(n)
	for i in range(n):
		var t: float = float(i) / float(RATE)
		var attack: float = minf(1.0, t / 0.004)       # 4 ms fade-in, so there is no pop
		var release: float = minf(1.0, (seconds - t) / 0.01)  # and a 10 ms fade-out at the end
		out[i] = sin(TAU * freq * t) * exp(-decay * t) * attack * maxf(0.0, release) * volume
	return out


static func _silence(seconds: float) -> PackedFloat32Array:
	var out: PackedFloat32Array = PackedFloat32Array()
	out.resize(int(seconds * float(RATE)))
	return out


static func _join(parts: Array) -> PackedFloat32Array:
	var out: PackedFloat32Array = PackedFloat32Array()
	for part in parts:
		out.append_array(part)
	return out


## A tone whose pitch slides from f0 to f1 (used for the gentle failure sound).
static func _slide(f0: float, f1: float, seconds: float, volume: float) -> PackedFloat32Array:
	var n: int = int(seconds * float(RATE))
	var out: PackedFloat32Array = PackedFloat32Array()
	out.resize(n)
	var phase: float = 0.0
	for i in range(n):
		var t: float = float(i) / float(RATE)
		var freq: float = f0 + (f1 - f0) * (t / seconds)
		phase += TAU * freq / float(RATE)
		var attack: float = minf(1.0, t / 0.01)
		var release: float = minf(1.0, (seconds - t) / 0.12)
		out[i] = sin(phase) * attack * maxf(0.0, release) * volume
	return out


## Low rumble: smoothed noise plus a deep tone, swelling in then fading out.
## The noise comes from a fixed formula, so it sounds the same every time.
static func _rumble(seconds: float, volume: float) -> PackedFloat32Array:
	var n: int = int(seconds * float(RATE))
	var out: PackedFloat32Array = PackedFloat32Array()
	out.resize(n)
	var seed_value: int = 12345
	var smooth: float = 0.0
	for i in range(n):
		var t: float = float(i) / float(RATE)
		seed_value = (seed_value * 1103515245 + 12345) & 0x7fffffff
		var noise: float = float(seed_value) / float(0x7fffffff) * 2.0 - 1.0
		smooth += (noise - smooth) * 0.06                # low-pass: keeps only the low rumble
		var swell: float = minf(1.0, t / 0.5) * minf(1.0, (seconds - t) / 0.7)
		out[i] = (smooth * 2.2 + sin(TAU * 52.0 * t) * 0.35) * swell * volume
	return out
