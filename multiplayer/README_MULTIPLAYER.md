# erdetspill — Multiplayer mod

Adds Steam P2P co-op on top of the single-player game. Every hook is gated so
that with no active session, the game behaves exactly like vanilla
single-player (`NetworkManager.is_active` is `false` and every multiplayer
code path short-circuits to the original solo behavior).

**Design**: host-authoritative. Peer 1 (the host) owns all shared party state
(money, inventory, quests, story flags — see below) and simulates enemy AI;
each player owns their own body (input/camera/health). Built entirely on
Godot's built-in high-level multiplayer (`multiplayer.multiplayer_peer`,
`@rpc`, `MultiplayerSynchronizer`, `MultiplayerSpawner`) running over
`SteamMultiplayerPeer`, which is bundled in the vendored GodotSteam 4.20
build — no extra addon needed.

## What's implemented

- **Lobby identity** (`multiplayer/player_appearance.gd`, the profile section
  of `scenes/ui/multiplayer_menu.gd`): you type a name and pick a character
  **before** hosting or joining, with a live rotating 3D preview of the body
  other players will see. Both are saved to the settings file (section
  `[multiplayer]`), default to your Steam persona name, and can still be
  changed while sitting in the lobby. The chosen name is written to
  `GameManager.player_name`, so it's the name the postkasse, ID card and
  scholarship form use too — it's a real in-game name, not just a label. The
  host reassigns duplicate characters so no two players wear the same body.
- **Player bodies are actual characters** (`multiplayer/player_avatar.gd`).
  `PlayerCharacterScene`'s only body is a bare `CapsuleMesh` on render layer 2
  — it exists so the local player casts a shadow without seeing themselves,
  and it is why everyone looked like a bean. Remote players now get one of the
  PSX character models the game already uses for its NPCs, normalised to the
  same height/orientation `npc_base.gd` uses, yawed to the player's actual
  look direction (the base game rotates `CameraHolder`, not the body, so
  without this everyone faced world-north), with a crouch squash mirrored from
  the capsule and a walk bob driven by the already-replicated `velocity`. It's
  presentation-only — nothing here can desync the simulation — and it falls
  back to the capsule if the models are missing from a build.
- **Steam invites actually work** (`_check_launch_invite`, `_handle_invite`,
  `invite_received`). Accepting an invite used to call `join_lobby()` behind a
  closed menu, so it looked like nothing happened; accepting one with the game
  closed did nothing at all. Now: `+connect_lobby` on the command line (and
  `getLaunchCommandLine()`) is parsed at boot, an invite received in-game
  drops the session and returns to the title screen, and either way the title
  screen opens the multiplayer panel and *then* connects, so the status
  messages are visible.
- **Session layer** (`multiplayer/network_manager.gd`, autoload
  `NetworkManager`): create/join a Steam lobby, invite via the Steam overlay,
  see a live player roster, and start the shared game together. A
  `world_seed` is broadcast at start so anything that needs "the same random
  result on every machine" (see streetlights below) can use it.
- **What is shared vs. what is yours.** The dividing line is *party progress*
  versus *the state of one body*:

  | Shared across the party | Local to each player |
  | --- | --- |
  | Money, inventory | Reserve ammo (`AmmunitionManager.ammoDict`) |
  | Quests (active/completed/failed) | Magazine ammo (`WeaponResource.totalAmmoInMag`) |
  | Story flags, dead NPCs, collectibles | Which weapon you have equipped (`weaponIndex`) |
  | **Which weapons the party has found** (`GameManager.unlocked_weapons`) | Health, camera, input |
  | Freezer stock, bank payouts, ID card | Settings (volume, sensitivity, video) |

  Picking a gun off the floor unlocks it for everyone — but it does **not**
  yank it into their hands, and it does not hand them your bullets. New
  weapons arrive via `acquire_weapon_by_id(id, equip = false)`; the player who
  actually took it calls `take_weapon_by_id()`, which equips locally *and*
  broadcasts the unlock. A player joining mid-session picks up the party's
  existing weapons from the state snapshot.
