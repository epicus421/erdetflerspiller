extends Area3D

func _ready() -> void :
	add_to_group("Enemies")
	body_entered.connect(_on_body_entered)


func _on_body_entered(body: Node3D) -> void :
	if not (body is RigidBody3D and body.has_method("applyDamage")):
		return
	var proj_hitbox: = body.get_node_or_null("Hitbox") as CollisionShape3D
	if proj_hitbox != null and proj_hitbox.disabled:
		return
	if body.has_method("hit"):
		body.hit()
	body.applyDamage(self)


func hitscanHit(damageVal: float, _hitscanDir: Vector3, _hitscanPos: Vector3) -> void :
	_apply_damage(damageVal)


func projectileHit(damageVal: float, _projectileDir: Vector3) -> void :
	_apply_damage(damageVal)


func _apply_damage(damageVal: float) -> void :
	var hc: Node = get_parent().get_node_or_null("HealthComponent")
	if hc and hc.has_method("take_damage"):
		hc.take_damage(damageVal)
