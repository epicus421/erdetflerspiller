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

- **Session layer** (`multiplayer/network_manager.gd`, autoload
  `NetworkManager`): create/join a Steam lobby, invite via the Steam overlay,
  see a live player roster, and start the shared game together. A
  `world_seed` is broadcast at start so anything that needs "the same random
  result on every machine" (see streetlights below) can use it.
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
- **Polish**: name tags above remote players; a client whose host
  disconnects mid-game is dropped back to the title screen with an
  explanation instead of left in a broken state.

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
- **No in-game "leave party" button** — leaving mid-session is only wired
  up from the title screen's multiplayer panel. A host disconnecting is
  handled gracefully for clients (see Polish above); a host explicitly
  wanting to leave while already in the level has no dedicated UI yet.
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

- Exact `Steam.*` lobby method names in `network_manager.gd`
  (`createLobby`, `joinLobby`, `getLobbyOwner`, etc.) and
  `SteamMultiplayerPeer.create_host`/`create_client` signatures.
- Whether `MultiplayerSynchronizer`/`SceneReplicationConfig` property
  setters (used for `HealthComponent.current_health`/`is_dead`) actually
  invoke a GDScript-defined `set()` accessor when a replicated value
  arrives, the way plain property writes do.

Both are one-line-ish fixes if slightly off — Godot's in-editor "Search
Help" for the `Steam` class covers the first; a fallback for the second
would be re-adding an explicit signal-emit/replay path like
`GameManager`'s, if the property-setter trick doesn't fire as expected.
