Dialogue portraits. 512x512 transparent PNGs, named after the character:

    cyrus.png            the everyday face
    cyrus_worried.png    an expression, chosen with [#worried] on the line
    old_man.png          "Old Man" - lowercase, spaces become underscores

Written in the dialogue itself, next to the line it belongs to:

    Cyrus: I don't like this.
    Cyrus: [#worried] I really don't.
    Cyrus: [#portrait=armoured] Ready when you are.
    Cyrus: [#noportrait] ...

Anything with no matching file shows no portrait at all, so half-drawn
characters degrade to the plain balloon rather than a blank box.

512 because the balloon gives a portrait about 180px of height in the 1280x720
design space, and the game stretches - x1.5 at 1080p, x2 on a Retina display -
so 512 still has headroom past 2x.
