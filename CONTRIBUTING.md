# Linee guida di contribuzione

Grazie per l'interesse verso Sinfonia4You. Questo documento descrive il flusso di lavoro adottato nel repository.

## Requisiti

- macOS con Xcode 26.3 o superiore
- SDK iOS 26.0 e watchOS 26.2
- Swift 5.0 (toolchain inclusa in Xcode)

## Flusso di lavoro

1. Crea un branch dedicato a partire da `main`:
   - `feature/<breve-descrizione>` per nuove funzionalita
   - `fix/<breve-descrizione>` per correzioni
   - `chore/<breve-descrizione>` per manutenzione
2. Mantieni i commit piccoli e coerenti.
3. Apri una Pull Request verso `main` compilando il template.

## Convenzione dei commit

Si utilizza [Conventional Commits](https://www.conventionalcommits.org/):

```
feat(rapporto-gara): aggiunge dettatura vocale da Apple Watch
fix(distinte): corregge il parsing del numero di maglia
docs(readme): aggiorna le istruzioni di configurazione
refactor(api): estrae il client di rete
test(parser): copre gli alias del capitano
chore(ci): aggiorna la versione di Xcode
```

Scope suggeriti: `auth`, `api`, `rapporto-gara`, `distinte`, `referti`, `reparti`, `scheda-tecnica`, `watch`, `ui`, `ci`.

## Stile del codice

- SwiftUI dichiarativo, viste piccole e componibili.
- Logica di dominio nei ViewModel e negli store, non nelle viste.
- Nomi di tipi e proprieta in italiano dove gia adottato nel modulo, per coerenza.
- Nessun segreto, token, IP o credenziale hardcoded: usa la configurazione descritta nel README.

## Test

Prima di aprire una PR esegui:

```bash
xcodebuild test \
  -project Sinfonia4You.xcodeproj \
  -scheme Sinfonia4You \
  -destination 'platform=iOS Simulator,name=iPhone 17'
```

I test unitari vivono in `Sinfonia4YouTests`, i test di interfaccia in `Sinfonia4YouUITests`.

## Segnalazione di problemi

Apri una issue usando i template disponibili, indicando versione di iOS/watchOS, passi per riprodurre e comportamento atteso.
