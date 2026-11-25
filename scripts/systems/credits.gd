extends RefCounted
## Credits and licence notices shown in-game (title screen → Credits).
## CC-BY sounds and MIT code/assets must be credited in the shipped game,
## not just in the repo — keep this in sync with docs/ASSET_LICENCES.md.

const GAME := """THE ASCENT

Design, code, levels, procedural sound, shaders, decals, the skyline
and the torch pattern — made for this game.


3D MODELS AND TEXTURES
Poly Haven — polyhaven.com — CC0 (public domain).
Thank you to the Poly Haven artists for the furniture, props, appliances,
machinery and surface textures used on every floor.


CHARACTERS AND MOTION CAPTURE
Microsoft Rocketbox Avatar Library — github.com/microsoft/Microsoft-Rocketbox
Copyright (c) 2020 Microsoft — MIT licence (full text below).
Avatars and mocap clips re-textured, re-scaled and tinted for the game.


SOUND — CC-BY (attribution required)
"Footsteps on different surfaces" by congusbongus — opengameart.org — CC-BY 3.0
    tile steps from "footstep-concrete.wav" by swuing (freesound.org/s/38873)
    and "Squeaky footstep.wav" by ceberation (freesound.org/s/235524);
    water steps from "Water Footsteps" by EminYILDIRIM (freesound.org/s/608663)
    and swuing.
"25 spooky sound effects" by Bart — http://opengameart.org — CC-BY 3.0
    (knocking, door slam)
"Wind Loop" — created by Jonathan Shaw (InspectorJ),
    freesound.org/people/InspectorJ/sounds/376415 — looped by antumdeluge
    (opengameart.org/node/101110) — CC-BY 3.0
"Abandoned Building Ambience" by tcarisland — opengameart.org — CC-BY 3.0
Licences: creativecommons.org/licenses/by/3.0 and /by/4.0
Sounds were trimmed, re-pitched, layered and mixed for the game.


SOUND — CC0 (public domain, credited with thanks)
Kenney (kenney.nl) — Impact Sounds, RPG Audio, Interface Sounds
Bart — heartbeat  ·  ylmir — rain  ·  techiew — ambient horror
rubberduck — metal and wood SFX, water splashes
psychhead — Horror Hit Soundpack 1  ·  NenadSimic — muffled distant explosion
Spring Spring — tape recorder
(all via opengameart.org)


Phone ring, hum, whispers, gasps and the footsteps behind you
are synthesised in code.
"""

const ROCKETBOX_MIT := """Microsoft Rocketbox — MIT License

Copyright (c) 2020 Microsoft

Permission is hereby granted, free of charge, to any person obtaining a copy
of this software and associated documentation files (the "Software"), to deal
in the Software without restriction, including without limitation the rights
to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
copies of the Software, and to permit persons to whom the Software is
furnished to do so, subject to the following conditions:

The above copyright notice and this permission notice shall be included in all
copies or substantial portions of the Software.

THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
SOFTWARE.
"""

## One-line credit for the ending summary.
const SHORT := "Made with Godot Engine  ·  Models: Poly Haven (CC0)  ·  Characters: Microsoft Rocketbox (MIT)\nSound: Kenney, Bart, InspectorJ, congusbongus, tcarisland and others  ·  Full credits on the title screen"

## Everything, including the Godot engine licence and its third-party notices.
static func full_text() -> String:
	var s := GAME + "\n\n" + ROCKETBOX_MIT
	s += "\n\nGODOT ENGINE\nThis game uses Godot Engine, available under the following license:\n\n"
	s += Engine.get_license_text()
	s += "\n\nGodot Engine includes third-party components:\n"
	for c in Engine.get_copyright_info():
		for p in c.parts:
			s += "\n%s — © %s — %s" % [c.name, ", ".join(PackedStringArray(p.copyright)), p.license]
	var li: Dictionary = Engine.get_license_info()
	for k in li:
		s += "\n\n——— %s ———\n%s" % [k, li[k]]
	return s
