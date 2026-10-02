extends RefCounted
class_name PlaceholderSounds
## Short blips made on the spot, standing in for the sounds PictureFeedback has
## no file for yet: a rising note for picking something up, a buzz for the
## wrong item, a little chime for a clue. Nothing to import, nothing shipped -
## and each is gone the moment a real sound goes in its slot.

const RATE := 22050

## Per sound: the notes it is made of, one after another -
## [from Hz, to Hz, seconds, wave, loudness]. Wave is "sine", "square",
## "noise" or "rest".
const RECIPES := {
	"hover": [[1800, 1800, 0.012, "noise", 0.05]],
	"look": [[620, 700, 0.06, "sine", 0.28]],
	"take": [[480, 900, 0.1, "sine", 0.3]],
	"talk": [[520, 520, 0.05, "square", 0.1], [0, 0, 0.03, "rest", 0.0], [640, 640, 0.05, "square", 0.1]],
	"go": [[300, 900, 0.16, "noise", 0.12]],
	"back": [[800, 300, 0.12, "noise", 0.1]],
	"locked": [[190, 170, 0.1, "square", 0.12]],
	"use_right": [[523, 523, 0.07, "sine", 0.3], [659, 659, 0.11, "sine", 0.3]],
	"use_wrong": [[150, 140, 0.16, "square", 0.12]],
	"combine_right": [[523, 523, 0.06, "sine", 0.3], [659, 659, 0.06, "sine", 0.3], [784, 784, 0.13, "sine", 0.3]],
	"combine_wrong": [[220, 180, 0.15, "square", 0.12]],
	"clue": [[880, 880, 0.08, "sine", 0.26], [1320, 1320, 0.18, "sine", 0.2]],
	"deduction": [[523, 523, 0.07, "sine", 0.26], [659, 659, 0.07, "sine", 0.26], [784, 784, 0.07, "sine", 0.26], [1047, 1047, 0.22, "sine", 0.26]],
	"no_deduction": [[440, 440, 0.08, "sine", 0.24], [330, 330, 0.15, "sine", 0.24]],
	"present": [[392, 392, 0.08, "sine", 0.26], [587, 587, 0.17, "sine", 0.26]],
	"dial": [[2600, 1800, 0.018, "noise", 0.2]],
	"pick_up": [[900, 1250, 0.045, "sine", 0.2]],
	"put_down": [[700, 480, 0.05, "sine", 0.2]],
	"snap": [[1600, 1600, 0.02, "square", 0.1], [1000, 1000, 0.05, "sine", 0.24]],
	"solved": [[523, 523, 0.08, "sine", 0.28], [784, 784, 0.08, "sine", 0.28], [1047, 1047, 0.26, "sine", 0.28]],
	"lens": [[320, 900, 0.18, "sine", 0.14]],
	"journal": [[900, 350, 0.11, "noise", 0.1]],
}

static var _made := {}


## The blip for `event`, made once and kept. A plain click for anything without
## a recipe.
static func make(event: String) -> AudioStreamWAV:
	if _made.has(event):
		return _made[event]
	var notes: Array = RECIPES.get(event, [[700, 700, 0.03, "sine", 0.2]])
	var data := PackedByteArray()
	var noise := RandomNumberGenerator.new()
	noise.seed = hash(event)
	for note in notes:
		var count := int(RATE * float(note[2]))
		var phase := 0.0
		var held := 0.0
		for i in count:
			var t := float(i) / maxf(count - 1, 1)
			var hz := lerpf(float(note[0]), float(note[1]), t)
			phase += TAU * hz / RATE
			var value := 0.0
			match note[3]:
				"sine":
					value = sin(phase)
				"square":
					value = 1.0 if sin(phase) >= 0.0 else -1.0
				"noise":
					# Held for a stretch set by the pitch, so a higher "note"
					# is a finer hiss.
					if fmod(phase, TAU) < TAU * hz / RATE or i == 0:
						held = noise.randf_range(-1.0, 1.0)
					value = held
			# In and out over a few milliseconds, so no note starts or stops
			# with a click of its own.
			var edge := minf(minf(float(i), float(count - i)) / (RATE * 0.004), 1.0)
			var sample := int(clampf(value * float(note[4]) * edge, -1.0, 1.0) * 32767.0)
			data.append(sample & 0xFF)
			data.append((sample >> 8) & 0xFF)
	var stream := AudioStreamWAV.new()
	stream.format = AudioStreamWAV.FORMAT_16_BITS
	stream.mix_rate = RATE
	stream.stereo = false
	stream.data = data
	_made[event] = stream
	return stream
