VERSION = "3.0.0-dev"

DEFAULT_OBLIQUE = [
    "La machine ne ment pas. Elle déforme.",
    "Supprime une fréquence. Laisse le silence parler.",
    "Joue comme si les circuits étaient fatigués.",
    "Le bruit est une information que tu n'as pas encore comprise.",
    "Répète jusqu'à ce que la répétition devienne quelque chose d'autre.",
    "Inverse le signal. Écoute ce qui était caché.",
    "Les Robōtariis ne rêvent pas. Ils calculent l'absence.",
    "Retire un élément. Que reste-t-il ?",
    "Le glitch n'est pas une erreur. C'est une vérité accidentelle.",
    "Joue plus lentement que tu ne le penses nécessaire.",
    "Distords jusqu'à l'os. Puis encore un peu.",
    "Qu'est-ce que cette machine voudrait dire si elle pouvait ?",
    "Le silence entre les sons est aussi une composition.",
    "Enregistre d'abord. Écoute après.",
    "La mémoire des machines ne s'efface jamais vraiment.",
    "Travaille avec ce que tu as, pas avec ce que tu voudrais avoir.",
    "Un seul paramètre. Pousse-le à l'extrême.",
    "Les Robōtariis parlent en fréquences que les humains ont oublié d'entendre.",
    "Ce qui semble cassé est peut-être parfait.",
    "Ferme les yeux. Écoute ce que le setup dit sans toi.",
    "La contrainte est une forme de liberté.",
    "Commence par la fin.",
    "Le drone est une prière que la machine adresse au vide.",
    "Moins de sources. Plus de profondeur.",
    "Ce pattern que tu répètes depuis une heure — c'est peut-être ça, le morceau.",
]

DEFAULT_ITEMS = {
    "machine": [
        "MicroFreak", "NTS-1", "Volca Drum", "Volca Kick",
        "Launchpad Pro mk3", "MacBook Intel (instrument)",
        "Mac M4", "iPad/iPhone", "PC Windows",
        "Zoom R8", "Zoom H4n", "BCD 3000",
        "Behringer Uphoria 1820", "Audient ID4 mk2", "CME WIDI Pro",
    ],
    "effet": [
        "NTS-1 (effets)", "Sonicake Smartbox", "Korg Pandora PX Mini",
        "Zoom R8 (effets)", "Zoom H4n (effets)",
    ],
    "daw": [
        "Ableton Live", "Logic Pro", "MainStage",
    ],
    "synth_ios": [
        "Tera Pro", "MiRack", "Condukt", "Stepolyarp",
        "Peach", "Seqnd", "Blue Arp", "LK for Live",
    ],
    "plugin": [
        "Kilohearts Suite", "Baby Audio Tekno", "VCV Rack",
        "Arturia MiniFreak V", "Arturia Analog Lab",
    ],
}

DEFAULT_INFLUENCES = [
    "PanSonic", "Vromb", "Synapscape", "P·A·L", "Converter",
    "Raison d'Être", "Lustmord", "Alva Noto", "Fennesz",
    "Monolake", "Actress", "Esplendor Geométrico", "Noisex",
    "Hands Productions", "Ant-Zen", "Culture of Violence",
]

CHARACTERS = ["Drone","Rythmique","Texturé","Mélodique","Noise","Ambient","Industriel","Génératif","Percussif"]
MODES = ["Dawless","Hybride","Full DAW","iOS seul","MiRack seul"]
INTENTIONS = ["Exploration","B.O Robōtariis","Exercice technique","Défouloir","Jam","Post-prod"]

ITEM_TYPES = {
    "machine": "Hardware / Machines",
    "effet": "Effets Hardware",
    "daw": "DAW",
    "synth_ios": "Synthés iOS",
    "plugin": "Plugins VST/AU",
}

SAMPLE_TYPES   = ["Drums","Percussions","Basses","Synthés","Textures","Field recordings","Loops","Effets","Voix","Autre"]
MIRACK_CATS    = ["Oscillateur","Filtre","LFO","Enveloppe","Séquenceur","Effet","Utilitaire","Mixer","Aléatoire","Autre"]
WISHLIST_TYPES = ["Synthétiseur","Effet hardware","DAW/Logiciel","Contrôleur","Interface audio","Câbles/Accessoires","Autre"]
WISHLIST_PRIOS = ["Urgent","Bientôt","Un jour","Rêve"]
INSPI_TYPES    = ["Phrase","Extrait film","Livre","Image/Photo","Architecture","Concept","Autre"]
