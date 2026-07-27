# erdetflerspiller

A multiplayer mod for **erdetspill** — play the whole game co-op with up to
**4 players** over Steam.

Works best with 2 players. It supports 4, but the more people in a lobby the
more likely you are to hit something rough.

> [!WARNING]
> This is an unofficial fan-made modification. It is not affiliated with or
> endorsed by the original developers of **erdetspill**. Use at your own risk,
> and always back up your original game files (see below).

---

## What multiplayer gives you

Everyone runs their own full copy of the game and shares one world. The host
is the authority: they own the party's progress and simulate the enemies.

**Shared by the whole party**

- Money and inventory
- Quests — active, completed and failed
- Story flags, dead NPCs, collectibles
- Weapons the party has found — if one of you picks up the rifle, everyone
  can use it (it won't be yanked out of your hands)

**Yours alone**

- Your ammo, both magazine and reserve
- Which weapon you currently have equipped
- Health, camera and controls
- Settings: volume, mouse sensitivity, video

You'll see the other players walking around as proper characters with their
name above their head, holding whatever weapon they've got out — and yes,
they can see you flip them off.

---

## Installation

The mod replaces the game's compiled data file (`.pck`). Follow the steps
carefully — **everyone who wants to play together needs the same version of
the mod installed.**

### 1. Find your game files

1. Open **Steam** and go to your **Library**.
2. Right-click **erdetspill** → **Properties**.
3. Open the **Installed Files** tab.
4. Click **Browse...** to open the game's install folder.

### 2. Back up the original `.pck`

In the game folder, find the `.pck` file — it shares its name with the game's
executable, e.g. `erdetspill.pck`.

**Rename** it rather than deleting it:

```
erdetspill.pck  →  erdetspill_original.pck
```

That keeps a backup so you can always go back to the vanilla game.

### 3. Install the mod

1. Download the modded `.pck` from the [Releases](https://github.com/IkkeElias1/erdetflerspiller/releases) page.
2. Copy it into the same game folder.
3. Rename it to match what the game expects (`erdetspill.pck`).
4. Launch through Steam as normal.

### 4. Going back to vanilla

1. Delete (or move) the modded `.pck`.
2. Rename `erdetspill_original.pck` back to `erdetspill.pck`.

---

## How to play together

Multiplayer runs on Steam, so **both players need the game running through
Steam** and need to be Steam friends to use invites.

### Hosting

1. On the title screen, choose **FLERSPILLER**.
2. Type your **name** and pick your **figur** (character) — you'll see a
   preview of the body everyone else will see. Both are remembered for next
   time.
3. Press **VÆR VERT** to open a lobby.
4. Invite people with **INVITER VENN (STEAM)**, or press **KOPIER** to copy
   the Lobby-ID and send it to them however you like.
5. Once they show up in the player list, press **START SPILLET**.

### Joining

Any of these work:

- **Accept a Steam invite.** The game opens the multiplayer menu and connects
  on its own — this works whether the game is already running or closed.
- **Click "Join Game"** on your friend's Steam profile.
- **Paste the Lobby-ID** into the field in the FLERSPILLER menu and press
  **BLI MED**.

Set your name and character before joining — same panel as the host uses.

### While you're playing

- You can join a game that's already in progress. You'll arrive with the
  party's current money, inventory and quests.
- **Esc** opens the pause menu. In multiplayer this does *not* pause the
  world — your friends keep playing — so it only frees your mouse.
- **FORLAT ØKTEN** in the pause menu leaves the session and returns you to the
  title screen.
- If the host leaves, everyone else is returned to the title screen with an
  explanation rather than being left in a broken world.

---

## Troubleshooting

**"Steam er ikke tilgjengelig"**
Steam isn't running, or the game wasn't launched through Steam. Multiplayer
needs the Steam client; there's no direct-IP option.

**My friend can't join / I can't see their lobby**
Lobbies are **friends-only**. Make sure you're Steam friends, and that you
both installed the *same* version of the mod.

**Everyone looks fine but nothing else works right**
Mismatched mod versions between players will cause strange behaviour. Confirm
you're both on the same release.

**The mod stopped working after a Steam update**
Steam will overwrite the modded `.pck` when the game updates. Reinstall the
mod — and note that a mod build targets a specific version of the game, so you
may need an updated release.

---

## Building from source

> [!IMPORTANT]
> Build with **Godot 4.6.2**. The shipped game's executable *is* the 4.6.2
> engine, and it has to be able to load the `.pck` you produce. Exporting with
> a newer Godot (4.7+) can produce a `.pck` the game refuses to load.

1. Open the project in Godot 4.6.2.
2. **Project → Export**, pick the "Windows Desktop" preset, and export.
3. Use the resulting `.pck` as described in [Installation](#installation).

Steam only initialises in exported builds — running from the editor
deliberately skips it, so you can't test multiplayer in-editor. To test
properly you need **two separate Steam accounts** (one account can't host and
join itself).

Implementation notes, the shared/local state split and known gaps are
documented in [`multiplayer/README_MULTIPLAYER.md`](multiplayer/README_MULTIPLAYER.md).

---

## Notes

- Always keep a backup of the original `.pck` before replacing it.
- A mod build targets a specific version of the game.
- Found a bug? Open an issue on the [Issues](https://github.com/IkkeElias1/erdetflerspiller/issues)
  tab.
