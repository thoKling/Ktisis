extends RefCounted
## Un marcheur dans les rues : service (eau, marché, prêtre, impôt, vigile, sanctuaire),
## livreur (cart) ou groupe d'immigrants.

var id := 0
var kind := ""          # "service", "cart", "immigrant"
var service := ""
var god := ""
var home := -1          # bâtiment d'origine
var target := -1        # bâtiment de destination (livreur, immigrant)
var pos := Vector2i.ZERO
var prev := Vector2i.ZERO
var path := []          # cases restantes à parcourir
var steps_left := 0
var returning := false
var cargo_res := ""
var cargo_amt := 0
var group := 0
var move_t := 0
var visited := {}
