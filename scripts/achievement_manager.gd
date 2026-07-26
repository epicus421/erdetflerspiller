extends Node



const ACH_START: = "ACH_START"
const ACH_GRANDPA: = "ACH_GRANDPA"
const ACH_COMPLETE_EP1: = "ACH_COMPLETE_EP1"
const ACH_KILL_RABBIT: = "ACH_KILL_RABBIT"
const ACH_VINDKAST: = "ACH_VINDKAST"
const ACH_UNDERAGE_ID: = "ACH_UNDERAGE_ID"
const ACH_BUY_KEFIR: = "ACH_BUY_KEFIR"

const ACH_PAGES: = "ACH_PAGES"
const ACH_FANOFFANS: = "ACH_FANOFFANS"
const ACH_MOWERDEST: = "ACH_MOWERDEST"
const ACH_MOWERDEST_MOOSE: = "ACH_MOWERDEST_MOOSE"

const ACH_GJOK: = "ACH_GJOK"
const ACH_KILLED_BY_CROW: = "ACH_KILLED_BY_CROW"
const ACH_KILLED_BY_MOOSE: = "ACH_KILLED_BY_MOOSE"
const ACH_KILLED_BY_RPGMOOSE: = "ACH_KILLED_BY_RPGMOOSE"
const ACH_DONT_STEAL: = "ACH_DONT_STEAL"
const ACH_ESCAPE_GORGON: = "ACH_ESCAPE_GORGON"
const ACH_GETCAUGHT_GORGON: = "ACH_GETCAUGHT_GORGON"
const ACH_LISTEN_SONG: = "ACH_LISTEN_SONG"
const ACH_RUNDOWN_50_PEDS: = "ACH_RUNDOWN_50_PEDS"
const ACH_FISH: = "ACH_FISH"
const ACH_GRUS: = "ACH_GRUS"
const ACH_TIRE: = "ACH_TIRE"
const ACH_BUY_ICECREAM: = "ACH_BUY_ICECREAM"
const ACH_LIMONADE: = "ACH_LIMONADE"

const ACH_FLIPOFF_KASSEDAMA: = "ACH_FLIPOFF_KASSEDAMA"
const ACH_FLIPOFF_IVER: = "ACH_FLIPOFF_IVER"
const ACH_FLIPOFF_BESTEFAR: = "ACH_FLIPOFF_BESTEFAR"
const ACH_FLIPOFF_HVERDAGSKOMIKER: = "ACH_FLIPOFF_HVERDAGSKOMIKER"
const ACH_FLIPOFF_LAANEKASSA: = "ACH_FLIPOFF_LAANEKASSA"
const ACH_FLIPOFF_COMPLETIONIST: = "ACH_FLIPOFF_COMPLETIONIST"


const FLIPOFF_ACHIEVEMENTS: = {
	"kassedama": ACH_FLIPOFF_KASSEDAMA, 
	"iver": ACH_FLIPOFF_IVER, 
	"grandpa": ACH_FLIPOFF_BESTEFAR, 
	"hverdagskomiker": ACH_FLIPOFF_HVERDAGSKOMIKER, 
	"chief_keef": ACH_FLIPOFF_LAANEKASSA, 
}

const RUNDOWN_TARGET: = 50
const STATS_PATH: = "user://ach_stats.cfg"
var _peds_rundown: int = 0



const DEATH_ACHIEVEMENTS: = {
	"moose": ACH_KILLED_BY_MOOSE, 
	"crow": ACH_KILLED_BY_CROW, 
	"moose_rpg": ACH_KILLED_BY_RPGMOOSE, 


	"security_turret": ACH_DONT_STEAL, 
}


const QUEST_ACHIEVEMENTS: = {
	"GRANDPA_REQUEST": ACH_GRANDPA, 
	"VINDKAST_PLAKATER": ACH_VINDKAST, 
	"FINAL_DELIVERY": ACH_COMPLETE_EP1, 
	"STEINAR_GRUS": ACH_GRUS, 
}


const ITEM_ACHIEVEMENTS: = {
	"kefir": ACH_BUY_KEFIR, 
	"icecream": ACH_BUY_ICECREAM, 
	"gummi": ACH_TIRE, 
}


func _ready() -> void :
	process_mode = Node.PROCESS_MODE_ALWAYS
	_load_stats()
	GameManager.quest_completed.connect(_on_quest_completed)
	GameManager.item_added.connect(_on_item_added)
	if not GameManager.steam_enabled:
		return
	await get_tree().create_timer(1.0).timeout
	unlock(ACH_START)


func _on_quest_completed(quest_id: String) -> void :
	if QUEST_ACHIEVEMENTS.has(quest_id):
		unlock(QUEST_ACHIEVEMENTS[quest_id])


func _on_item_added(item_id: String, _amount: int) -> void :
	if ITEM_ACHIEVEMENTS.has(item_id):
		unlock(ITEM_ACHIEVEMENTS[item_id])



func unlock_for_death(cause: String) -> void :
	if DEATH_ACHIEVEMENTS.has(cause):
		unlock(DEATH_ACHIEVEMENTS[cause])



func on_flipped_off(npc_id: String) -> void :
	if not FLIPOFF_ACHIEVEMENTS.has(npc_id):
		return
	unlock(FLIPOFF_ACHIEVEMENTS[npc_id])
	_check_flipoff_completionist()



func _check_flipoff_completionist() -> void :
	if not GameManager.steam_enabled:
		return
	var steam: = Engine.get_singleton("Steam")
	for a in FLIPOFF_ACHIEVEMENTS.values():
		if not steam.getAchievement(a).get("achieved", false):
			return
	unlock(ACH_FLIPOFF_COMPLETIONIST)




func on_pedestrian_rundown() -> void :
	if _peds_rundown >= RUNDOWN_TARGET:
		return
	_peds_rundown += 1
	_save_stats()
	if _peds_rundown >= RUNDOWN_TARGET:
		unlock(ACH_RUNDOWN_50_PEDS)


func _load_stats() -> void :
	var cfg: = ConfigFile.new()
	if cfg.load(STATS_PATH) == OK:
		_peds_rundown = int(cfg.get_value("stats", "peds_rundown", 0))


func _save_stats() -> void :
	var cfg: = ConfigFile.new()
	cfg.load(STATS_PATH)
	cfg.set_value("stats", "peds_rundown", _peds_rundown)
	cfg.save(STATS_PATH)


func unlock(id: String) -> void :
	if not GameManager.steam_enabled:
		return
	var steam: = Engine.get_singleton("Steam")
	var data: Dictionary = steam.getAchievement(id)
	if data.get("achieved", false):
		return
	steam.setAchievement(id)
	steam.storeStats()
	print("[Achievements] Unlocked: %s" % id)
