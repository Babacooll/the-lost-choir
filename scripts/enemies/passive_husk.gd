class_name PassiveHusk
extends EnemyBase
## R2's Strike-teaching target — "1 Strike = 1, three to kill" on a husk that
## can never hurt the player back. Aggro range 0 (EnemyBase's own default)
## keeps it in State.IDLE forever, so it never reaches APPROACH/TELLING and
## never touches the tell path at all; HP 3 is the only thing this overrides.

const HP: int = 3


func max_hp() -> int:
	return HP


func register_name() -> String:
	return "passive"
