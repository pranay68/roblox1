-- asset_ids.l
-- Central place to edit asset ids and tuning values for Ignisia

local assets = {}

-- Sound asset IDs (replace with your own rbxassetid:// values)
assets.sounds = {
    ambient = "rbxassetid://18435252", -- placeholder
    crackle = "rbxassetid://18435253",
    hum = "rbxassetid://18435254",
    chime = "rbxassetid://18435255",
}

-- Animation id for kneel (optional)
assets.kneelAnimation = "rbxassetid://0"

-- Particle texture id for aura (optional)
assets.auraParticleTexture = ""

-- Tuning values
assets.tuning = {
    NEAR_RADIUS = 8,
    STILL_VEL_THRESHOLD = 1.2,
    TARGET_SECONDS = 3.5,
}

return assets


