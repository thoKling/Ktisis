extends RefCounted
## Génère le terrain d'une mission à partir de quelques paramètres et d'une graine.

const Defs = preload("res://scripts/sim/defs.gd")


static func generate(cfg: Dictionary) -> Dictionary:
	var w := int(cfg.get("width", 48))
	var h := int(cfg.get("height", 48))
	var rng := RandomNumberGenerator.new()
	rng.seed = int(cfg.get("seed", 1))
	var t := PackedByteArray()
	t.resize(w * h)
	t.fill(Defs.T_GRASS)
	var entry := Vector2i(0, h / 2)

	# Côte à l'est : une bande d'eau au bord irrégulier.
	if str(cfg.get("coast", "")) == "east":
		var off := 0
		for y in h:
			off = clampi(off + rng.randi_range(-1, 1), 0, 3)
			var start := w - 7 - off
			for x in range(start, w):
				t[y * w + x] = Defs.T_WATER

	_blobs(t, w, h, rng, entry, int(cfg.get("lakes", 0)), Defs.T_WATER, 2, 4)
	_blobs(t, w, h, rng, entry, int(cfg.get("meadows", 5)), Defs.T_MEADOW, 3, 6)
	_blobs(t, w, h, rng, entry, int(cfg.get("forests", 4)), Defs.T_FOREST, 2, 4)
	_blobs(t, w, h, rng, entry, int(cfg.get("rocks", 2)), Defs.T_ROCK, 1, 3)

	# Dégage l'entrée de la carte.
	for x in range(0, 8):
		for y in range(entry.y - 2, entry.y + 3):
			t[y * w + x] = Defs.T_GRASS
	return {"terrain": t, "width": w, "height": h, "entry": entry}


static func _blobs(t: PackedByteArray, w: int, h: int, rng: RandomNumberGenerator, entry: Vector2i,
		count: int, kind: int, rmin: int, rmax: int) -> void:
	for i in count:
		var c := Vector2i.ZERO
		var tries := 0
		while tries < 50:
			c = Vector2i(rng.randi_range(2, w - 3), rng.randi_range(2, h - 3))
			tries += 1
			if Vector2(c - entry).length() > 10 and t[c.y * w + c.x] != Defs.T_WATER:
				break
		var r := rng.randi_range(rmin, rmax)
		for y in range(c.y - r, c.y + r + 1):
			for x in range(c.x - r, c.x + r + 1):
				if x < 0 or y < 0 or x >= w or y >= h:
					continue
				var d := Vector2(x - c.x, y - c.y).length()
				if d <= r * rng.randf_range(0.6, 1.05) and t[y * w + x] != Defs.T_WATER:
					t[y * w + x] = kind
