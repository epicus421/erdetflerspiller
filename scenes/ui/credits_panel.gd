extends Control

signal back_pressed

@onready var back_button: Button = $BackButton


func _ready() -> void :
	back_button.pressed.connect(_on_back_pressed)


func _on_back_pressed() -> void :
	visible = false
	back_pressed.emit()
