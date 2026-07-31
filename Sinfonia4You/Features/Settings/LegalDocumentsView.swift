import SwiftUI

enum DocumentoLegaleKind: String, CaseIterable, Identifiable {
    case terminiApp
    case condizioniUso
    case privacyDati

    var id: String { rawValue }

    var titolo: String {
        switch self {
        case .terminiApp:
            return "Termini dell'app"
        case .condizioniUso:
            return "Condizioni d'uso"
        case .privacyDati:
            return "Privacy e dati"
        }
    }

    var titoloBreve: String {
        switch self {
        case .terminiApp:
            return "Termini"
        case .condizioniUso:
            return "Condizioni"
        case .privacyDati:
            return "Privacy"
        }
    }

    var icona: String {
        switch self {
        case .terminiApp:
            return "doc.text"
        case .condizioniUso:
            return "checklist"
        case .privacyDati:
            return "hand.raised"
        }
    }

    var sottotitoloMenu: String {
        switch self {
        case .terminiApp:
            return "Scopo, limiti del servizio, responsabilità e aggiornamenti della piattaforma."
        case .condizioniUso:
            return "Regole operative per accesso, utilizzo corretto, referti, biometria e notifiche."
        case .privacyDati:
            return "Informativa dettagliata su dati trattati, archiviazione locale, backend e controlli utente."
        }
    }

    var introduzione: String {
        switch self {
        case .terminiApp:
            return "Documento generale che definisce cosa offre l'app, quali limiti operativi ha e quale rapporto mantiene con il portale Sinfonia4You e con i dati visualizzati."
        case .condizioniUso:
            return "Regole di utilizzo applicabili all'utente che accede con il proprio account arbitrale e usa i moduli operativi dell'app su iPhone."
        case .privacyDati:
            return "Informativa estesa sul trattamento dei dati personali e tecnici legati all'accesso, all'uso dei moduli, alla biometria e alle notifiche locali."
        }
    }

    var ambito: String {
        switch self {
        case .terminiApp:
            return "Servizio applicativo"
        case .condizioniUso:
            return "Uso dell'account"
        case .privacyDati:
            return "Dati e protezione"
        }
    }

    var avvertenza: String? {
        switch self {
        case .terminiApp:
            return "Per designazioni, referti, dati tecnici, comunicazioni ufficiali e scadenze rilevanti, la fonte di riferimento resta sempre il servizio Sinfonia4You e la documentazione ufficiale collegata al tuo profilo arbitrale."
        case .condizioniUso:
            return "L'app rende più rapido il lavoro operativo, ma non sostituisce la responsabilità personale dell'arbitro nel controllare l'esattezza dei dati prima di inviare referti, accettare designazioni o usare documenti ufficiali."
        case .privacyDati:
            return "Questa app non adotta un monitoraggio continuo del portale tramite credenziali salvate sul server per generare notifiche remote automatiche. È una scelta esplicita orientata alla tutela della privacy dell'utente."
        }
    }

