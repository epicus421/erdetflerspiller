extends CanvasLayer

@onready var currStateLabelText = %CurrStateLabelText
@onready var currDirLabelText = %CurrDirectionLabelText
@onready var desiredMoveSpeedLabelText = %DesiredMoveSpeedLabelText
@onready var velocityLabelText = %VelocityLabelText
@onready var nbJumpsInAirAllowedLabelText = %NbJumpsInAirAllowedLabelText

@onready var ammo_label: Label = $WeaponsInfos / AmmoLabel


func displayCurrentState(currState: String):
	currStateLabelText.set_text(str(currState))

func displayCurrentDirection(currDir: Vector3):
	currDirLabelText.set_text(str(currDir))

func displayDesiredMoveSpeed(desMoveSpeed: float):
	desiredMoveSpeedLabelText.set_text(str(desMoveSpeed))

func displayVelocity(vel: float):
	velocityLabelText.set_text(str(vel))

func displayNbJumpsInAirAllowed(nbJumpsInAirAllowed: int):
	nbJumpsInAirAllowedLabelText.set_text(str(nbJumpsInAirAllowed))


func displayAmmo(mag: int, reserve: int) -> void :
	if ammo_label:
		ammo_label.text = str(mag) + " / " + str(reserve)
