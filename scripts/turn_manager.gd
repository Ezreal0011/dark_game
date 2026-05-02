class_name TurnManager
extends Node

var current_turn := 1
var dark_energy := 4
var max_dark_energy := 10
var energy_per_turn := 2
var wait_energy_bonus := 1
var move_cost := 1
var scan_cost := 2
var attack_cost := 3
var skill_pick_cost := 1
var black_domain_base_penalty := 2
var black_domain_penalty_per_stage := 1

func setup(config: Dictionary) -> void:
	current_turn = int(config.get("initial_turn", current_turn))
	dark_energy = int(config.get("initial_dark_energy", dark_energy))
	max_dark_energy = int(config.get("max_dark_energy", max_dark_energy))
	energy_per_turn = int(config.get("energy_per_turn", energy_per_turn))
	wait_energy_bonus = int(config.get("wait_energy_bonus", wait_energy_bonus))
	move_cost = int(config.get("move_cost", move_cost))
	scan_cost = int(config.get("scan_cost", scan_cost))
	attack_cost = int(config.get("attack_cost", attack_cost))
	skill_pick_cost = int(config.get("skill_pick_cost", skill_pick_cost))
	black_domain_base_penalty = int(config.get("black_domain_base_penalty", config.get("black_domain_energy_penalty", black_domain_base_penalty)))
	black_domain_penalty_per_stage = int(config.get("black_domain_penalty_per_stage", black_domain_penalty_per_stage))

func can_spend_dark_energy(amount: int) -> bool:
	return dark_energy >= amount

func try_spend_dark_energy(amount: int) -> bool:
	if not can_spend_dark_energy(amount):
		return false
	dark_energy -= amount
	return true

func start_new_turn() -> int:
	current_turn += 1
	var before := dark_energy
	dark_energy = min(max_dark_energy, dark_energy + energy_per_turn)
	return dark_energy - before

func apply_wait_bonus() -> int:
	var before := dark_energy
	dark_energy = min(max_dark_energy, dark_energy + wait_energy_bonus)
	return dark_energy - before

func add_dark_energy(amount: int) -> int:
	var before := dark_energy
	dark_energy = min(max_dark_energy, dark_energy + amount)
	return dark_energy - before

func get_black_domain_penalty(stage: int) -> int:
	return max(1, black_domain_base_penalty + max(0, stage - 1) * black_domain_penalty_per_stage)

func apply_black_domain_penalty(current_hp: int, stage_or_amount: int = 1, amount_override: int = -1) -> int:
	var penalty: int = amount_override if amount_override >= 0 else get_black_domain_penalty(stage_or_amount)
	var remaining: int = penalty
	var energy_loss: int = min(dark_energy, remaining)
	dark_energy -= energy_loss
	remaining -= energy_loss
	return max(0, current_hp - remaining)
