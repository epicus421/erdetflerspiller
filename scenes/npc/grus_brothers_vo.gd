class_name GrusBrothersVO

const _VOX: = "res://assets/sfx/erdetlyd/vox/stein og steinar/"

const _GRUSE: AudioStream = preload(_VOX + "vi vil gruse oss ikke selge til oss fordi saaret.ogg")
const _DIGG_GRUS: AudioStream = preload(_VOX + "hvis du skaffer oss litt digg grus.ogg")
const _AAH_GRUS: AudioStream = preload(_VOX + "aah du fikk kjopt grus.ogg")
const _HER_CAPS: AudioStream = preload(_VOX + "her har du caps.ogg")
const _JA_KRIS: AudioStream = preload(_VOX + "ja vi har capsen til kris.ogg")
const _VIL_BLI_GRUSA: AudioStream = preload(_VOX + "vi vil bli grusa.ogg")
const _INGEN_GRUS: AudioStream = preload(_VOX + "ingen grus ingen caps.ogg")
const _GATED_STEINAR: AudioStream = preload(_VOX + "er det galt aa gaa med caps.ogg")
const _GATED_STEIN: AudioStream = preload(_VOX + "sjekk ut den fete capsen til steinar a.ogg")
const _KOM_TILBAKE: AudioStream = preload(_VOX + "kom tilbake senere.ogg")
const _DU_MANGLER: AudioStream = preload(_VOX + "du mangler fortsatt noe.ogg")
const _LEVER_GRUS: AudioStream = preload(_VOX + "lever grusen til steinar.ogg")
const _STEINAR_BESTEMMER: AudioStream = preload(_VOX + "steinar bestemmer.ogg")
const _GRUS_IDLE: AudioStream = preload(_VOX + "grus.ogg")


static func steinar_sounds() -> Dictionary:
	return {
		"STEINAR_GRUS": [_GRUSE, _DIGG_GRUS], 
		"STEINAR_GRUS_COMPLETE": [_AAH_GRUS, _HER_CAPS], 
		"KRIS_LUA_HINT": [_JA_KRIS, _GRUSE, _DIGG_GRUS], 
		"IDLE": [_VIL_BLI_GRUSA, _INGEN_GRUS], 
		"GATED_PRE_BANK": [_GATED_STEINAR], 
		"BLOCKED_PREREQ": [null], 
		"BLOCKED_TURN_IN": [_DU_MANGLER], 
	}


static func stein_sounds() -> Dictionary:
	return {
		"KRIS_LUA_HINT": [_JA_KRIS, _GRUSE, _DIGG_GRUS], 
		"STEINAR_GRUS_STEIN": [_LEVER_GRUS], 
		"IDLE": [_STEINAR_BESTEMMER, _GRUS_IDLE], 
		"GATED_PRE_BANK": [_GATED_STEIN], 
		"BLOCKED_PREREQ": [_KOM_TILBAKE], 
		"BLOCKED_TURN_IN": [_DU_MANGLER], 
	}
