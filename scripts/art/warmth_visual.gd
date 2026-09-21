class_name WarmthVisual
extends Polygon2D
## A placeholder room visual that responds to WarmthField (art doc §4). Every
## instance shares one ShaderMaterial and drives its own `w`/`is_brass`
## instance uniforms — this node's own `color` is the warm albedo the shader
## derives cold from. Swap-in point for real sprites/tiles: they replace the
## polygon and keep the same material and driving logic.

const ColdWarmShader := preload("res://shaders/cold_warm.gdshader")

static var _shared_material: ShaderMaterial

## Brass takes a different cold-derive path and is the only material allowed
## to show the overshoot band as emission (art doc §4.1/§4.2).
@export var is_brass: bool = false

## Placeholder-legibility role (MICH-613, throwaway — see
## docs/art/placeholder-legibility.md). Empty means this node isn't covered
## by that layer and behaves exactly as before (terrain and backdrop keep
## the derive — doc §7). When set and the layer is enabled, this node drops
## the ShaderMaterial entirely instead of driving it (doc §3 rule 3).
@export var legibility_role: String = ""


func _ready() -> void:
	if not legibility_role.is_empty() and PlaceholderLegibility.enabled:
		PlaceholderLegibility.apply(self, legibility_role)
		return
	if _shared_material == null:
		_shared_material = ShaderMaterial.new()
		_shared_material.shader = ColdWarmShader
	material = _shared_material
	set_instance_shader_parameter(&"is_brass", is_brass)
	_update_warmth()


func _process(_delta: float) -> void:
	if not legibility_role.is_empty() and PlaceholderLegibility.enabled:
		return
	_update_warmth()


func _update_warmth() -> void:
	set_instance_shader_parameter(&"w", WarmthField.warmth_at(global_position))
