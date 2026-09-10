Two kinds of audio, controlled from two different places.

## Skill sounds - chosen in the skill database

Open a skill in res://skills/ and set **Sound** (and **Sound Volume Db** to
trim it). It plays as the skill's animation ENDS, so the noise lands with the
blow rather than under the wind-up. A skill with no sound is silent; a
combatant with no animation resolves instantly and the sound plays then.

Four sounds can overlap before the oldest is cut, so a reaction going off
during someone else's swing does not silence it.

Put the files wherever you like - audio/sfx/ is the obvious home.

## Music - controlled from the dialogue you write

Drop tracks in audio/music/ and refer to them by name, without the extension.
.ogg, .mp3 and .wav all work. Then, in any .dialogue file:

    ~ village_gate
    do Music.play("village")
    Guard: You'll want to speak to the smith.
    do Music.pause()
    Guard: [#worried] ...did you hear that?
    do Music.resume()
    do Music.play("battle", false)     # play once, no looping
    do Music.fade_out(2.0)
    do Music.stop()

Also available: Music.set_looping(true/false), Music.is_playing(), and
Music.current() - the last is useful in a condition:

    if Music.current() == "battle"

play() on the track already playing does nothing, rather than restarting it,
so a scene that can be entered from several directions can safely state its
music each time. A track that does not exist warns and carries on in silence,
so dialogue written ahead of the audio still runs.

Music is an autoload, so it keeps playing across a scene change - walking from
the map into a battle does not restart the score.

## Mixing

There are Music and SFX buses (default_bus_layout.tres), so the two can be
balanced against each other, and a volume slider later has something to move.