    var sezioni: [DocumentoLegaleSection] {
        switch self {
        case .terminiApp:
            return [
                DocumentoLegaleSection(
                    titolo: "1. Oggetto del servizio",
                    paragrafi: [
                        "Sinfonia4You per iPhone è una piattaforma mobile pensata per consentire all'utente autorizzato di consultare e gestire, da dispositivo iOS, una parte delle funzioni disponibili tramite il proprio account arbitrale: accesso, designazioni, dettagli gara, classifica gara, referti, comunicazioni, eventi, scheda tecnica, promemoria e altre aree operative rese disponibili dal profilo.",
                        "L'app non genera autonomamente designazioni, classifiche, voti, rimborsi o provvedimenti. I contenuti mostrati dipendono dal profilo dell'utente, dal portale Sinfonia4You, dai sistemi collegati e dalle informazioni che tali servizi rendono effettivamente disponibili al momento della richiesta."
                    ]
                ),
                DocumentoLegaleSection(
                    titolo: "2. Rapporto con servizi esterni e fonti ufficiali",
                    paragrafi: [
                        "L'app si appoggia a un backend applicativo che interroga i servizi necessari per autenticare l'utente e recuperare i contenuti richiesti. Alcune funzioni possono inoltre dipendere da siti, moduli o dati di terze parti collegati all'ecosistema arbitrale.",
                        "Quando un'informazione è decisiva ai fini operativi, disciplinari, amministrativi o di refertazione, l'utente deve considerare il portale ufficiale e gli atti ufficiali come fonte prevalente. L'app ha finalità di supporto, accesso rapido e organizzazione operativa, non di sostituzione dell'obbligo di verifica."
                    ]
                ),
                DocumentoLegaleSection(
                    titolo: "3. Disponibilità, continuità e aggiornamenti",
                    paragrafi: [
                        "Il servizio è fornito secondo disponibilità tecnica. Possono verificarsi interruzioni, rallentamenti, modifiche dell'interfaccia, differenze di contenuto tra moduli, assenza temporanea di dati o necessità di manutenzione ordinaria e straordinaria.",
                        "Il Gestore dell'app può aggiornare interfacce, flussi, modalità di accesso, testi legali e integrazioni tecniche per motivi di sicurezza, compatibilità, miglioramento del servizio o adeguamento a variazioni dei sistemi collegati. L'uso continuato dell'app dopo un aggiornamento implica presa visione del quadro operativo aggiornato."
                    ]
                ),
                DocumentoLegaleSection(
                    titolo: "4. Limitazioni del servizio",
                    paragrafi: [
                        "L'app compie ogni sforzo ragionevole per mostrare dati coerenti, ordinati e utili all'attività arbitrale, ma non garantisce in assoluto la presenza continua di ogni funzionalità su ogni account, categoria, ruolo o periodo temporale. Alcuni moduli possono cambiare comportamento in base al ruolo dell'utente, al tipo di gara o alla disponibilità del dato sorgente.",
                        "Promemoria, badge, notifiche locali, sincronizzazioni e contenuti cache aiutano l'operatività ma non costituiscono prova formale di avvenuta comunicazione, ricezione, presa visione o adempimento di obblighi ufficiali."
                    ]
                ),
                DocumentoLegaleSection(
                    titolo: "5. Responsabilità dell'utente",
                    paragrafi: [
                        "L'utente è responsabile dell'uso del proprio account, della correttezza delle informazioni inserite nei moduli, della verifica dei dati prima di un invio operativo e della custodia del dispositivo con cui accede all'app.",
                        "Prima di trasmettere un referto, confermare un'azione o fare affidamento su un'informazione operativa, l'utente deve controllare contenuti, data, ora, ruolo, squadre, allegati e ogni altro elemento rilevante al proprio adempimento."
                    ]
                ),
                DocumentoLegaleSection(
                    titolo: "6. Proprietà, documentazione e contenuti",
                    paragrafi: [
                        "Interfaccia, flussi, testi, componenti grafici, organizzazione delle schermate e documentazione dell'app restano riservati al Gestore dell'app e ai rispettivi aventi diritto. I contenuti provenienti da servizi esterni restano nella disponibilità dei rispettivi titolari.",
                        "È vietato riprodurre, estrarre in massa, redistribuire o riutilizzare in modo non autorizzato componenti, contenuti o logiche del servizio per finalità estranee all'uso personale e autorizzato dell'app."
                    ]
                )
            ]

        case .condizioniUso:
            return [
                DocumentoLegaleSection(
                    titolo: "1. Accesso e requisiti dell'utente",
                    paragrafi: [
                        "L'accesso è riservato al titolare legittimo delle credenziali arbitrali utilizzate per autenticarsi. L'utente deve impiegare un dispositivo iOS protetto da codice di sblocco, aggiornato e sotto il proprio controllo diretto.",
                        "L'uso dell'app deve essere coerente con il ruolo ricoperto, con i dati resi disponibili dal proprio account e con le regole del contesto arbitrale di riferimento."
                    ]
                ),
                DocumentoLegaleSection(
                    titolo: "2. Credenziali, sessione e biometria",
                    paragrafi: [
                        "Le credenziali sono personali e non devono essere condivise, trasmesse o rese accessibili a terzi. In caso di sospetto accesso non autorizzato, l'utente deve cambiare password e interrompere l'uso della sessione attiva.",
                        "L'accesso con Face ID o Touch ID è opzionale e deve essere attivato esplicitamente nelle impostazioni dell'app. Se attivato, le credenziali vengono archiviate esclusivamente nel Portachiavi del dispositivo, protette dal sistema di sicurezza Apple e sbloccabili solo mediante biometria o configurazione equivalente prevista da iOS."
                    ]
                ),
                DocumentoLegaleSection(
                    titolo: "3. Uso corretto delle funzioni operative",
                    paragrafi: [
                        "L'utente deve utilizzare designazioni, referti, classifica gara, scheda tecnica, comunicazioni, eventi e documenti in modo coerente con la loro finalità. È vietato usare l'app per alterare contenuti, tentare accessi non autorizzati, aggirare controlli, manipolare richieste o ottenere dati non spettanti.",
                        "Quando il modulo referti è disponibile, la compilazione e l'invio devono essere eseguiti solo dopo controllo consapevole del contenuto. L'utente resta responsabile di quanto inserito e trasmesso tramite il proprio account."
                    ]
                ),
                DocumentoLegaleSection(
                    titolo: "4. Notifiche, promemoria e disponibilità del dato",
                    paragrafi: [
                        "Le notifiche presenti nell'app sono gestite in modo coerente con il livello di privacy scelto per il progetto. L'app può generare badge e promemoria locali sul dispositivo, ma non salva le credenziali dell'utente sul server per effettuare monitoraggi continui del portale a sua insaputa.",
                        "Il promemoria gara del giorno viene programmato localmente in base alle designazioni già sincronizzate e può dipendere da permessi notifiche, stato del dispositivo, calendario del sistema e ultima sincronizzazione disponibile. L'utente deve pertanto considerarlo uno strumento di supporto e non un presidio sostitutivo dei controlli personali."
                    ]
                ),
                DocumentoLegaleSection(
                    titolo: "5. Comportamenti vietati",
                    paragrafi: [
                        "È vietato usare l'app per effettuare scraping non autorizzato, reverse engineering, simulazioni di traffico malevolo, estrazione massiva di dati, condivisione di sessioni, uso promiscuo del dispositivo con account diversi senza adeguata disconnessione oppure caricamento di contenuti illeciti o non pertinenti.",
                        "Sono parimenti vietati usi che possano danneggiare l'integrità del servizio, compromettere la sicurezza di altri utenti o produrre referti, comunicazioni o azioni operative non corrispondenti alla volontà e alla responsabilità personale dell'utente autenticato."
                    ]
                ),
                DocumentoLegaleSection(
                    titolo: "6. Sospensione, aggiornamenti e cessazione dell'uso",
                    paragrafi: [
                        "Alcune funzioni possono essere temporaneamente limitate o sospese in caso di problemi tecnici, aggiornamenti, cambiamenti dei servizi esterni o necessità di sicurezza. Il Gestore dell'app può modificare flussi o interfacce per mantenere il servizio coerente, leggibile e sicuro.",
                        "L'utente può interrompere l'uso in ogni momento effettuando logout, disattivando biometria e promemoria, revocando i permessi di sistema o rimuovendo l'app dal dispositivo."
                    ]
                )
            ]

        case .privacyDati:
            return [
                DocumentoLegaleSection(
                    titolo: "1. Principi generali del trattamento",
                    paragrafi: [
                        "L'app tratta solo i dati necessari a fornire le funzionalità richieste dall'utente e a mantenere un'esperienza coerente sul dispositivo. L'impostazione generale del progetto privilegia minimizzazione del dato, controllo locale dell'utente e assenza di monitoraggi remoti non indispensabili.",
                        "Ogni funzione che comporta archiviazione aggiuntiva sul dispositivo o uso di componenti sensibili, come biometria e notifiche, viene attivata solo in presenza di scelta esplicita dell'utente o di permessi concessi tramite iOS."
                    ]
                ),
                DocumentoLegaleSection(
                    titolo: "2. Categorie di dati trattati",
                    paragrafi: [
                        "Per l'autenticazione e l'uso del servizio possono essere trattati dati identificativi e operativi come username, password inserita per il login, token di sessione, codice associativo, ruolo, sezione, ultimo accesso, designazioni, dettagli gara, referti, comunicazioni, eventi, documenti, scheda tecnica, rimborsi, classifiche e altri contenuti resi disponibili dal profilo dell'utente.",
                        "Sul dispositivo possono inoltre essere trattati dati tecnici e di preferenza come impostazione della biometria, stato del promemoria gara del giorno, elenco degli eventi non letti, dati temporanei di cache di rete e permessi notifiche concessi dal sistema operativo."
                    ]
                ),
                DocumentoLegaleSection(
                    titolo: "3. Finalità del trattamento",
                    paragrafi: [
                        "I dati vengono trattati per autenticare l'utente, caricare i moduli richiesti, mostrare designazioni e contenuti collegati, permettere la consultazione e la compilazione dei flussi operativi previsti, mantenere il badge delle novità, generare promemoria locali della gara del giorno e, se attivato, consentire l'accesso rapido con Face ID o Touch ID.",
                        "L'app non utilizza i dati per profilazione commerciale, rivendita a terzi o monitoraggio server-side costante delle credenziali dell'utente per finalità di notifica remota automatica."
                    ]
                ),
                DocumentoLegaleSection(
                    titolo: "4. Dove vengono gestiti i dati",
                    paragrafi: [
                        "Una parte dei dati transita dal backend applicativo necessario a soddisfare le richieste dell'utente verso i servizi collegati. Sul dispositivo iPhone restano invece le informazioni strettamente locali: preferenze, badge di lettura, promemoria, cache temporanee e, solo se l'utente abilita la biometria, le credenziali protette nel Portachiavi Apple.",
                        "Le credenziali salvate per la biometria non vengono memorizzate sul server per la generazione di notifiche automatiche. Restano nel dispositivo, con protezione hardware e logica fornita da Apple, finché l'utente non disattiva la funzione o rimuove l'app."
                    ]
                ),
                DocumentoLegaleSection(
                    titolo: "5. Conservazione e permanenza dei dati",
                    paragrafi: [
                        "La sessione applicativa resta disponibile fino a logout, scadenza tecnica o chiusura della sessione da parte del sistema. Gli identificativi degli eventi non letti, le preferenze dei promemoria e altre impostazioni applicative possono restare in memoria locale per offrire continuità d'uso tra un'apertura e l'altra.",
                        "Le risposte di rete possono essere temporaneamente conservate nella cache del dispositivo secondo le regole di iOS e della configurazione tecnica dell'app, allo scopo di migliorare velocità e fluidità. Tali dati non hanno finalità autonome e possono essere rimossi dal sistema, dall'utente o con reinstallazione dell'app."
                    ]
                ),
                DocumentoLegaleSection(
                    titolo: "6. Notifiche locali e dati non letti",
                    paragrafi: [
                        "Le notifiche implementate nell'app sono locali sul dispositivo e si basano sui dati già sincronizzati dall'utente. Il badge della sezione Notizie utilizza il conteggio degli eventi che l'app considera ancora non letti in base allo stato locale del profilo attivo sul dispositivo.",
                        "Il promemoria della gara del giorno viene programmato localmente alle ore 09:00, quando previsto, usando le designazioni già scaricate. Se l'utente revoca il permesso notifiche o disattiva il promemoria nelle impostazioni, la funzione smette di operare sul dispositivo."
                    ]
                ),
                DocumentoLegaleSection(
                    titolo: "7. Controlli e scelte dell'utente",
                    paragrafi: [
                        "L'utente può in ogni momento effettuare logout, disattivare l'accesso biometrico, disattivare il promemoria gara del giorno, revocare i permessi notifiche da iOS, cambiare password sul sistema di riferimento e rimuovere l'app dal dispositivo.",
                        "Per una protezione coerente dei dati visualizzati, è raccomandato usare un codice di sblocco sicuro, non condividere il dispositivo sbloccato con terzi, aggiornare regolarmente iOS e disattivare biometria se il dispositivo non è più sotto controllo esclusivo dell'utente."
                    ]
                ),
                DocumentoLegaleSection(
                    titolo: "8. Trasparenza e limiti",
                    paragrafi: [
                        "L'app è progettata per rendere chiaro quando una funzione opera in locale e quando, invece, dipende da servizi esterni. Se un dato non è disponibile, è incompleto o richiede una verifica ulteriore, l'utente deve fare affidamento sulla fonte ufficiale collegata al proprio account arbitrale.",
                        "Eventuali richieste di chiarimento su trattamento, sicurezza o uso dell'app devono essere indirizzate ai riferimenti di supporto o ai canali indicati nella distribuzione del progetto e nella documentazione applicabile al servizio."
                    ]
                )
            ]
        }
    }
}

