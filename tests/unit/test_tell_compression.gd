extends GutTest
## §5 shared rule 3's repeat-compression table, checked to the millisecond
## for both enemies — this is one of the load-bearing numbers the issue
## brief calls out for full re-derivation.
##
## | Tell # | 1 | 2 | 3 | 4 | 5 | 6 | 7+ |
## | Reed Husk    | 520 | 520 | 458 | 420 | 420 | 420 | 420 |
## | Keening Husk | 700 | 700 | 616 | 542 | 477 | 420 | 420 |

const ReedHusk = preload("res://scripts/enemies/reed_husk.gd")
const KeeningHusk = preload("res://scripts/enemies/keening_husk.gd")

var _reed
var _keening


func before_each() -> void:
	_reed = ReedHusk.new()
	add_child_autofree(_reed)
	_keening = KeeningHusk.new()
	add_child_autofree(_keening)


func test_reed_husk_compression_table() -> void:
	var expected := [520.0, 520.0, 458.0, 420.0, 420.0, 420.0, 420.0]
	for i in range(expected.size()):
		var lead: float = _reed._next_lead_time_ms()
		assert_eq(lead, expected[i], "Reed Husk tell #%d" % (i + 1))


func test_keening_husk_compression_table() -> void:
	var expected := [700.0, 700.0, 616.0, 542.0, 477.0, 420.0, 420.0]
	for i in range(expected.size()):
		var lead: float = _keening._next_lead_time_ms()
		assert_eq(lead, expected[i], "Keening Husk tell #%d" % (i + 1))


func test_counter_is_per_instance() -> void:
	# "The counter is per enemy instance, not per encounter": a second Reed
	# Husk's first tell is still at base lead, regardless of how many tells
	# the first one has already played.
	for i in range(5):
		_reed._next_lead_time_ms()

	var second_reed := ReedHusk.new()
	add_child_autofree(second_reed)
	assert_eq(second_reed._next_lead_time_ms(), 520.0,
		"a second instance's first tell must be at base lead")


func test_counter_resets_after_6s_out_of_combat() -> void:
	for i in range(4):
		_reed._next_lead_time_ms()
	assert_eq(_reed._tell_count, 4)

	_reed._tick_tell_reset_timer(6000.1)
	assert_eq(_reed._tell_count, 0, "6s+ since the last tell should reset the counter")
	assert_eq(_reed._next_lead_time_ms(), 520.0, "the next tell after a reset is at base lead again")


func test_counter_does_not_reset_before_6s() -> void:
	for i in range(4):
		_reed._next_lead_time_ms()

	_reed._tick_tell_reset_timer(5999.0)
	assert_eq(_reed._tell_count, 4, "must not reset a moment before the 6s threshold")
