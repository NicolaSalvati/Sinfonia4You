# Politica di sicurezza

## Segnalare una vulnerabilita

Non aprire una issue pubblica per problemi di sicurezza. Utilizza la funzione **Security > Report a vulnerability** di GitHub oppure contatta direttamente il proprietario del repository.

Riceverai un riscontro entro pochi giorni lavorativi.

## Dati sensibili

L'applicazione tratta dati personali di tesserati e ufficiali di gara. Di conseguenza:

- Nessun endpoint reale, IP, token, credenziale o certificato deve essere committato nel repository.
- L'URL del backend viene fornito tramite configurazione (`Config/Secrets.xcconfig`, non versionato) o tramite variabili di ambiente.
- La sessione utente e le credenziali sono conservate nel Keychain, mai in `UserDefaults`.
- Le comunicazioni con il backend usano HTTPS con certificate pinning quando i pin sono configurati.

## Permessi richiesti dall'app

| Permesso | Motivo |
| --- | --- |
| Fotocamera | Acquisizione e scansione delle distinte squadra |
| Libreria Foto | Importazione delle distinte gia fotografate |
| Face ID / Touch ID | Accesso rapido e sicuro all'app |
| Riconoscimento vocale | Trascrizione degli eventi dettati da Apple Watch |
| Microfono (watchOS) | Registrazione vocale degli eventi di gara |