- **Seeing what other players hold** (`player_avatar.gd` `_refresh_weapon`):
  the first-person viewmodel can't be reused for this — it lives under the
  camera on render layer 3, which only that player's own weapon SubViewport
  camera draws. So the held weapon's model is cloned onto the third-person
  avatar, forced to render layer 1 and normalised to a sensible size. The
  weapon id rides along as `.:net_weapon_id` on the player synchronizer.

  Aiming it is the interesting part. A clone with an identity transform floats
  sideways through the torso, because a viewmodel's local axes are whatever the
  artist happened to author and these PSX bodies have no rig to parent to.
  Every weapon model carries an `<Name>AttackPoint` marker at the muzzle, so
  the vector from the model's centre to that marker *is* the barrel direction;
  rotating it onto the avatar's forward aims any weapon without a hand-tuned
  per-weapon table. (The GrusSkive keeps its marker on the slot rather than the
  model, so that case is checked too.) Measured across all six weapons: barrel
  alignment `dot` 0.99–1.00 with the body's forward, world size 0.55–0.60 m.
- **Hand gestures** (`.:net_hand_gesture`): the holster "weapon" is a flat hand
  PNG in the viewmodel, which is how the game does the middle finger, peace
  sign and so on — and being on the viewmodel layer, none of it reached the
  people it was aimed at. The displayed texture is now recorded as an index
  into `PlayerAppearance.HAND_TEXTURES` and replicated; remote avatars show the
  same hand on a billboarded `Sprite3D` (so it reads from any angle), with the
  same shake the first-person hand does. It hides as soon as a real weapon is
  drawn.
- **Player replication** (`multiplayer/player_spawner.gd`,
  `multiplayer/player_net.gd`): removes the level's baked single player and
  spawns one `PlayerCharacterScene` per connected peer instead, each owned by
  that peer. Movement/velocity/camera look/crouch/FSM state sync via a
  `MultiplayerSynchronizer` built at runtime. Input, camera, HUD, and weapon
  processing are all gated to the local player
  (`PlayerCharacterScript.is_local_player()`); a remote player's body is made
  visible (it's hidden-from-self by default) and gets a floating name tag.
- **Shared party state** (`multiplayer/game_net.gd`, autoload `GameNet`):
  `GameManager` (money/inventory/quests/story flags) is patched so its ~17
  public mutators redirect to the host when called on a non-host client, and
  the host's result replays back out to everyone. A joining client also
  requests a full state snapshot so they don't start with an empty
  inventory/quest journal. Settings (volumes, sensitivity, video) stay local
  per machine, as before.
- **"Acting player" resolution** (`multiplayer/net_util.gd`
  `get_acting_player()`, wired into `GameManager.get_player()`): when the
  host is applying a client's networked request (e.g. that client used a
  healing item), game logic that means "the player who did this" resolves to
  *that* client's player, not an arbitrary one. Outside of that narrow
  window it's just the local player, so this is safe everywhere it's used —
  including the local-settings code (mouse sensitivity, render distance)
  that previously grabbed "the first PlayerCharacter in the group," which
  was a real multiplayer bug (~70 call sites had this pattern; the
  non-combat ones were swept to `NetUtil.get_local_player()` /
  `get_nearest_player()`).
- **Combat & enemies**: `components/health_component.gd` uses property
  setters for `current_health`/`is_dead` (not explicit signal emits), so
  `on_damage_taken`/`on_death` fire correctly wherever the synced value
  lands — a remote player flinching or an enemy dying looks right on every
  screen, not just the one that dealt the hit. Damage/heal/revive redirect
  to whichever peer holds authority over the entity (that player's own peer
  for their own health; the host for anything baked into the level — enemies,
  NPCs, wildlife, since those default to authority 1). Enemy AI
  (`addons/3dEnemyToolkit/Example/example_enemy.gd`, shared by moose/crow/
  melee enemies) only actually *simulates* on the host; everyone else just
  receives its replicated transform/state. Targeting uses
  `NetUtil.get_nearest_player()` instead of always chasing one arbitrary
  player. Enemy loot drops are host-gated so they aren't granted once per
  peer watching the kill.
