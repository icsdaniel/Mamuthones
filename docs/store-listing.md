# Store listing

Material for the App Store and Google Play pages. The game is paid up front, offline, with no ads,
no in-app purchases, no accounts of its own and no data collection. Character counts below are checked
against both stores' limits (App Store name and subtitle 30 each; Google Play title 30, short
description 80).

## Names

Updated after the outside review (2026-10-31): the game is called Sonazzos, the Workshop and mask
carving are gone, and there are no stand-stills.

| | English | Italiano |
| --- | --- | --- |
| App name / Play title (30 max) | Sonazzos (8) | Sonazzos (8) |
| App Store subtitle (30 max) | Mamuthones rhythm game (22) | Ritmo dei Mamuthones (20) |
| Google Play short description (80 max) | Ring the Mamuthones' bells on the beat. A rhythm game from Sardinia. (69) | Suona i campanacci dei Mamuthones a tempo. Un gioco ritmico sardo. (67) |
| Category | Games › Music | Giochi › Musica |
| Age rating | 4+ / PEGI 3 (no violence, no chat, no purchases) | 4+ / PEGI 3 |

## Description — English

**Walk with the Mamuthones of Mamoiada.**

Every winter in Mamoiada, in the heart of Sardinia, the Mamuthones walk through the village in dark
wooden masks and sheepskins, carrying a heavy load of cowbells, the sonazzos, on their backs. Step by
step they move together, and their bells ring as one.

In *Sonazzos* you are one of them. Hold the phone in both hands, tap the three step buttons as the
notes slide down, and ring your bells with a sharp tilt of the phone, up, then down. The better you
keep time, the louder the whole row rings behind you.

- **The bells are the game.** A quick tilt rings them, alternating up and down. Prefer buttons? Press
  Left and Right together instead.
- **Unison.** Hits on time raise your row's unison, up to 4x; a slip costs two levels, not everything.
  The fire burns brighter as the row comes together.
- **Seven stops,** from the dressing before the first outing and the fires of Sant'Antonio in January
  to the last day of Carnival, each with its own song and a modern remix to unlock.
- **Four difficulties** for every song, grades from F to S+, and online leaderboards through Game
  Center and Google Play Games.
- **Fair timing.** A tilt calibration, sound and screen delay tests, and a results screen that shows
  whether you hit early or late, with one tap to fix it.

Made with respect for a living tradition that belongs to the people of Mamoiada. Best with headphones.

Plays fully offline. No ads. No in-app purchases. No data collected.

## Descrizione — Italiano

**Cammina con i Mamuthones di Mamoiada.**

Ogni inverno a Mamoiada, nel cuore della Sardegna, i Mamuthones attraversano il paese con le maschere
di legno scuro e le pelli di pecora, portando sulla schiena un pesante carico di campanacci, i sonazzos.
Passo dopo passo avanzano insieme, e i campanacci suonano come uno solo.

In *Sonazzos* sei uno di loro. Tieni il telefono con due mani, batti i tre tasti dei passi mentre
scendono le note, e fai suonare i campanacci con un colpo secco del telefono, in su e poi in giù. Più
tieni il tempo, più forte suona dietro di te tutta la fila.

- **I campanacci sono il gioco.** Basta un colpo di polso, alternando su e giù. Preferisci i tasti?
  Premi insieme Sinistra e Destra.
- **L'unisono.** I colpi a tempo alzano l'unisono della fila, fino a 4x; un errore ti fa scendere di
  due livelli, non da capo. Il fuoco arde più forte quando la fila è unita.
- **Sette tappe,** dalla vestizione prima della prima uscita e dai fuochi di Sant'Antonio a gennaio
  fino all'ultimo giorno di Carnevale, ognuna con il suo brano e un remix moderno da sbloccare.
- **Quattro difficoltà** per ogni brano, voti dalla F alla S+, e classifiche online con Game Center e
  Google Play Games.
- **Un tempo giusto.** Calibrazione del movimento, test del ritardo di audio e schermo, e una
  schermata dei risultati che mostra se anticipi o ritardi, con un tocco per correggere.

Fatto con rispetto per una tradizione viva, che appartiene alla gente di Mamoiada. Meglio con le cuffie.

Si gioca interamente offline. Niente pubblicità. Niente acquisti in-app. Nessun dato raccolto.

## Privacy statement

Use the same text for the App Store privacy label ("Data Not Collected"), the Google Play Data safety
form ("No data collected, no data shared") and the privacy policy URL.