struct DocumentoLegaleSection: Identifiable {
    let id = UUID()
    let titolo: String
    let paragrafi: [String]
}

struct VistaDocumentoLegale: View {
    let kind: DocumentoLegaleKind

    var body: some View {
        ZStack {
            SfondoSezioniAppView()
                .ignoresSafeArea()

            ScrollView(showsIndicators: false) {
                VStack(alignment: .leading, spacing: 18) {
                    CardTitoloView(
                        titolo: kind.titolo,
                        sottotitolo: kind.introduzione
                    )

                    DocumentoLegaleMetaCard(
                        aggiornamento: "20 marzo 2026",
                        ambito: kind.ambito
                    )

                    if let avvertenza = kind.avvertenza {
                        DocumentoLegaleEvidenzaCard(
                            titolo: "Avvertenza importante",
                            testo: avvertenza
                        )
                    }

                    ForEach(kind.sezioni) { sezione in
                        DocumentoLegaleSectionCard(sezione: sezione)
                    }
                }
                .padding(.horizontal, 18)
                .padding(.top, 18)
                .padding(.bottom, 36)
            }
        }
        .navigationTitle(kind.titoloBreve)
        .navigationBarTitleDisplayMode(.inline)
    }
}

private struct DocumentoLegaleMetaCard: View {
    let aggiornamento: String
    let ambito: String

