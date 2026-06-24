# Creature Renames — à écrire dans `src/i18n/en.lua` (NAME + lore)

> 34 renommages des unités **SEVERE** (2 agents qui ont *vu* les PNG) + fixes de cohérence.
> Visuels = canon ; le nom épouse le sprite. **Re-mécanique des effets = passe ULTÉRIEURE sim-gated.**
> Ici = NAME (+ flavor/lore). **Golden-neutre** (i18n texte). `id` mécanique inchangé.

| id | → NEW NAME | lore |
|---|---|---|
| marauder | TIDEWRACK PINCER | It came up the drains when the Pit flooded, and learned everything down here is meat. |
| templar | THE GILDED VIGIL | A wheel of golden eyes that never blinks, set turning to guard what is already lost. |
| bandit | SUMP CLEAVER | Its hammer-claw cracked a man's helm like an egg, and it ate what was inside. |
| witch | THE BROODING SAC | Something warm grows in the fibre, and where its light leaks, the air turns to poison. |
| demon | LANTERN-GULLET | Its little green light is a kindness; follow it, and feed the dark behind. |
| rot_hound | CRYPT-MAGGOT | It feeds in the C of its own body, fatter the longer the corpse holds out. |
| stormcaller | STORMGLINT SHOAL | A knot of cold blue eyes adrift in a private storm; where it looks, the lightning follows. |
| plague_doctor | THE VIOLET SWARM | A crowned mass of droning wings that knits its wounds faster than any blade can open them. |
| cinder_cur | THE EMBER HIEROPHANT | Four coals for eyes and a sermon that ends in ash; its blessing is a slow, rekindling burn. |
| pyre_tender | THE KINDLING-STORK | It wades the ash-flats on stilt-legs and stoops to set a deep, patient fire in the fallen. |
| ash_moth | THE PALE WADER | A starveling of the burnt margins; the small flame it lights gutters out almost at once. |
| gash_fiend | THE GREY SLITTER | Its beak is a hooked razor; one pass opens you to the bone and leaves you limping. |
| leech_thorn | THE ANTLERED FAMINE | A stag-skulled starveling that wears back as a barb every wound it gives. |
| rot_grub | THE FOUR-MAWED CREEPER | Four necks, four heads, and a venom so patient it forgets to stop. |
| carrion_pecker | THE LONE-EYED GORGER | One pale eye, no mind behind it, and a hunger that strips a carcass to wet rags. |
| maggot_king | THE STRUNG TYRANT | It hangs from strings it cannot see, and its rot only deepens the longer the play runs. |
| soot_acolyte | THE THREE-HEADED PYRE | Three skulls share one furnace, close enough to fan a neighbour's fire hotter. |
| clot_mender | ANTLER WRAITH | It rakes the air with bone-antlers, and every wound it opens keeps weeping. |
| miasma_acolyte | THE BILE SAC | A swollen green egg-sac that vents its rot through a single weeping seam. |
| decay_tender | THE STRUNG SAINT | Hung from its own crossbar, the puppet jerks toward you on rotted strings. |
| bloodletter | DAGGERBEAK | It walks on stilt-legs and lances the marrow with a beak honed to a blade. |
| plague_bearer | THE WEEPING CHRYSALIS | A bruised purple cocoon that splits to scatter contagion on all it touches. |
| patient_worm | THE HOLLOW MARIONETTE | Long after the strings should have rotted, the wooden thing still twitches and waits. |
| blight_spreader | THE GALLOWS-HUNG | It dangles by the neck from a rope that never frays, and the rot drops with it. |
| venom_censer | THE EMBER-SAC | An ashen egg-sac that broods a coal in its belly until the shell bursts aflame. |
| live_wire | SPAWN OF EYES | A humble clutch of red eyes that twitch as one and sting where they stare. |
| static_swarm | LANTERN-GORGE | Down where no light should reach, its lure glows and its jaws wait open. |
| galvanizer | THE KNOTTED SIX | Six rats fused tail-to-tail, six gold eyes, one writhing crown of vermin. |
| dynamo_priest | THE BLUE CONGREGATION | A dark winged shape pierced through with cold blue eyes that all open at once. |
| arc_warden | THE COLD LURE | Its lantern drifts ahead like a friend; the chained jaws follow in the dark. |
| shieldbearer | PALE OPHAN | A wheel of cold eyes hovers on grey pinions, and its gaze turns blows aside. |
| aegis_warden | THE PALE STAG | A four-legged frame of bleached bone stands sentinel, antler raised, and dares the blow. |
| ward_weaver | THE GILDED THRONE | Upon wings of beaten gold sits a red-rimmed eye that mends what war has broken. |
| surge_warden | THE BEAKED COURSER | Grey-feathered and four-hoofed, it bears a cross-eyed gaze and a blade for a beak. |