> **English.** Sonazzos does not collect, store off the device, or share any personal data. It has
> no accounts of its own, no advertising, no analytics and no tracking, and the game itself makes no
> internet connections. Your settings, scores and progress are saved only on your phone and are deleted
> when you uninstall the game. The motion sensors are read only while you play, to detect the bell
> tilt, and their readings never leave the device.
>
> Optional: if you are signed in to Game Center (iPhone, iPad) or Google Play Games (Android) and open
> the online leaderboards, your score and your player name for that service are sent to Apple or
> Google, under their own privacy policies, to show the global leaderboards. Nothing else is sent, and
> the game works fully without signing in.
>
> **Italiano.** Sonazzos non raccoglie, non conserva fuori dal dispositivo e non condivide alcun dato
> personale. Non ha account propri, pubblicità, statistiche d'uso né tracciamento, e il gioco in sé non
> si collega a internet. Impostazioni, punteggi e progressi restano solo sul tuo telefono e vengono
> cancellati quando disinstalli il gioco. I sensori di movimento vengono letti solo mentre giochi, per
> riconoscere il colpo dei campanacci, e i loro dati non lasciano mai il dispositivo.
>
> Facoltativo: se hai effettuato l'accesso a Game Center (iPhone, iPad) o Google Play Games (Android) e
> apri le classifiche online, il tuo punteggio e il tuo nome giocatore su quel servizio vengono inviati
> ad Apple o Google, secondo le loro informative, per mostrare le classifiche globali. Non viene inviato
> nient'altro, e il gioco funziona completamente anche senza accesso.

Platform settings that back this up (`game/export_presets.cfg`): Android asks only for the vibrate
permission (no internet permission); the iOS privacy manifest declares no tracking and no collected data. If
the Google Play Games leaderboards are switched on in a later build, the Android preset will need the
internet permission and the Play "Data safety" form must then say the score is shared with Google.
The outside review (2026-10-31) flagged this: the game already shows a Game Center / Play Games button
on the Scores screen, so either that button stays hidden on Android until the permission is added, or
the permission and the Data safety answer change before launch.

## Screenshots

Rendered by `game/tests/screenshots.gd` (see "How to make them" below) in every size the stores need.
Use these, in this order:

| # | File (per size folder) | Caption (EN) | Didascalia (IT) |
| --- | --- | --- | --- |
| 1 | `play_fires.png` | Ring the bells. Keep the row. | Suona i campanacci. Tieni il passo. |
| 2 | `results.png` | See your grade, your unison and your timing. | Il tuo voto, il tuo unisono e il tuo tempo. |
| 3 | `story.png` | Seven stops, from the fires to Shrove Tuesday. | Sette tappe, dai fuochi al Martedì grasso. |
| 4 | `play_bell.png` | Tilt the phone to ring the bells. | Inclina il telefono per suonare i campanacci. |
| 5 | `stop_card.png` | Every stop is a real moment of the procession. | Ogni tappa è un vero momento della processione. |
| 6 | `title.png` | Offline. No ads. No purchases. | Offline. Niente pubblicità, niente acquisti. |

Sizes (the folder names the script writes):

| Folder | Pixels | Use |
| --- | --- | --- |
| `720x1600` | 720 × 1600 (9:20) | Google Play phone (scale to 1080 × 2400 if a larger size is wanted) |
| `720x1440` | 720 × 1440 (9:18) | Google Play phone |
| `720x1280` | 720 × 1280 (9:16) | Google Play phone, older aspect |
| `1290x2796` | 1290 × 2796 | App Store 6.9" iPhone (required) |
| `1536x2048` | 1536 × 2048 (3:4) | App Store iPad and Google Play tablet |

Italian screenshots: the script also writes an `it/` copy of every size with the game in Italian.

### How to make them

```
xvfb-run -a godot --path game --rendering-driver opengl3 -s res://tests/screenshots.gd -- /tmp/shots
```

### App preview video

Record an Autoplay run with Godot's movie maker, then trim to 15–30 s:

```
godot --path game --rendering-driver opengl3 --write-movie /tmp/fires.avi --fixed-fps 60 \
    -s res://tests/record.gd -- fires hard
```

## Icon

Art's app icon: `game/art/icon.png` (1024 × 1024, iOS and stores). Android's adaptive icon uses
`game/art/icon_192.png`, `game/art/icon_fg_432.png` and `game/art/icon_bg_432.png`, all set in
`game/export_presets.cfg`. Bundle ID and package name: `io.github.icsdaniel.mamuthones`.

## Keywords (App Store, 100 chars)

EN: `rhythm,bells,sardinia,mamuthones,carnival,mask,music,tilt,folk,cowbell`
IT: `ritmo,campanacci,sardegna,mamuthones,carnevale,maschera,musica,tradizione`
