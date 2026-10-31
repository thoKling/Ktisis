extends RefCounted
## Habillage graphique. Tout passe par ici pour pouvoir remplacer les formes provisoires par des sprites :
## si res://assets/<dossier>/<nom>.png existe, il est utilisé, sinon on dessine une forme simple.
## Voir assets/README.md pour les conventions (angle, échelle, point d'ancrage).

const Grid = preload("res://src/domain/world/grid.gd")

# Palette commune : marbre, terre cuite, ocre, vert olivier, bleu égéen.
const MARBLE := Color("#efe9dc")
const TERRACOTTA := Color("#c2673f")
const OCHRE := Color("#d4a24c")
const OLIVE := Color("#7d8a3e")
const AEGEAN := Color("#2f6f9f")

const TERRAIN_COLORS := {
	Grid.T_GRASS: Color("#a3ad6c"),
	Grid.T_WATER: Color("#3d78a8"),
	Grid.T_FOREST: Color("#5f7a3c"),
	Grid.T_ROCK: Color("#a59d90"),
	Grid.T_MEADOW: Color("#bcc76a"),
	Grid.T_HILL: Color("#d6c7a2"),
}
const ROAD_COLOR := Color("#d8c39a")
const ROAD_EDGE := Color("#b09468")

const CATEGORY_COLORS := {
	"habitat": TERRACOTTA,
	"alimentation": OCHRE,
	"industrie": Color("#9c7a54"),
	"stockage": Color("#b88d58"),
	"services": Color("#6f9fc0"),
	"religion": MARBLE,
	"beaute": Color("#86a85a"),
	"monuments": MARBLE,
}

const WALKER_COLORS := {
	"water": Color("#4aa3e0"),
	"market": OCHRE,
	"priest": Color("#ffffff"),
	"sanctuary": Color("#c9a6ff"),
	"tax": Color("#f2d24b"),
	"guard": Color("#c0392b"),
	"cart": Color("#7a5230"),
	"immigrant": Color("#6b6b6b"),
}

const SHORT_LABELS := {
	"farm": "Blé", "fishery": "Pêche", "granary": "Grenier", "warehouse": "Entrepôt", "agora": "Agora",
	"olive_grove": "Olives", "press": "Huile", "sheepfold": "Laine", "woodcutter": "Bois", "quarry": "Marbre",
	"tax_office": "Impôt", "guard_post": "Vigie", "altar_demeter": "Déméter", "altar_athena": "Athéna",
	"altar_poseidon": "Poséidon", "altar_hera": "Héra", "sanctuary_demeter": "Déméter",
	"sanctuary_athena": "Athéna", "sanctuary_poseidon": "Poséidon", "sanctuary_hera": "Héra",
	"argo_shipyard": "Argo", "propylaea": "Propylées", "parthenon": "Parthénon", "temple_poseidon": "Poséidon",
	"sacred_olive": "Olivier", "salt_spring": "Source",
}

## Les sprites sont rendus en 4x (voir tools/art) : on les dessine au quart pour rester nets au zoom et sur grand écran.
const SPRITE_SCALE := 0.25
## Nombre de variantes de sol (motif périodique de K x K tuiles).
const TERRAIN_K := 4

static var _textures := {}


## Texture optionnelle res://assets/<folder>/<name>.png, mise en cache (null si absente).
static func texture(folder: String, name: String) -> Texture2D:
	var key := folder + "/" + name
	if _textures.has(key):
		return _textures[key]
	var path := "res://assets/%s.png" % key
	var tex: Texture2D = null
	if ResourceLoader.exists(path):
		tex = load(path)
	_textures[key] = tex
	return tex


## Dessine un sprite dont le bas-milieu est posé en bottom.
static func draw_sprite(ci: CanvasItem, tex: Texture2D, bottom: Vector2) -> void:
	var size := tex.get_size() * SPRITE_SCALE
	ci.draw_texture_rect(tex, Rect2(bottom - Vector2(size.x * 0.5, size.y), size), false)


## Hauteur à l'écran d'un sprite (0 s'il n'existe pas).
static func sprite_height(tex: Texture2D) -> float:
	return tex.get_height() * SPRITE_SCALE if tex != null else 0.0


## Sol de la tuile p : variante périodique si elle existe, sinon texture unique.
static func terrain_texture(t: int, p: Vector2i) -> Texture2D:
	var v := posmod(p.x, TERRAIN_K) + posmod(p.y, TERRAIN_K) * TERRAIN_K
	var tex := texture("terrain", "%d_%d" % [t, v])
	return tex if tex != null else texture("terrain", str(t))


## Sprite d'un bâtiment dans son état du moment (niveau de maison, étape de chantier) ; null s'il n'y en a pas.
## Le même sert sur la carte et dans la fiche du panneau gauche.
static func building_texture(b) -> Texture2D:
	if b.kind() == "house":
		if b.pop == 0:
			var empty := texture("buildings", "house_empty")
			if empty != null:
				return empty
		return texture("buildings", "%s_%d" % [b.type, b.level])
	if b.kind() == "monument" and not b.complete:
		var stage := texture("buildings", "%s_s%d" % [b.type, b.stage])
		if stage == null:
			stage = texture("buildings", "monument_s%d" % b.stage)
		if stage != null:
			return stage
	return texture("buildings", b.type)


static func building_color(def: Dictionary, level: int = 0) -> Color:
	var c: Color = CATEGORY_COLORS.get(def.get("category", ""), Color.GRAY)
	if def.get("kind", "") == "house":
		c = Color("#b89a74").lerp(MARBLE, level / 4.0)
	return c


static func building_height(b) -> float:
	var d: Dictionary = b.def
	match d["kind"]:
		"house":
			return 10.0 + b.level * 6.0
		"deco":
			return 4.0 if d["size"] > 1 else 14.0
		"producer":
			return 8.0 if d["size"] >= 3 else 18.0
		"monument":
			var n: float = d["stages"].size()
			var done: float = n if b.complete else b.stage + b.progress / float(d["stage_ticks"])
			return 6.0 + 50.0 * done / n
	return 12.0 + d["size"] * 6.0
