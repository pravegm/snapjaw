# Icon R3: composition

Answers REVIEW-2 #13 and juror P1-5 (the "fanged Pac-Man"). The only file changed is `Snap/UI/AppIconArt.swift`. `AppIconArt` and
`AppIconPainter.paint(_:)` keep their signatures.

**The idea:** a Venus flytrap seen from 3/4 above, half shut around a fat cartoon fly. The fly peeks over the front lip
with its hands on the rim, and its big eyes look up at the jaw that is about to close.

- **Background:** a deep bog green with a radial fade (#4A9E5C glow at the upper left, falling to #05200E). It has three large, soft
  bokeh blobs and nothing thin.
- **Back lobe:** the glossy crimson inner face uses the game's crimson (#F46A7E → #D93A56 → #7E0E2A). It darkens toward the
  hidden hinge and has a white gloss crescent at the upper left plus a small glint. A yellow-green margin (#D8EA62)
  runs along it, with a dark leaf band outside the margin. A crown of 13 long, pale, curved **cilia** (#F2F9CC) sits on top.
  Their soft shadows are silhouetted against the dark bog, and the cilia fan out at the corners. No cilium crosses the crimson or the fly, so nothing reads
  as teeth.
- **Front lobe:** this is the green outside of the leaf, with a soft sheen. Its yellow-green lip runs under the fly's eyes, so the fly
  is clearly *inside* the trap.
- **Fly:** a navy, glossy body with two huge white eyes. Its pupils glance up and to the right toward the closing lobe. It has pale glass wings
  out to the sides and two little hands gripping the lip.
- **Stem:** a broad leafy stem leaves the frame at the bottom left. A soft drop shadow sits under the trap.
- **Tilt:** the whole trap is turned −0.2 rad, so the opening faces up and to the right. That keeps it from reading as an eye, a melon or a pair of lips.

**Rules:** no outlines and no text. Colour and value separate the parts: green / crimson / navy / white. The subject stays
inside the central ~80 %; only the background and the stem reach the edges. The canvas is opaque and full-bleed. All geometry is
in a 1024-unit space with y pointing down.

**Small sizes:** I checked a canvas prototype at 180, 60 and 29 px. At 29 px it still reads as a red cup with a spiky crown and
a fly with two white eyes.
