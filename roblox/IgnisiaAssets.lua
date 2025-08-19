-- IgnisiaAssets (ModuleScript)
-- Put this ModuleScript in ReplicatedStorage and rename to IgnisiaAssets

local assets = {}

-- NOTE: These are placeholder IDs and suggestions. Replace any empty string or placeholder
-- with a Marketplace asset id you own or that is free-to-use. See README for curated
-- suggestions and links to the Creator Marketplace.

assets.sounds = {
    -- ambient background (soft wind / ember ambience)
    ambient = "rbxassetid://451776625",
    -- crackling ember/fire
    crackle = "rbxassetid://705787045",
    -- low hum / heartbeat bass used when steady
    hum = "rbxassetid://171186876",
    -- small magical chime used on ignition
    chime = "rbxassetid://180204501",
}

-- Kneel animation: put a valid AnimationId here (rbxassetid://12345)
assets.kneelAnimation = "rbxassetid://71201518567477"

-- Optional particle texture for aura (image id)
assets.auraParticleTexture = ""

-- UI asset placeholders (replace with your own decal IDs)
assets.ui = {
    vignetteImage = "rbxassetid://3570695787", -- default transparent placeholder; replace with radial vignette
    reflectionButtonIcon = "rbxassetid://3570695787",
}

-- Graphic quality presets
assets.graphics = {
    particleMultiplier = 1.0, -- multiply particle rates for low-end devices
    enableBloom = true,
    enableVignette = true,
}

-- Default graphics asset values for the client to reference (kept in ReplicatedStorage)
assets.defaults = {
    particleMultiplier = 1.0,
}

-- profiler settings (client will report usage)
assets.profiler = {
    enabled = true,
    sampleInterval = 10,
}

-- optional: multiple reflection button icons (prefer these if present). Provide as table of 3 ids.
assets.ui.reflectionButtonIcons = { "rbxassetid://3570695787", "rbxassetid://3570695787", "rbxassetid://3570695787" }

-- NPC decal mapping (name -> rbxassetid://ID). Fill these with the uploaded decal ids.
assets.npcDecals = {
    Alex = "",
    Alexis = "",
    Emerson = "",
    Donna = "",
    Tripp = "",
    Trace = "",
    Heather = "",
    Shawna = "",
    Skylar = "",
    Brad = "",
    Maggie = "",
    Heidi = "",
}

-- Tuning values you can tweak for feel
assets.tuning = {
    NEAR_RADIUS = 8,
    STILL_VEL_THRESHOLD = 1.2,
    TARGET_SECONDS = 3.5,
}

return assets