    var body: some View {
        HStack(spacing: 14) {
            DocumentoLegaleMetaPill(
                icona: "calendar",
                titolo: "Ultimo aggiornamento",
                valore: aggiornamento
            )

            DocumentoLegaleMetaPill(
                icona: "shield.checkered",
                titolo: "Ambito",
                valore: ambito
            )
        }
    }
}

private struct DocumentoLegaleMetaPill: View {
    let icona: String
    let titolo: String
    let valore: String

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: icona)
                .font(.system(size: 16, weight: .bold))
                .foregroundStyle(Color(hex: 0xB7DEFF))
                .frame(width: 34, height: 34)
                .background(
                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                        .fill(Color.white.opacity(0.08))
                )

            VStack(alignment: .leading, spacing: 4) {
                Text(titolo)
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(Color.white.opacity(0.62))
                Text(valore)
                    .font(.system(size: 15, weight: .bold, design: .rounded))
                    .foregroundStyle(.white)
                    .fixedSize(horizontal: false, vertical: true)
            }

            Spacer(minLength: 0)
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 22, style: .continuous)
                .fill(Color.white.opacity(0.05))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 22, style: .continuous)
                .stroke(Color.white.opacity(0.10), lineWidth: 1)
        )
    }
}

private struct DocumentoLegaleEvidenzaCard: View {
    let titolo: String
    let testo: String

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Label(titolo, systemImage: "exclamationmark.shield")
                .font(.system(size: 17, weight: .bold, design: .rounded))
                .foregroundStyle(Color(hex: 0xFFE39D))