- **World consistency**: `scripts/streetlight_manager.gd`'s poster placement
  used a per-process random shuffle (every peer would see posters on
  different streetlights) — now seeded from the shared `world_seed`.
  Freezer/shelf-spawned shop items got deterministic names so their
  NodePaths (and thus network identity) are the same on every peer.
  Carried objects (ice cream, shelf items, wood scraps, anything in the
  `Carriable` group) get a synced transform the moment a player picks them
  up, so everyone sees your friend actually carrying things — this is a
  single fix at `PlayerCharacterScript._ensure_carriable_sync()`, the one
  central place every carry interaction already went through.
- **Polish**: name tags above remote players (refreshed when the roster
  arrives, since `peer_connected` fires before a peer has said who they are);
  a client whose host disconnects mid-game is dropped back to the title screen
  with an explanation instead of left in a broken state; the pause menu grows
  a "FORLAT ØKTEN" button in a session and hides "RESTART" (a single client
  reloading the level alone would only desync itself).

## Bugs fixed in the second pass

These were real defects in the first implementation, not new features:

- **Late joiners never loaded the level.** `_begin_session_game` was
  broadcast exactly once, when the host pressed START, so anyone who joined
  afterwards sat in the lobby forever. The host now sends it to each peer as
  it connects, and a joining client requests a state snapshot *after* the
  level loads so it arrives with the party's real money/inventory/quests.
- **Bodies were spawned before the receiving peer had anywhere to put them.**
  A `MultiplayerSpawner` that spawns into a path the remote peer hasn't loaded
  yet silently drops the node. There is now a level-load handshake
  (`notify_level_ready` / `peers_in_level`): the host only spawns a body for a
  peer that has reported its `PlayerSpawnRoot` is in the tree, and re-spawns
  if that peer reloads the level.
- **Nobody ever moved: the player synchronizer was never created at all.**
  `player_net.gd` was a *node* under each player body that built the
  `MultiplayerSynchronizer` from its own `_ready()` via
  `get_parent().add_child(sync)`. Godot rejects that outright —

  ```
  ERROR: Parent node is busy setting up children, `add_child()` failed.
  ```

  — because a node is blocked while `_ready()` is being propagated through its
  children, so a child cannot add siblings to its parent at that moment. The
  call failed every time, no synchronizer existed, and no position, velocity
  or look direction ever left the machine. Every remote player stood frozen at
  their spawn point. The synchronizer is now built inside
  `player_spawner.gd`'s spawn function while the body is still detached from
  the tree, which is legal *and* means it is present at spawn time so Godot
  registers it as part of the spawn on every peer.

  Verified end-to-end with two headless Godot 4.6.2 processes over ENet, old
  pattern vs new, client-owned node:

  ```
  OldWay   sync_node=false  x= 0.00  FROZEN
  NewWay   sync_node=true   x=14.90  REPLICATES
  ```

- **Runtime `MultiplayerSynchronizer`s had the wrong authority.** `add_child()`
  does **not** copy the parent's multiplayer authority (measured: a child added
  to a parent with authority 77 comes out with authority 1), and a
  synchronizer decides who transmits when it *enters the tree* — setting the
  authority afterwards does not make it re-evaluate. So authority must be
  correct **before** `add_child`. `player_spawner.gd` now applies
  `set_multiplayer_authority(peer_id)` recursively to the whole body after the
  synchronizer is attached but before it enters the tree, and
  `health_component.gd` sets its own before adding.
- **Two synchronizers were fighting over the player's position.**
  `PlayerCharacterScene.tscn` shipped a baked `MultiplayerSynchronizer`
  replicating `.:position`/`.:rotation` on top of the runtime one; it has been
  removed.
- **Pausing froze the shared world.** `get_tree().paused = true` stops every
  `MultiplayerSynchronizer` on that machine, so one player opening the menu
  stalled everyone else's view of them and left them out of date on return.
  In a session the tree is left running and only the local body is frozen;
  gameplay input is gated on `PauseMenu.is_menu_paused()` instead.
