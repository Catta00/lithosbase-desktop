# Lithosbase Desktop

App desktop che fa da **specchio della web app** `https://lithosbase.app`.
Carica il sito live in una finestra nativa: l'accesso e tutte le funzioni sono quelle
del web, quindi l'app resta sempre allineata senza dover ricompilare nulla.

## Come funziona
- `main.js` apre una finestra che carica `lithosbase.app`.
- Il login è quello della web app (la sessione resta salvata tra un avvio e l'altro).
- I link esterni (PDF, social, mailto) si aprono nel browser di sistema.

## Sviluppo
```
npm install
npm start          # avvia l'app in locale
```
Per puntare a un ambiente diverso: `LITHOSBASE_URL=https://preview... npm start`.

## Build installer
```
npm run dist:win   # Windows (.exe NSIS)  → cartella release/
npm run dist:mac   # macOS (.dmg) — richiede un Mac
npm run dist:linux # Linux (AppImage)
```

## TODO prima della distribuzione
- Aggiungere le icone in `build/`: `icon.ico` (Windows), `icon.icns` (mac), `icon.png` (Linux).
  Sorgente: logo Lithosbase (vedi `lithosbase.app/logo-black.webp`).
- Code signing (Windows/macOS) per evitare avvisi SmartScreen/Gatekeeper.
- Decidere il canale di distribuzione (download dal sito vs Microsoft Store).
