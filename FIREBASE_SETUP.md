# Firebase e App Store Review Setup

Questo documento spiega come configurare Firebase Analytics e il sistema di richiesta valutazioni App Store per INDEX.

## Firebase Setup

Firebase è già configurato nel progetto con le seguenti dipendenze:
- FirebaseAnalytics

### Passi per completare la configurazione:

1. **Crea un progetto Firebase:**
   - Vai su [Firebase Console](https://console.firebase.google.com/)
   - Crea un nuovo progetto o seleziona un progetto esistente

2. **Aggiungi l'app macOS:**
   - Nel progetto Firebase, clicca "Aggiungi app" > "iOS/macOS"
   - Inserisci il Bundle ID della tua app (puoi trovarlo in Xcode: Project > Targets > General > Bundle Identifier)
   - Scarica il file `GoogleService-Info.plist`

3. **Configura il file GoogleService-Info.plist:**
   - Sostituisci il file `GoogleService-Info.plist` esistente nella cartella `SQLClient/` con quello scaricato da Firebase
   - Assicurati che sia incluso nel target dell'app

4. **Verifica la configurazione:**
   - Firebase viene inizializzato automaticamente in `SQLClientApp.swift`
   - Gli eventi vengono tracciati automaticamente quando:
     - Si apre un workspace
     - Si esegue una query SQL
     - Si richiede una valutazione App Store

## App Store Review Setup

Il sistema di richiesta valutazioni mostra automaticamente un prompt dopo la prima apertura di un workspace.

### Configurazione necessaria:

1. **Trova il tuo App ID:**
   - Vai su [App Store Connect](https://appstoreconnect.apple.com/)
   - Seleziona la tua app
   - Nella pagina "App Information", trova l'Apple ID (un numero come 1234567890)

2. **Aggiorna il codice:**
   - Apri `Services/AppStoreReviewService.swift`
   - Sostituisci `"YOUR_APP_ID"` con il tuo Apple ID effettivo in entrambe le righe:
     ```swift
     let appStoreURL = "macappstore://apps.apple.com/app/idYOUR_APP_ID?action=write-review"
     let fallbackURL = "https://apps.apple.com/app/idYOUR_APP_ID"
     ```

### Come funziona:

- Il prompt appare automaticamente dopo la prima apertura di un workspace
- Se l'utente ha già valutato l'app, il prompt non appare più
- Gli utenti possono scegliere "Valuta ora" o "Più tardi"
- Scegliendo "Più tardi", il prompt non apparirà più

### Eventi Firebase tracciati:

- `workspace_opened`: Quando si apre un workspace
- `query_executed`: Quando si esegue una query SQL
- `review_requested`: Quando l'utente sceglie di valutare l'app

## Test

Per testare il sistema:

1. **Reset delle preferenze per il testing:**
   ```bash
   defaults delete com.tuo-bundle-id hasReviewedApp
   defaults delete com.tuo-bundle-id workspaceOpensCount
   ```

2. **Verifica Firebase:**
   - Gli eventi appariranno nella console Firebase > Analytics > Events
   - Potrebbe volerci qualche ora perché gli eventi appaiano

3. **Test del prompt di valutazione:**
   - Apri un workspace
   - Il prompt dovrebbe apparire dopo 2 secondi
   - Testa entrambi i pulsanti