- **Any peer could invoke any method.** `GameNet._request` and
  `HealthComponent._request` gated on `has_method()`, which let a peer make
  every other machine call *anything* on those objects. Both now use explicit
  allowlists.
- **Failed host/join left a half-open session.** A Steam lobby that failed to
  create, or a client peer that failed to connect, left `is_active = true` and
  a live `multiplayer_peer`, so the next attempt was refused with "Already in
  a session" until the game was restarted. Every failure path now tears the
  session down and leaves the Steam lobby, and `_cleanup_session` closes the
  peer rather than just dropping the reference.
- **Every player shared one set of weapons.** `WeaponResource` is a `Resource`,
  and the seven `.tres` files are exported into `PlayerCharacterScene` — so
  Godot handed *the same seven objects* to every player body in the lobby.
  Three separate symptoms fell out of that one cause:
  `weaponSlot` is assigned during `WeaponManager.initialize()`, so the last
  player to spawn won the pointer and everyone else's `cWModel` then pointed at
  **that** player's nodes (switching a weapon showed/hid the model on somebody
  else's body); `isShooting`/`isReloading` are checked by `changeWeapon()`, so
  one player reloading **froze weapon switching for the entire party**; and
  `totalAmmoInMag` was a single magazine everyone drew from.
  `initialize()` now takes a shallow `duplicate()` per player, which keeps the
  heavy assets (meshes, sounds, curves) shared but gives each body its own
  mutable fields. This was a latent single-player bug too — the cached
  originals leaked mutated ammo across playthroughs.
- **Every remote player drew their weapon viewmodel over your screen.** The
  first-person viewmodel is a full-screen `SubViewportContainer` parented to
  the player body, rendering layer 3 through its own camera. That container
  ships with *every* `PlayerCharacter`, including the ones representing other
  players, so each remote body stacked another full-screen overlay on your
  view — when a teammate switched weapons, their gun appeared on your screen.
  It also rendered a 640x480 viewport per remote player every frame for
  nothing. Remote bodies now hide it and set `UPDATE_DISABLED`.
- **Weapon pickups responded to the wrong player.** `weapon_world_pickup.gd`
  set `_player_nearby` from any `PlayerCharacter` entering its area, including
  remote bodies — so a teammate standing on a weapon armed *your* "E" key, and
  pressing it handed the gun to their manager instead of yours.
- **The roster was populated too late to be useful.** Bodies were spawned on
  `peer_connected`, before the joining peer had sent its name/character, so
  name tags read "Spiller" and everyone got character 0. Spawning now waits
  for `_submit_player_info`.

## Known gaps (by design or by budget — not oversights)

- **Minigames and dialogue are inherently per-process already.** This is a
  multi-*process* P2P architecture (each player runs their own full game),
  not split-screen — so `DialogueUI`/minigame "global" locks only ever
  affected the process they ran in to begin with. No extra per-player
  plumbing was needed once player lookups were fixed (see above).
- **`GameManager.collect_collectible()`** isn't routed through the network
  bridge — it takes a `Texture2D` resource argument, which isn't something
  the generic RPC replay can serialize. A non-host client picking up a lore
  collectible only updates their own local copy for now.
- **The Gorgon horror maze set-piece** (`scenes/minigames/gorgon_horror.gd`)
  is a personal, randomly-generated, isolate-and-teleport sequence by
  design — it's left fully per-process. If one player triggers it, only
  they experience it; their partner keeps playing normally in the shared
  world, which fits the content (a solo jump-scare interlude) rather than
  needing the whole party pulled in.
- **Checkout counters / lemonade build zone**: these should mostly work as
  a side effect of the carried-object transform sync plus each peer's own
  local `Area3D` overlap detection reacting to the now-synced positions, but
  they weren't individually built/tested the way player and enemy sync were.
  A carriable object whose node name isn't deterministic across peers
  (anything spawned with a randomized/auto-generated name, rather than
  baked into a scene or given an explicit name like the freezer/shelf fix)
  won't sync — it'll just look frozen on other peers' screens until dropped.
