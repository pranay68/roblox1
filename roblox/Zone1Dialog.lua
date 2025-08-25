-- Zone1Dialog.lua
-- ModuleScript for Zone 1 (Ignisia) official dialog and reflection choices
-- Place as a ModuleScript in ReplicatedStorage named "Zone1Dialog"

local Zone1Dialog = {}

Zone1Dialog.openingCinematic = {
	{name = "Solari", text = "Whoa. Look at this little guy—still glowing after all that? …Same."},
	{name = "Solari", text = "Hey! You made it! I wasn’t sure you’d show... You don’t feel like a myth."},
	{name = "Donna", text = "The light inside you… it remembers. Even if you forgot."},
	{name = "Shauna", text = "BOOM! Did I scare you? No? Okay well, pretend I did. I have a reputation to uphold."},
	{name = "Solari", text = "Shauna thinks she’s mysterious. Really she just likes dramatic entrances."},
	{name = "Shauna", text = "Excuse you. This place needs drama... You pose."},
	{name = "Heidi", text = "Or… you breathe. Sometimes light needs quiet to be heard."},
	{name = "Donna", text = "This is Ignisia. The place where the spark first wakes up. Yours is here somewhere—waiting."},
	{name = "Solari", text = "Let’s find it. Before Shauna tries to name it something like “Sir Sizzlepuff.”"},
	{name = "Shauna", text = "Wow. That’s actually kind of amazing. I claim full naming rights."},
	{name = "Donna", text = "Follow the flicker. It knows you."},
	{name = "Solari", text = "Let’s go spark-searching. You ready?"},
}

Zone1Dialog.sparkDiscovery = {
	{name = "Heidi", text = "There it is. Do you feel it? That… pull?"},
	{name = "Shauna", text = "Wow. Usually I talk too much. But this… Yeah. This deserves silence."},
	{name = "Donna", text = "That flicker? It’s not just fire. It’s the first yes. The one you give yourself."},
	{name = "Solari", text = "It chose you. Like, actually chose you. No take-backs."},
	{name = "Donna", text = "Now that you’ve felt it... You’ll never fully forget. Even if the world tries to make you."},
}

Zone1Dialog.reflectionPrompt = "What did it feel like when your spark lit up?"

Zone1Dialog.reflectionChoices = {
	"🔥 Like something inside me finally said: \"I'm here.\"",
	"🌱 Small, but brave. Like a candle lighting in the dark.",
	"💫 Honestly? I didn’t think I had one. But… maybe I do.",
}

return Zone1Dialog