extends RefCounted
## Projection isométrique 2:1. Une tuile fait 64 x 32 px ; le coin haut de la tuile (x, y) est en to_screen(x, y).

const TW := 64.0
const TH := 32.0


static func to_screen(p: Vector2) -> Vector2:
	return Vector2((p.x - p.y) * TW * 0.5, (p.x + p.y) * TH * 0.5)


static func to_tile(s: Vector2) -> Vector2:
	var a := s.x / (TW * 0.5)
	var b := s.y / (TH * 0.5)
	return Vector2((a + b) * 0.5, (b - a) * 0.5)


static func tile_at(s: Vector2) -> Vector2i:
	var t := to_tile(s)
	return Vector2i(floori(t.x), floori(t.y))


## Losange d'une zone de n x m tuiles dont le coin est en p.
static func diamond(p: Vector2, n: float = 1.0, m: float = -1.0) -> PackedVector2Array:
	if m < 0.0:
		m = n
	return PackedVector2Array([
		to_screen(p), to_screen(p + Vector2(n, 0)), to_screen(p + Vector2(n, m)), to_screen(p + Vector2(0, m)),
	])