            Text(testo)
                .font(.system(size: 14, weight: .medium))
                .foregroundStyle(Color.white.opacity(0.82))
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(18)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 24, style: .continuous)
                .fill(
                    LinearGradient(
                        colors: [
                            Color(hex: 0x5B3B0A).opacity(0.92),
                            Color(hex: 0x2B1D08).opacity(0.96)
                        ],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
        )
        .overlay(
            RoundedRectangle(cornerRadius: 24, style: .continuous)
                .stroke(Color(hex: 0xF0BF5A).opacity(0.30), lineWidth: 1)
        )
    }
}

private struct DocumentoLegaleSectionCard: View {
    let sezione: DocumentoLegaleSection

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text(sezione.titolo)
                .font(.system(size: 21, weight: .bold, design: .rounded))
                .foregroundStyle(.white)

            VStack(alignment: .leading, spacing: 12) {
                ForEach(Array(sezione.paragrafi.enumerated()), id: \.offset) { _, paragrafo in
                    Text(paragrafo)
                        .font(.system(size: 15, weight: .medium))
                        .foregroundStyle(Color.white.opacity(0.78))
                        .fixedSize(horizontal: false, vertical: true)
                        .multilineTextAlignment(.leading)
                }
            }
        }
        .padding(18)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 24, style: .continuous)
                .fill(
                    LinearGradient(
                        colors: [
                            Color(hex: 0x143C78).opacity(0.84),
                            Color(hex: 0x0E284E).opacity(0.94)
                        ],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
        )
        .overlay(
            RoundedRectangle(cornerRadius: 24, style: .continuous)
                .stroke(Color.white.opacity(0.10), lineWidth: 1)
        )
    }
}
