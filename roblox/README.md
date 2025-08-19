Ignisia (Zone 1) - Setup Guide
=================================

Files in this folder are ready-to-paste scripts for Roblox Studio to implement "Ignisia" (Zone 1) — cinematic, patience-based spark interaction, ignition milestone, persistent aura buff, reflection UI, and audio/particle feedback.

What to do in Roblox Studio
1. Open your place in Roblox Studio.
2. In Explorer create the following objects (or use the names below if you want the scripts to auto-find them):
   - Workspace > Part named `Spark` (Anchored = true). Position it where you want the ember.
   - Spark > add a `PointLight` and a `ParticleEmitter` for embers (optional, scripts will adjust properties if present).
   - Under `ReplicatedStorage` create two `RemoteEvent`s named `SparkEvent` and `IgnisiaEffectEvent` (server and client communicate through these).

3. Copy `SparkServer.lua` into `ServerScriptService` as a Script.
4. Copy `SparkClient.lua` into `StarterPlayer > StarterPlayerScripts` as a LocalScript.
5. Edit `asset_ids.lua` values (placeholder IDs) to point to your chosen sound/animation/texture asset ids.

How it works (summary)
- `SparkClient.lua` runs on each player, creates UI if missing, plays the cinematic (first spawn), monitors proximity and stillness at the `Spark` part, updates the patience meter, opens the reflection UI on success and then fires `SparkEvent` to the server.
- `SparkServer.lua` receives the ignite event, marks the player with persistent values (`HasSpark`, `ReflectionChoice`) and attaches aura particles to the player's character.
- `IgnisiaEffectEvent` can be used by the server to broadcast visual/sound effects on ignite to all clients.

Polished GUI + Installer
- The included `IgnisiaInstaller.lua` now auto-creates a polished `IgnisiaUI` (if missing) with `UICorner` and `UIGradient` elements and three styled reflection buttons. It also creates a `ProximityPrompt` on the `Spark` and wires a kneel animation (if set in `IgnisiaAssets`).

Testing steps (detailed)
1. Open your place in Roblox Studio.
2. Run `IgnisiaInstaller.lua` from the Command Bar or by pasting it into a Script in Studio and running it (it only runs in Studio).
3. Confirm `ReplicatedStorage` contains `IgnisiaAssets`, `SparkEvent`, and `IgnisiaEffectEvent`.
4. Confirm `ServerScriptService` has `SparkServer` and `StarterPlayer > StarterPlayerScripts` has `SparkClient`.
5. Press Play (Play Solo). On first spawn you should see the cinematic, NPC lines, and a visible `Spark` part with a ProximityPrompt.
6. Approach the spark, trigger the prompt to kneel, stand still within range until the patience bar fills, choose a reflection option. Your `Player` folder in Explorer should now have `HasSpark` and `ReflectionChoice` values and you should see a temporary ignite VFX plus a persistent aura on your character.

Polish options I added in this update:
- Aura color changes by data-driven values (already added server-side based on reflection choice).
- Advanced VFX implemented client-side: light pulsing on the spark, temporary `BloomEffect` on the camera, and a screen-space vignette overlay.
- UI assets: `IgnisiaAssets` now includes `ui.vignetteImage` placeholder; replace with a bespoke radial vignette PNG for best results.
- Installer stub: `IgnisiaInstaller.lua` writes a plugin stub to `ServerStorage` (`IgnisiaPluginStub`) to help convert to a real Studio plugin.

Notes about the plugin stub:
- Roblox Studio requires packaging plugin files via the Studio UI (Plugins tab → Save as Local Plugin). The provided stub is a convenience; to make a true one-click plugin, copy the pluginSource contents into a plugin script and save it from Studio.

Tuning
- `NEAR_RADIUS`, `STILL_VEL_THRESHOLD`, and `TARGET_SECONDS` in the client script control how patient the player must be.
- Particle/sound intensities and rates are exposed in `asset_ids.lua` and the client script.

Zone 2 (Lensveil) quick start
- Place `Zone2Content.lua` and `Zone2Quest.lua` in `Workspace` (they will create a `Zone2` folder automatically).
- Press R in play to pulse the Reveal ability. Illusion-tagged parts and the hint mirror will glow briefly.
- Collect 3 Light Shards to spawn the LightBridge.
- Inspect mirrors in the grove; the correct mirror grants a small heal and marks completion.

Notes
- These files are plain Lua text for you to paste into Roblox Studio. Roblox's runtime does not directly read files from your filesystem; you must copy the contents into Script/LocalScript instances in the Explorer.
- If you'd like, I can also produce a Studio plugin script that creates all instances automatically — tell me and I'll add it.

Files in this folder:
- `asset_ids.lua` - placeholder asset ids and tuning values
- `SparkServer.lua` - server script to place in `ServerScriptService`
- `SparkClient.lua` - LocalScript to place in `StarterPlayerScripts`
- `SaveService.lua` - Server save/load (DataStore) helper with retries
- `Metrics.lua` - lightweight server metrics/logger helper
- `Zone2Placeholder.lua` - Zone 2 NPC placeholder
- `Zone2Quest.lua` - Zone 2 simple quest (collect shards)
- `AudioManager.lua` - helper module for spatial audio playback

Enjoy — paste the scripts into your place and run Play Solo to test. If anything errors in Studio, copy the error message here and I'll patch the scripts.


