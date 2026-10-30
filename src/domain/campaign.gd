extends RefCounted
## Progression de la campagne : quelles missions le joueur peut lancer.

## Phase de test : toutes les missions sont ouvertes depuis le menu.
## Passer à false pour revenir au déblocage mission après mission.
const ALL_MISSIONS_OPEN := true


## La mission d'indice `index` peut-elle être lancée, sachant que `unlocked` missions sont débloquées ?
static func is_open(index: int, unlocked: int, mission_count: int, all_open := ALL_MISSIONS_OPEN) -> bool:
	if index < 0 or index >= mission_count:
		return false
	return all_open or index < maxi(1, unlocked)


## Nombre de missions débloquées après la victoire dans la mission `index`.
static func unlocked_after_win(index: int, unlocked: int, mission_count: int) -> int:
	return clampi(maxi(unlocked, index + 2), 1, mission_count)
