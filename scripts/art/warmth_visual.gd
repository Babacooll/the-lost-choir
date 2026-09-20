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


func _ready() -> void:
	if _shared_material == null:
		_shared_material = ShaderMaterial.new()
		_shared_material.shader = ColdWarmShader
	material = _shared_material
	set_instance_shader_parameter(&"is_brass", is_brass)
	_update_warmth()


func _process(_delta: float) -> void:
	_update_warmth()


func _update_warmth() -> void:
	set_instance_shader_parameter(&"w", WarmthField.warmth_at(global_position))
