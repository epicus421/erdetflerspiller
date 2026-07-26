extends Node3D

const _ItemNotification: = preload("res://scenes/ui/item_notification.gd")

@onready var ammoManager: Node3D = %AmmunitionManager
@onready var weaponManager: Node3D = %WeaponManager

func ammoRefillLink(ammoDict: Dictionary):
	for key in ammoDict.keys():
		if key in ammoManager.ammoDict:


			var nbAmmoToRefill: int = min(ammoManager.maxNbPerAmmoDict[key] - ammoManager.ammoDict[key], ammoDict[key])
			ammoManager.ammoDict[key] += nbAmmoToRefill
			if nbAmmoToRefill > 0:
				_ItemNotification.notify_ammo_pickup(get_tree(), str(key), nbAmmoToRefill)
