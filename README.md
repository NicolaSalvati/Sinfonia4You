# Sinfonia4You

App iOS e companion watchOS per gli ufficiali di gara AIA-FIGC: consultazione del portale Sinfonia4You, gestione delle designazioni, compilazione dei referti e rilevazione live degli eventi di gara da Apple Watch.

![Platform](https://img.shields.io/badge/platform-iOS%2026%20%7C%20watchOS%2026-blue)
![Swift](https://img.shields.io/badge/Swift-5.0-orange)
![Xcode](https://img.shields.io/badge/Xcode-26.3-informational)

> Progetto non ufficiale, non affiliato ad AIA-FIGC. Tutti i diritti riservati (vedi [Licenza](#licenza)).

---

## Indice

- [Funzionalita](#funzionalita)
- [Architettura](#architettura)
- [Struttura del progetto](#struttura-del-progetto)
- [Requisiti](#requisiti)
- [Configurazione](#configurazione)
- [Avvio](#avvio)
- [Test](#test)
- [Privacy e permessi](#privacy-e-permessi)
- [Roadmap](#roadmap)
- [Licenza](#licenza)

---

## Funzionalita

### Area personale
- Login con sessione persistente e sblocco biometrico (Face ID / Touch ID)
- Anagrafica, curriculum, scheda tecnica ed esportazione PDF
- Gestione IBAN, documenti, quote e rinnovo del certificato medico
- Richieste di indisponibilita, congedo, preclusione e domande, con relativo storico

### Gare e comunicazioni
- Elenco designazioni con accettazione/rifiuto e promemoria locali
- Dashboard pre-partita con meteo, percorso e contatti rapidi
- Comunicazioni ed eventi con notifiche e allegati scaricabili
- Classifiche e risultati con integrazione delle fonti pubbliche

### Referti
- Compilazione del referto direttore di gara e del referto assistente
- Liste gara, durata dei tempi, sicurezza e svolgimento
- Salvataggio progressivo e ufficializzazione del referto

### Rapporto Gara (iOS + Apple Watch)
- Cronometro di gara con tempi, intervallo e recuperi
- Registrazione eventi (ammonizione, espulsione, doppio giallo, gol, sostituzione, nota)
- Dettatura vocale da Apple Watch con parser in lingua italiana per numero di maglia, squadra, minuto e motivazione
- Sincronizzazione bidirezionale iPhone/Watch via WatchConnectivity, con funzionamento offline e coda di invio
- Acquisizione delle distinte tramite fotocamera, OCR con Vision e correzione manuale di giocatori e staff
- Regolamenti ufficiali (Calcio, Calcio a 5, Beach Soccer) consultabili in-app

---

## Architettura

```
┌──────────────────────┐        WatchConnectivity        ┌───────────────────────┐
│   Sinfonia4You iOS   │ <─────────────────────────────> │  Sinfonia4YouWatch    │
│   SwiftUI + MVVM     │   contesto, sync, dettature     │  SwiftUI watchOS      │
└──────────┬───────────┘                                 └───────────────────────┘
           │ HTTPS (+ certificate pinning)
           v
┌──────────────────────┐
│   Backend API        │  (repository separato)
│   FastAPI            │
└──────────┬───────────┘
           │ scraping/parsing autenticato
           v
┌──────────────────────┐
│  Portale Sinfonia4You│
└──────────────────────┘
```

Principi adottati:

- **SwiftUI + MVVM**: le viste restano dichiarative, la logica vive in ViewModel e store osservabili.
- **Store dedicati** per notifiche, comunicazioni, eventi, promemoria gare e Rapporto Gara.
- **Networking centralizzato** in `APIClient`, con failover su URL di backup, header di sessione e pinning dei certificati.
- **Persistenza**: Keychain per credenziali e sessione, `UserDefaults` per preferenze e cache leggere, Application Support per audio e distinte.
- **Offline first sul Watch**: le sessioni di gara sono registrate localmente e sincronizzate quando l'iPhone torna raggiungibile.

---

## Struttura del progetto

```
Sinfonia4You/
├─ Sinfonia4You/                     # Target app iOS
│  ├─ Core/
│  │  ├─ Models/                     # Sessione, DTO reparti e scheda tecnica
│  │  ├─ Navigation/                 # Router e modificatori di navigazione
│  │  ├─ Networking/                 # APIClient, sicurezza di rete, download
│  │  ├─ Notifications/              # Store notifiche, eventi, promemoria
│  │  ├─ RapportoGara/               # Modelli, store, OCR distinte, speech
│  │  └─ Security/                   # Autenticazione biometrica
│  ├─ Features/
│  │  ├─ Auth/                       # Login e gestione sessione
│  │  ├─ Home/                       # Dashboard e pre-partita
│  │  ├─ Navigation/                 # Tab principale
│  │  ├─ Reparti/                    # Moduli portale, referti, scheda tecnica
│  │  └─ Settings/                   # Impostazioni e documenti legali
│  └─ Assets.xcassets
├─ Sinfonia4YouWatch Watch App/      # Target watchOS
├─ Sinfonia4YouTests/                # Test unitari
├─ Sinfonia4YouUITests/              # Test di interfaccia
└─ Sinfonia4You.xcodeproj
```

---

## Requisiti

| Componente | Versione |
| --- | --- |
| Xcode | 26.3 o superiore |
| iOS | 26.0 (target di deployment) |
| watchOS | 26.2 |
| Swift | 5.0 |
| Backend | FastAPI (repository separato) |

---

## Configurazione

L'app non contiene endpoint reali. L'URL del backend viene letto, in ordine di priorita, da:

1. variabili di ambiente dello schema Xcode: `SINFONIA_API_BASE_URL`, `SINFONIA_API_BASE_URLS`, `SINFONIA_DEBUG_API_BASE_URL`;
2. chiavi `Info.plist` popolate da build settings: `SINFONIA_API_BASE_URL`, `SINFONIA_API_BACKUP_URLS`, `SINFONIA_API_PINS`;
3. valore memorizzato in `UserDefaults` dopo il primo avvio andato a buon fine.

### Passi

1. Duplica il file di esempio:

   ```bash
   cp Config/Secrets.example.xcconfig Config/Secrets.xcconfig
   ```

2. Compila i valori:

   ```
   SINFONIA_API_BASE_URL = https:/$()/il-tuo-backend.example.com
   SINFONIA_API_BACKUP_URLS =
   SINFONIA_API_PINS =
   ```

   > La sequenza `/$()/` serve a evitare che `//` venga interpretato come commento nei file `.xcconfig`.

3. In Xcode, associa `Config/Secrets.xcconfig` alla configurazione desiderata (Project > Info > Configurations).

`Config/Secrets.xcconfig` e escluso dal versionamento tramite `.gitignore`.

---

## Avvio

```bash
git clone https://github.com/<utente>/Sinfonia4You.git
cd Sinfonia4You
open Sinfonia4You.xcodeproj
```

Seleziona lo schema `Sinfonia4You` e un simulatore iPhone, oppure lo schema `Sinfonia4YouWatch Watch App` per il companion. Per provare la sincronizzazione Watch, esegui l'app iPhone e l'app Watch su una coppia di simulatori abbinati.

---

## Test

```bash
# Test unitari + UI su simulatore
xcodebuild test \
  -project Sinfonia4You.xcodeproj \
  -scheme Sinfonia4You \
  -destination 'platform=iOS Simulator,name=iPhone 17'
```

La suite copre in particolare il parser delle distinte (`RapportoGaraDistinteParser`) e il parsing delle classifiche.

---

## Privacy e permessi

L'app richiede i seguenti permessi, con relative motivazioni gia dichiarate in `Info.plist`:

| Permesso | Uso |
| --- | --- |
| Fotocamera | Acquisizione e scansione delle distinte squadra |
| Libreria Foto | Importazione delle distinte |
| Face ID | Accesso rapido e sicuro |
| Riconoscimento vocale | Trascrizione degli eventi dettati da Apple Watch |
| Microfono (watchOS) | Registrazione vocale degli eventi di gara |

Nessun dato viene condiviso con terze parti: le informazioni transitano esclusivamente tra l'app, il backend dedicato e il portale ufficiale.

---

## Roadmap

- [ ] Estensione della copertura di test su store e networking
- [ ] Localizzazione multilingua tramite String Catalog
- [ ] Widget e Live Activity per la gara in corso
- [ ] Esportazione del Rapporto Gara in PDF

---

## Licenza

Copyright (c) 2026. Tutti i diritti riservati.

Il codice e pubblicato a scopo consultivo e dimostrativo. Non e concessa alcuna licenza d'uso, copia, modifica o ridistribuzione senza autorizzazione scritta del proprietario del repository. Vedi [COPYRIGHT](COPYRIGHT).
