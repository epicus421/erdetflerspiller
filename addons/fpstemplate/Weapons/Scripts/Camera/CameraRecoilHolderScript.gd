extends Node3D


var currentRotation: Vector3
var targetRotation: Vector3
var baseRotationSpeed: float
var targetRotationSpeed: float

func _process(delta):
	handleRecoil(delta)

func handleRecoil(delta):


	targetRotation = lerp(targetRotation, Vector3.ZERO, baseRotationSpeed * delta)
	currentRotation = lerp(currentRotation, targetRotation, targetRotationSpeed * delta)

	rotation = currentRotation

func setRecoilValues(baseRotSpeed: float, targRotSpeed: int):
	baseRotationSpeed = baseRotSpeed
	targetRotationSpeed = targRotSpeed

func addRecoil(recoilValue):
	targetRotation += Vector3(recoilValue.x, randf_range( - recoilValue.y, recoilValue.y), randf_range( - recoilValue.z, recoilValue.z))
