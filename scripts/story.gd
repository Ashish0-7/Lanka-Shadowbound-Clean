class_name Story
extends RefCounted
## All NPC conversations and story beats.

static func talk(id: String, it: Interactable, player: PlayerChar) -> void:
	var m = Game.main
	var nm: String = Game.data["name"]
	match id:
		"banda":
			if not Game.flag("banda_met"):
				Game.set_flag("banda_met")
				await m.say([
					"OLD BANDA: Easy now, easy! You washed up with the driftwood.",
					"OLD BANDA: Don't mind the glow. I drowned off this beach the night the Great Lamp went dark.",
					"OLD BANDA: The souls who are still remembered keep a little light. The forgotten ones... became those shadows.",
					"OLD BANDA: Forty years I fished these waters, and this island was never on any chart. No star points to it.",
					"OLD BANDA: Look at those arms. You're no lost sailor. A warrior, then. Good. The night here needs one.",
					"OLD BANDA: Take my old Sun Lantern. It keeps the dark from biting so hard.",
				])
				Game.add_key_item("lantern")
				Sfx.play("pickup")
				await m.say([
					"Obtained the SUN LANTERN!",
					"OLD BANDA: There's a village north, up the path. Smoke rose from it this morning, then... nothing.",
					"OLD BANDA: Go see. And %s... I feel like I've said your name before. Strange." % nm,
					"TIP: [X] sword (tap for combos)   [Space] dash   [Q] [E] [Tab] skills   [F] talk   [Esc] menu.",
				])
			elif Game.flag("ending_seen"):
				await m.say(["OLD BANDA: The lamp burns again! I can see my village's lights across the water!", "OLD BANDA: Thank you, %s. Whoever you were before, you're a keeper now." % nm])
			elif not Game.flag("elder_met"):
				await m.say(["OLD BANDA: The village is north along the dirt path. Mind the crabs.", "OLD BANDA: Rest by any campfire to heal and save your progress."])
			elif Game.shard_count() == 0:
				await m.say(["OLD BANDA: Caves in the eastern cliffs, you say? The tide sings in there at night.", "OLD BANDA: My lantern will light the way. Go carefully."])
			elif Game.shard_count() == 1:
				await m.say(["OLD BANDA: One shard! It glows like the old lighthouse used to.", "OLD BANDA: The jungle to the northwest... the monkeys there scream like men. Be ready."])
			else:
				await m.say(["OLD BANDA: The lighthouse on the ashen cliffs. That's where it all ends, isn't it?", "OLD BANDA: Bring the light home, %s." % nm])
		"parrot":
			var lines := ["PARROT: SQUAWK! GHOST BIRD! STILL PRETTY!", "PARROT: SQUAWK! UNKNOWN! UNKNOWN!", "PARROT: SQUAWK! DON'T SAY THE NAME!", "PARROT: SQUAWK! %s CAME BACK! %s CAME BACK!" % [nm, nm], "PARROT: SQUAWK! THREE LIGHTS! THREE LIGHTS!", "PARROT: SQUAWK! WHERE IS THE MAP? NO MAP!"]
			await m.say([lines[randi() % lines.size()]])
		"elder":
			if not Game.flag("elder_met"):
				Game.set_flag("elder_met")
				await m.say([
					"A translucent figure flickers by the fire. It turns toward you.",
					"ELDER SPIRIT: ...A living one. And with a lantern. How long has it been?",
					"ELDER SPIRIT: This is Lanka-that-was. An island the sea agreed to forget.",
					"ELDER SPIRIT: Below us sleeps THE NAMELESS. It eats what is known, and leaves only what is not.",
					"ELDER SPIRIT: For three hundred years our Great Lamp held it below. Three shards of sunlight kept it burning.",
					"ELDER SPIRIT: Then corsairs came and pried the shards loose. The lamp went dark. The island fell off every map.",
					"ELDER SPIRIT: Those of us someone still remembers stayed as souls of light. The rest became the shadows you have met.",
					"ELDER SPIRIT: Forgive them, warrior. They do not know you. Calm them, and their light may return.",
				])
				var yes: bool = await m.ask("ELDER SPIRIT: Will you return the three shards to the Great Lamp?")
				if yes:
					await m.say(["ELDER SPIRIT: Then take this. We buried our treasures when the dark came. Dig where you see red marks."])
				else:
					await m.say(["ELDER SPIRIT: ...You said that last time, too. Take this anyway. Dig where you see red marks."])
				Game.add_key_item("shovel")
				Sfx.play("pickup")
				await m.say([
					"Obtained the SHOVEL!",
					"ELDER SPIRIT: The TIDE SHARD was dragged into the caverns of the eastern cliffs.",
					"ELDER SPIRIT: The GROVE SHARD is worn by a beast in the northwest jungle.",
					"ELDER SPIRIT: With two shards, the lighthouse doors will open. The last shard is where the dark is deepest.",
				])
			elif Game.shard_count() >= 2 and not Game.flag("ending_seen"):
				await m.say(["ELDER SPIRIT: I feel them... two shards. The lighthouse on the ashen heights will open for you now.", "ELDER SPIRIT: What waits below has your face. Do not let that stop you."])
			elif Game.flag("ending_seen"):
				await m.say(["ELDER SPIRIT: The lamp burns. My people are resting at last.", "ELDER SPIRIT: Lanka is on the map again, keeper. Because of you."])
			else:
				await m.say(["ELDER SPIRIT: Tide Shard: the eastern caverns. Grove Shard: the northwest jungle.", "ELDER SPIRIT: Read the bottles the sea gives you. The island remembers what we forgot."])
		"mermaid":
			if not Game.data["skills"].has("bolt"):
				await m.say([
					"MERMAID: Oh! A living face. I am only the memory of a mermaid now, but memories can still give gifts.",
					"MERMAID: The shadows hate sunlight. I kept some in my pearls, before the lamp died.",
					"MERMAID: Here. Hold out your hand. Don't flinch!",
				])
				Game.data["skills"].append("bolt")
				Sfx.play("levelup")
				await m.say(["Learned SUN BOLT! Press [E] to fire. Aims at the mouse if you're using one.", "MERMAID: Come back if you find Moon Pearls. Use them; they will make you sturdier."])
			else:
				await m.say(["MERMAID: The lagoon used to reflect the lighthouse beam every night. Now it reflects nothing.", "MERMAID: Even you, a little. Look. Your reflection is late."])
		"echo":
			if Game.shard_count() >= 1 and not Game.data["skills"].has("radiant"):
				await m.say([
					"A figure in your clothes stands with its back to you. It doesn't turn around.",
					"???: You carry a shard. It still remembers being part of something bright.",
					"???: Let it out. Burn the dark away. Show yourself what's hidden.",
				])
				Game.data["skills"].append("radiant")
				Sfx.play("radiant")
				m.flash_screen(Color(1, 0.95, 0.7, 0.8), 0.6)
				await m.say(["Learned RADIANCE! Press [Tab]. It burns shadows AND reveals unexplored land around you.", "???: We have done this before, you and I. Let's do it right this time."])
			else:
				await m.say(["A figure in your clothes stands with its back to you.", "???: Not yet. Bring light first. Then we talk."])
		"spirit_a":
			var l := ["VILLAGER SPIRIT: I am walking to the well. I have been walking to the well for a very long time.", "VILLAGER SPIRIT: The well is gone, isn't it? ...Then why can I still hear the bucket?"]
			if Game.shard_count() > 0:
				l = ["VILLAGER SPIRIT: That light in your pocket... it feels like morning.", "VILLAGER SPIRIT: I almost remember my daughter's name. Almost."]
			await m.say(l)
		"spirit_b":
			var l2 := ["FISHER SPIRIT: Nets need mending before the tide. Every night, the same nets. Every night, the same holes.", "FISHER SPIRIT: Don't go past the eastern cliffs after dark. Something in the caverns counts the waves."]
			if Game.is_opened("boss:tide_king"):
				l2 = ["FISHER SPIRIT: The waves stopped counting. Was that you?", "FISHER SPIRIT: Tonight, for the first time, my nets have no holes."]
			await m.say(l2)
		"spirit_c":
			await m.say([
				"WANDERING SPIRIT: You walk like the keeper did. Lantern low, eyes on the edges of things.",
				"WANDERING SPIRIT: The keeper went into the lighthouse with a name and came out without one.",
				"WANDERING SPIRIT: ...You should stay out of my way. I don't stop walking. I can't.",
			])
		"lamp":
			if Game.flag("ending_seen"):
				await m.say(["The Great Lamp burns steady and warm. Its beam sweeps the sea, and the sea remembers the island."])
			elif Game.shard_count() >= 3:
				await m.say(["The Great Lamp's empty cradle hums.", "You place the TIDE SHARD... the GROVE SHARD... and the EMBER SHARD."])
				m.play_ending()
			else:
				await m.say(["The cradle of the Great Lamp. Three hollows wait for three shards.", "You have %d of 3." % Game.shard_count()])
		_:
			if id.begins_with("human_"):
				await m.say(_human_lines(id))
			else:
				await m.say(["..."])