## Fixes de cohérence appliqués (vs propositions brutes)
- `stormcaller` : THUNDERHEAD SHOAL → **STORMGLINT SHOAL** (l'unité `thunderhead` existe déjà).
- `plague_doctor` : THE VIOLET ROST → **THE VIOLET SWARM** (« rost » trop obscur).
- `miasma_acolyte` : BROODSAC → **THE BILE SAC** (≈ « THE BROODING SAC » de witch).
- **Famille cocon** distincte : witch=BROODING SAC · miasma=BILE SAC · plague_bearer=WEEPING CHRYSALIS · venom_censer=EMBER-SAC.

## Mild renames (agent mild) — `id | → NEW NAME | lore`
| thunderhead | THE RED CONGREGATION | A knot of red eyes wakes at once in a low private thunder, and where they fix you the air cracks. |
| skeleton | THE GREEN HUSK | A bog-swollen corpse that forgot to finish dying; strike it and it gives your blow back, bone for bone. |
| corruptor | THE DROWNED BEAK | A wine-dark leviathan that hauls itself ashore on tentacle-arms; its bite leaves the wound too foul to fight. |
| hookjaw | THE GORE-BULL | A blue-grey mountain of muscle and horn that walks you down and leaves you hamstrung in its wake. |
| necro_leech | THE HUSHED MOURNER | A small black grief that drifts the dead halls; what it touches simply rots away. |
| wildfire_hound | THE WILDFIRE FIEND | A horned thing wreathed in lava-light; where its prey burns and falls, the fire takes the next. |
| tendon_render | THE SINEW-STAG | An antlered famine of grey hide and bared rib; the more you bleed, the worse you limp. |
| ash_maw | THE VIOLET PYRE | A robed dark crowned with cold eyes; while it stands, your fires never gutter out. |
| plague_pyre | THE VIOLET CONTAGION | The same hooded dark, but when its fire leaps from the dying it sows a sickness in the living. |
| slow_bleed | THE GAUNT VERDICT | An antlered judge of bone and bared rib; at the first glance the whole field begins to give way. |
| marrow_drinker | THE COLD COMMUNION | A black grief with a sigil cupped in its hand; it drinks your blood and gives back only rot. |
| pit_maw | THE PIT'S FIRSTBORN | A maggot grown vast in the dark, curled around its own hunger; the rot it carries creeps over all near. |
| wither_bloom | THE WITHERING GAZE | A wheel of red eyes set in a hole in the world; under its look you slow, you weaken, you rot away. |
| stormlord | THE STORMSPIRE | A geode of violet glass that hums before it bites; mark a foe and every blow lands the heavier. |
| bulwark_acolyte | WARDSTONE SENTINEL | A slab of runed grey stone wakes with a cold blue light, and sets a guard over those beside it. |
| siege_breaker | WALLBITER | A lean grey wolf bred to find the seam in any shield-wall and tear it open for the pack. |
| footman | THE STOKED HUSK | A riveted shell of a soldier with a furnace where its heart should be; the line never cools. |

**KEEP (nom inchangé, sprite OK)** : emberling, razorkin, bile_spitter, kiln_warden, hollow_gut, storm_anchor, barrier_savant, mirror_ward, byakhee, oath_keeper (+ tous les « none » du tableau).

## ⚠️ 17 unités SANS clé i18n (dans U.order + U.pool) — AJOUTER name + passive_name + passive_desc
Rendues via un FALLBACK aujourd'hui (id→« LIVE WIRE »). passive_desc à dériver des `effects` (units.lua), style existant.
`live_wire`(SPAWN OF EYES), `static_swarm`(LANTERN-GORGE), `galvanizer`(THE KNOTTED SIX), `dynamo_priest`(THE BLUE CONGREGATION), `arc_warden`(THE COLD LURE), `shieldbearer`(PALE OPHAN), `aegis_warden`(THE PALE STAG), `ward_weaver`(THE GILDED THRONE), `surge_warden`(THE BEAKED COURSER), `thunderhead`(THE RED CONGREGATION), `stormlord`(THE STORMSPIRE), `storm_anchor`(STORM ANCHOR=keep), `bulwark_acolyte`(WARDSTONE SENTINEL), `barrier_savant`(BARRIER SAVANT=keep), `mirror_ward`(MIRROR WARD=keep), `siege_breaker`(WALLBITER), `oath_keeper`(OATH KEEPER=keep).

## Collisions d'archetype (familles assumées) — à arbitrer au réveil si gênant
3 herons (Kindling-Stork/Pale Wader/Grey Slitter + Daggerbeak), marionnettes (Strung Tyrant/Strung Saint/Hollow Marionette), cocons (Brooding/Bile Sac + Weeping Chrysalis + Ember-Sac), eye-wheels (Gilded Vigil/Pale Ophan/Gilded Throne), anglerfish (Lantern-Gullet/Lantern-Gorge/Cold Lure), eye-clusters shock (Stormglint Shoal/Red & Blue Congregation/Spawn of Eyes), wendigos (Antlered Famine/Antler Wraith/Sinew-Stag/Gaunt Verdict), shades (Hushed Mourner/Cold Communion).
