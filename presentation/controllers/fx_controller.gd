class_name FxController
extends Node

var fx_layer: Node
var action_preview_layer: Node

func bind_layers(next_fx_layer: Node, next_action_preview_layer: Node) -> void:
	fx_layer = next_fx_layer
	action_preview_layer = next_action_preview_layer

func clear_all() -> void:
	if action_preview_layer != null:
		action_preview_layer.clear()
	if fx_layer != null:
		fx_layer.clear()