- **Bool-returning mutators redirected to the host** (e.g. `remove_money`,
  `add_quest_by_id`) **optimistically return `true` on the client** before
  the host has actually confirmed anything, since the real result only
  comes back asynchronously. If the host actually rejects the action
  (e.g. insufficient funds), the client's own state simply won't get the
  matching update next sync — there's no instant rejection feedback to the
  initiating client. Fine for a cooperative party that isn't adversarial
  with itself; would need a proper async round trip to fully fix.
- **Character models are static meshes, not rigged.** The PSX character set
  the game ships has no animations (its own NPCs are static too), so a remote
  player glides rather than walking. `player_avatar.gd` fakes it with a bob
  and lean; proper limb animation would need rigged models the project
  doesn't currently contain.
- **Player damage in PvP-adjacent situations** (turret, splash damage) will
  work because `take_damage()` always redirects to whoever authoritatively
  owns the target — this was verified by reasoning through the code path,
  not by running it.

## Testing (important — the editor can't do this)

`GameManager._init_steam()` skips Steam entirely when running from the
Godot editor (`OS.has_feature("editor")`), so **Steam networking only works
in exported builds**, and you need **two separate Steam identities** (two
accounts/machines — one account generally can't run two instances against
itself). Export the game, run it on both, host from one via "FLERSPILLER" →
"VÆR VERT", invite via the Steam overlay (or share the lobby ID), and
"START SPILLET" once someone's joined.

## Verify-on-first-run

I couldn't run Godot in this environment, so a few things are verified by
reading GodotSteam's source/docs and reasoning through Godot's replication
API rather than by execution — if the very first test throws an error, it's
almost certainly one of these:

- ~~Exact `Steam.*` lobby method names~~ — every symbol used here
  (`createLobby`, `joinLobby`, `getLobbyOwner`, `getLaunchCommandLine`,
  `setLobbyJoinable`, `addRequestLobbyListStringFilter`,
  `activateGameOverlayInviteDialog`, `SteamMultiplayerPeer`, `create_host`,
  `create_client`, `disconnect_peer`, `close`) was confirmed present in the
  vendored `addons/godotsteam/win64/libgodotsteam.windows.template_release.x86_64.dll`.
  Argument *order* still isn't proven by execution.
- Whether `MultiplayerSynchronizer`/`SceneReplicationConfig` property
  setters (used for `HealthComponent.current_health`/`is_dead`) actually
  invoke a GDScript-defined `set()` accessor when a replicated value
  arrives, the way plain property writes do. A fallback would be re-adding an
  explicit signal-emit/replay path like `GameManager`'s.
- The character models' import orientation. `player_avatar.gd` reuses the
  exact normalisation `scenes/npc/npc_base.gd` already applies to these same
  `.glb` files (scale to 1.95 m, yaw 180°, centre on the mesh AABB), so if
  the game's NPCs stand upright and face the right way, remote players will
  too — but the *yaw follow* (`look_at` on the flattened camera forward) has
  only been reasoned through. If bodies face backwards, flip
  `MODEL_YAW_OFFSET_DEG` from 180 to 0.
- The multiplayer panel's layout at the game's 640x480 design resolution. It
  is wrapped in a `ScrollContainer` so nothing can be clipped off-screen, but
  the exact sizes were picked by arithmetic, not by looking at it.
- **Where the third-person weapon sits on the body.** Its *aim* and *size* are
  now measured (see above), but the attachment point is still a fixed offset —
  the PSX character models have no rig, so there is no hand bone to parent to
  and the arms don't move to meet the gun. Tune `WEAPON_OFFSET`,
  `WEAPON_LENGTH`, `WEAPON_PITCH_DEG` and `HAND_OFFSET` at the top of
  `player_avatar.gd` if things float or clip. Proper hands-on-the-weapon would
  need rigged character models, which this project doesn't contain.
