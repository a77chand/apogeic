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
	process_mode = Node.PROCESS_MODE_ALWAYS   # clicks still sound while the menu pauses the game
	_streams = build_streams()
	for i in range(VOICES):
		var p: AudioStreamPlayer = AudioStreamPlayer.new()
		p.volume_db = -6.0
		add_child(p)
		_players.append(p)


## volume is 0..1 (0 = silent). The loudest setting is the old fixed level.
func set_volume(volume: float) -> void:
	var db: float = -80.0
	if volume > 0.001:
		db = -6.0 + linear_to_db(volume)
	for item in _players:
		var p: AudioStreamPlayer = item
		p.volume_db = db


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
	out["power_down"] = _wav(_power_down(1.15, 0.26))
	# a harsh alarm buzzer: two low square-ish blasts
	out["error"] = _wav(_join([_buzz(150.0, 0.28, 0.30), _silence(0.07), _buzz(150.0, 0.28, 0.30), _silence(0.07), _buzz(110.0, 0.5, 0.30)]))
	# an explosion: a loud burst of noise that dies away
	out["boom"] = _wav(_boom(1.6, 0.9))
	# countdown: a short beep for 3, 2, 1, then a higher, longer tone at lift-off
	out["beep"] = _wav(_bell(740.0, 0.16, 0.30, 18.0))
	out["go"] = _wav(_bell(1110.0, 0.45, 0.32, 6.0))
	# picking a part: a very small, soft tick
	out["select"] = _wav(_join([_tone(1400.0, 0.025, 0.16, 90.0), _tone(2100.0, 0.03, 0.10, 90.0)]))
	# puzzle solved: quick rising notes (G4 C5 E5 G5), a held bell C6, and a light sparkle
	var fan: PackedFloat32Array = _join([_bell(392.0, 0.09, 0.26, 12.0), _bell(523.25, 0.09, 0.26, 12.0),
			_bell(659.25, 0.09, 0.26, 12.0), _bell(783.99, 0.09, 0.26, 12.0)])
	var held: PackedFloat32Array = _bell(1046.5, 0.75, 0.30, 4.0)
	var sparkle: PackedFloat32Array = _sparkle(0.75)
	for i in range(held.size()):
		held[i] += sparkle[i]
	fan.append_array(held)
	out["fanfare"] = _wav(fan)
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


## A bell-like note: the base tone plus softer overtones, so it rings instead of buzzing.
static func _bell(freq: float, seconds: float, volume: float, decay: float) -> PackedFloat32Array:
	var n: int = int(seconds * float(RATE))
	var out: PackedFloat32Array = PackedFloat32Array()
	out.resize(n)
	for i in range(n):
		var t: float = float(i) / float(RATE)
		var attack: float = minf(1.0, t / 0.004)
		var release: float = minf(1.0, (seconds - t) / 0.015)
		var wave: float = sin(TAU * freq * t) + 0.35 * sin(TAU * freq * 2.0 * t) * exp(-decay * 1.5 * t) + 0.15 * sin(TAU * freq * 3.0 * t) * exp(-decay * 2.5 * t)
		out[i] = wave / 1.5 * exp(-decay * t) * attack * maxf(0.0, release) * volume
	return out


## Tiny high "twinkles" scattered over the length, from a fixed pattern (same every time).
static func _sparkle(seconds: float) -> PackedFloat32Array:
	var n: int = int(seconds * float(RATE))
	var out: PackedFloat32Array = PackedFloat32Array()
	out.resize(n)
	var notes: Array = [[0.02, 2637.0], [0.10, 3136.0], [0.19, 2793.0], [0.28, 3520.0], [0.38, 3136.0]]
	for item in notes:
		var start: int = int(float(item[0]) * float(RATE))
		var freq: float = float(item[1])
		for j in range(int(0.12 * float(RATE))):
			if start + j >= n:
				break
			var t: float = float(j) / float(RATE)
			out[start + j] += sin(TAU * freq * t) * exp(-30.0 * t) * 0.07
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
## Going home or resetting: a falling, wobbling tone that winds down in steps, like an old
## arcade machine powering off, but soft. Square-ish wave, so it reads as "game" not "alarm".
static func _power_down(seconds: float, volume: float) -> PackedFloat32Array:
	var n: int = int(seconds * float(RATE))
	var out: PackedFloat32Array = PackedFloat32Array()
	out.resize(n)
	var phase: float = 0.0
	for i in range(n):
		var t: float = float(i) / float(RATE)
		var u: float = t / seconds
		# five falling "wah" steps, each sliding down, the whole thing dropping in pitch
		var step: float = fmod(u * 5.0, 1.0)
		var f: float = lerpf(620.0, 90.0, u) * (1.25 - 0.35 * step)
		phase += f / float(RATE)
		var wave: float = 0.6 * sign(sin(TAU * phase)) + 0.4 * sin(TAU * phase)
		var env: float = (1.0 - u) * minf(1.0, t * 40.0) * (0.75 + 0.25 * cos(step * PI))
		out[i] = wave * env * volume * 0.6
	return out


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


## A buzzer: a sine pushed hard so it clips into a rough, square-like tone.
static func _buzz(freq: float, seconds: float, volume: float) -> PackedFloat32Array:
	var n: int = int(seconds * float(RATE))
	var out: PackedFloat32Array = PackedFloat32Array()
	out.resize(n)
	for i in range(n):
		var t: float = float(i) / float(RATE)
		var attack: float = minf(1.0, t / 0.005)
		var release: float = minf(1.0, (seconds - t) / 0.02)
		var wave: float = clampf(sin(TAU * freq * t) * 3.0, -1.0, 1.0) * 0.7 + clampf(sin(TAU * freq * 1.5 * t) * 3.0, -1.0, 1.0) * 0.3
		out[i] = wave * attack * maxf(0.0, release) * volume
	return out


## An explosion: a sharp crack of noise, then a low rumble that fades. Fixed seed, so it
## sounds the same every time.
static func _boom(seconds: float, volume: float) -> PackedFloat32Array:
	var n: int = int(seconds * float(RATE))
	var out: PackedFloat32Array = PackedFloat32Array()
	out.resize(n)
	var seed_value: int = 777
	var low: float = 0.0
	for i in range(n):
		var t: float = float(i) / float(RATE)
		seed_value = (seed_value * 1103515245 + 12345) & 0x7fffffff
		var noise: float = float(seed_value) / float(0x7fffffff) * 2.0 - 1.0
		low += (noise - low) * 0.04
		var crack: float = noise * exp(-t * 18.0)
		var body: float = low * 3.0 * exp(-t * 2.2) + sin(TAU * 40.0 * t) * 0.4 * exp(-t * 3.0)
		out[i] = clampf((crack * 0.6 + body) * volume, -1.0, 1.0)
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
