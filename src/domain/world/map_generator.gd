extends RefCounted
## Génère le terrain d'une mission à partir de quelques paramètres et d'une graine.
## Une carte peut aussi être dessinée à la main avec des formes (features), appliquées dans l'ordre
## après les taches aléatoires : c'est ainsi qu'Athènes a sa colline, sa mer et son port.

const Grid = preload("res://src/domain/world/grid.gd")


## Renvoie {"grid": Grid, "entry": Vector2i}.
static func generate(cfg: Dictionary) -> Dictionary:
	var w := int(cfg.get("width", 48))
	var h := int(cfg.get("height", 48))
	var rng := RandomNumberGenerator.new()
	rng.seed = int(cfg.get("seed", 1))
	var t := PackedByteArray()
	t.resize(w * h)
	t.fill(Grid.T_GRASS)
	var entry := Vector2i(0, h / 2)
	if cfg.has("entry"):
		entry = Vector2i(int(cfg["entry"][0]), int(cfg["entry"][1]))

	# Côte à l'est : une bande d'eau au bord irrégulier.
	if str(cfg.get("coast", "")) == "east":
		_band(t, w, h, rng, "east", 7, 3, Grid.T_WATER)

	_blobs(t, w, h, rng, entry, int(cfg.get("lakes", 0)), Grid.T_WATER, 2, 4)
	_blobs(t, w, h, rng, entry, int(cfg.get("meadows", 5)), Grid.T_MEADOW, 3, 6)
	_blobs(t, w, h, rng, entry, int(cfg.get("forests", 4)), Grid.T_FOREST, 2, 4)
	_blobs(t, w, h, rng, entry, int(cfg.get("rocks", 2)), Grid.T_ROCK, 1, 3)

	for f in cfg.get("features", []):
		_feature(t, w, h, rng, f)

	# Dégage l'entrée de la carte.
	for x in range(0, 8):
		for y in range(entry.y - 2, entry.y + 3):
			if x < w and y >= 0 and y < h:
				t[y * w + x] = Grid.T_GRASS
	return {"grid": Grid.new(w, h, t), "entry": entry}


## Une forme dessinée : {"terrain", "shape": "ellipse" | "band" | "rect", ...}.
##   ellipse : "at" [x, y], "r" [rx, ry], "rough" (0 à 0.5 : bord irrégulier) ;
##   band : "side" (north, south, east, west), "depth" en cases, "rough" en cases ;
##   rect : "from" [x, y], "to" [x, y] (inclus).
static func _feature(t: PackedByteArray, w: int, h: int, rng: RandomNumberGenerator, f: Dictionary) -> void:
	var kind: int = Grid.TERRAIN_NAMES[f["terrain"]]
	match str(f["shape"]):
		"band":
			_band(t, w, h, rng, str(f["side"]), int(f["depth"]), int(f.get("rough", 2)), kind)
		"rect":
			for y in range(maxi(0, int(f["from"][1])), mini(h, int(f["to"][1]) + 1)):
				for x in range(maxi(0, int(f["from"][0])), mini(w, int(f["to"][0]) + 1)):
					t[y * w + x] = kind
		"ellipse":
			var c := Vector2(float(f["at"][0]), float(f["at"][1]))
			var r := Vector2(float(f["r"][0]), float(f["r"][1]))
			var rough := float(f.get("rough", 0.0))
			# Bord irrégulier : le rayon varie avec l'angle, selon quelques ondes tirées au hasard.
			var waves := []
			for i in 3:
				waves.append([rng.randi_range(2, 5), rng.randf() * TAU, rng.randf_range(0.3, 1.0)])
			for y in range(maxi(0, floori(c.y - r.y * 1.6)), mini(h, ceili(c.y + r.y * 1.6) + 1)):
				for x in range(maxi(0, floori(c.x - r.x * 1.6)), mini(w, ceili(c.x + r.x * 1.6) + 1)):
					var d := Vector2((x + 0.5 - c.x) / r.x, (y + 0.5 - c.y) / r.y)
					var edge := 1.0
					if rough > 0.0:
						var a := d.angle()
						var n := 0.0
						for wv in waves:
							n += sin(a * wv[0] + wv[1]) * wv[2]
						edge += rough * n / 2.0
					if d.length() <= edge:
						t[y * w + x] = kind


## Bande le long d'un bord de la carte, au bord irrégulier (marche aléatoire).
static func _band(t: PackedByteArray, w: int, h: int, rng: RandomNumberGenerator, side: String, depth: int,
		rough: int, kind: int) -> void:
	var along := w if side in ["north", "south"] else h
	var off := 0
	for i in along:
		off = clampi(off + rng.randi_range(-1, 1), 0, rough)
		var d := depth + off
		for k in d:
			var p: Vector2i
			match side:
				"east":
					p = Vector2i(w - 1 - k, i)
				"west":
					p = Vector2i(k, i)
				"south":
					p = Vector2i(i, h - 1 - k)
				_:
					p = Vector2i(i, k)
			if p.x >= 0 and p.y >= 0 and p.x < w and p.y < h:
				t[p.y * w + p.x] = kind


static func _blobs(t: PackedByteArray, w: int, h: int, rng: RandomNumberGenerator, entry: Vector2i,
		count: int, kind: int, rmin: int, rmax: int) -> void:
	for i in count:
		var c := Vector2i.ZERO
		var tries := 0
		while tries < 50:
			c = Vector2i(rng.randi_range(2, w - 3), rng.randi_range(2, h - 3))
			tries += 1
			if Vector2(c - entry).length() > 10 and t[c.y * w + c.x] != Grid.T_WATER:
				break
		var r := rng.randi_range(rmin, rmax)
		for y in range(c.y - r, c.y + r + 1):
			for x in range(c.x - r, c.x + r + 1):
				if x < 0 or y < 0 or x >= w or y >= h:
					continue
				var d := Vector2(x - c.x, y - c.y).length()
				if d <= r * rng.randf_range(0.6, 1.05) and t[y * w + x] != Grid.T_WATER:
					t[y * w + x] = kind
