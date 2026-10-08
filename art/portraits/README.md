Dialogue portraits. Square transparent PNGs (512x512 or larger), named after
the speaker exactly as the dialogue writes them - lowercase, spaces become
underscores:

    cyrus_rowe.png            the everyday face, for "Cyrus Rowe: ..."
    cyrus_rowe_worried.png    an expression, chosen with [#worried] on the line
    old_man.png               "Old Man"

Written in the dialogue itself, next to the line it belongs to:

    Cyrus Rowe: I don't like this.
    Cyrus Rowe: [#scared] I really don't.
    Cyrus Rowe: [#portrait=smile_sweat] Ready when you are.
    Cyrus Rowe: [#noportrait] ...

Anything with no matching file shows no portrait at all, so half-drawn
characters degrade to the plain balloon rather than a blank box - and an
expression with no file of its own falls back to the everyday face.

Cyrus has: cyrus_rowe (neutral, the everyday face), and the expressions
excited, grin, nervous_sweat, scared, serious, smile_sweat and smug.

512 is the least: the balloon gives a portrait about 180px of height in the
1280x720 design space, and the game stretches - x1.5 at 1080p, x2 on a Retina
display - so 512 still has headroom past 2x.