const HUMAN_TALK := [
	["ISLANDER: Oh! Hello. Sorry, I... where is this? It looks like my village, but the huts are older than I remember.", "ISLANDER: I keep reaching for a basket I'm sure I was carrying."],
	["FISHER: I was mending nets. Then it was dark. Then it was this morning. How many nights did I miss?", "FISHER: My hands smell of the sea, but my nets are gone."],
	["DANCER: My feet ache like I danced for a hundred years. I don't remember the music.", "DANCER: There's a tune stuck in my head. It sounds... like waves counting."],
	["SAILOR: Why am I holding a cutlass? I'm a ship's cook! At least... I think I am.", "SAILOR: The captain had a sack of glowing stones. I don't see the captain anywhere."],
	["ISLANDER: Have we met? You look like someone from a story my grandmother told.", "ISLANDER: The lighthouse is lit! I don't know why that makes me want to cry."],
	["WANDERER: I woke up under a palm tree with sand in my ears. I am choosing not to ask questions.", "WANDERER: If you see a red headband like yours, it might be mine. I'm joking. Probably."],
	["FISHER: There's a gap in my memory shaped like a long night.", "FISHER: Strange. I'm not afraid of the dark any more. I was terrified of it, yesterday."],
	["ISLANDER: Everyone's wandering about like sleepwalkers. Are you the one who woke us?", "ISLANDER: Thank you, warrior. Whatever it was you did."],
]

static func _human_lines(id: String) -> Array:
	var i: int = absi(hash(id)) % HUMAN_TALK.size()
	return HUMAN_TALK[i]
