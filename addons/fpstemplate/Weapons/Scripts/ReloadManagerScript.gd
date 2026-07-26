extends Node3D

var reloadTime: float
var startReloadTimer: bool = false
var currentPartIndex: int
var playSoundAndAnim: bool
var forceReloadStop: bool = false

var cW
@onready var weaponManager: Node3D = %WeaponManager

func getCurrentWeapon(currentWeapon):
	cW = currentWeapon

func _process(delta: float) -> void :
	if cW == null:
		return
	if not is_instance_valid(cW):
		return
	if cW.isReloading and startReloadTimer and !forceReloadStop:
		reloadFollow(delta)
	elif forceReloadStop:
		if not is_instance_valid(cW):
			return
		cW.isReloading = false
		startReloadTimer = false
		if weaponManager != null and weaponManager.has_method("reset_current_weapon_mesh_visibility"):
			weaponManager.reset_current_weapon_mesh_visibility()
		return

func reload() -> void :
	if cW == null or not is_instance_valid(cW):
		return
	reloadStart()

func reloadStart() -> void :
	if cW == null or not is_instance_valid(cW):
		return
	if weaponManager == null or weaponManager.ammoManager == null:
		return
	if cW.hasToReload:
		if ( !cW.isReloading and \
\
		weaponManager.ammoManager.ammoDict[cW.ammoType] >= cW.nbProjShotsAtSameTime and \
\
		cW.totalAmmoInMag != cW.totalAmmoInMagRef and \
		!cW.isShooting):
			cW.isReloading = true




			if (cW.totalAmmoInMagRef % cW.nbPartsNeeded) != 0:
				push_error("The number of parts set is not correct, cannot insert %d of ammunition" % int(cW.nbPartsNeeded / cW.totalAmmoInMagRef))
				cW.isReloading = false
			else:
				currentPartIndex = 0
				reloadTime = cW.reloadTimePerPart
				forceReloadStop = false
				playSoundAndAnim = true
				startReloadTimer = true


func reloadFollow(delta: float) -> void :
	if cW == null or not is_instance_valid(cW):
		startReloadTimer = false
		return
	if not cW.isReloading:
		startReloadTimer = false
		if weaponManager != null and weaponManager.has_method("reset_current_weapon_mesh_visibility"):
			weaponManager.reset_current_weapon_mesh_visibility()
		return
	if playSoundAndAnim:
		playSoundAndAnim = false
		if not cW.isReloading:
			return
		if weaponManager != null:
			weaponManager.weaponSoundManagement(cW.reloadSound, cW.reloadSoundSpeed)

		if cW.shootAnimName != "":
			if not cW.isReloading:
				return
			if weaponManager != null and weaponManager.animManager != null:
				weaponManager.animManager.playAnimation("ReloadAnim%s" % cW.weaponName, cW.reloadAnimSpeed, true)
		else:
			print("%s doesn't have a reload animation" % cW.weaponName)

	if reloadTime > 0.0: reloadTime -= delta
	else:
		if currentPartIndex < cW.nbPartsNeeded:
			if cW.nbPartsNeeded == 1:
				onePartReloadCalculus()
			else:
				multiPartReloadCalculus()

			currentPartIndex += 1

			if currentPartIndex < cW.nbPartsNeeded:
				reloadTime = cW.reloadTimePerPart
				playSoundAndAnim = true
			else:
				cW.isReloading = false
				if weaponManager != null and weaponManager.has_method("reset_current_weapon_mesh_visibility"):
					weaponManager.reset_current_weapon_mesh_visibility()
		else:
			cW.isReloading = false
			if weaponManager != null and weaponManager.has_method("reset_current_weapon_mesh_visibility"):
				weaponManager.reset_current_weapon_mesh_visibility()

func onePartReloadCalculus():
	if cW == null or not is_instance_valid(cW):
		return
	if weaponManager == null or weaponManager.ammoManager == null:
		return



	var nbnbAmmoToRefill: int = min(cW.totalAmmoInMagRef - cW.totalAmmoInMag, weaponManager.ammoManager.ammoDict[cW.ammoType])

	if nbnbAmmoToRefill <= cW.totalAmmoInMagRef and nbnbAmmoToRefill >= cW.nbProjShotsAtSameTime:

		cW.totalAmmoInMag += nbnbAmmoToRefill
		weaponManager.ammoManager.ammoDict[cW.ammoType] -= nbnbAmmoToRefill

func multiPartReloadCalculus():
	if cW == null or not is_instance_valid(cW):
		return
	if weaponManager == null or weaponManager.ammoManager == null:
		return
	var nbAmmoToRefill: int = int(cW.totalAmmoInMagRef / cW.nbPartsNeeded)
	if weaponManager.ammoManager.ammoDict[cW.ammoType] >= nbAmmoToRefill and \
	cW.totalAmmoInMag <= cW.totalAmmoInMagRef - nbAmmoToRefill:

		cW.totalAmmoInMag += nbAmmoToRefill
		weaponManager.ammoManager.ammoDict[cW.ammoType] -= nbAmmoToRefill
	else:
		print("Not enough ammunition in bag, or magazine complete")
		forceReloadStop = true

func autoReload() -> void :
	if cW == null or not is_instance_valid(cW):
		return
	if weaponManager == null or weaponManager.ammoManager == null:
		return

	if cW.autoReload and !cW.isReloading and \
	weaponManager.ammoManager.ammoDict[cW.ammoType] > 0 and \
	cW.totalAmmoInMag <= 0:
		reload()
