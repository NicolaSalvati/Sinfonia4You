import SwiftUI

struct VistaImpostazioniDashboard: View {
    @State private var mostraConfermaLogout = false
    @ObservedObject private var promemoriaStore = PromemoriaGareStore.shared
    @ObservedObject var authViewModel: AuthViewModel
    let onRequireLogout: () -> Void
    private let documentiLegali = DocumentoLegaleKind.allCases

    private let moduloAccount = RepartoSintesiDTO(
        id: "account",
        title: "Account",
        subtitle: "Cambio password e sicurezza dell'accesso",
        systemIcon: "lock.rotation"
    )

    var body: some View {
        ZStack {
            SfondoSezioniAppView()
                .ignoresSafeArea()

            ScrollView(showsIndicators: false) {
                VStack(alignment: .leading, spacing: 18) {
                    CardTitoloView(
                        titolo: "Impostazioni",
                        sottotitolo: "Gestisci l'accesso rapido con biometria e le impostazioni del tuo account."
                    )

                    ImpostazioniSectionCard(
                        titolo: "Accesso rapido",
                        sottotitolo: "Usa la biometria di iPhone per entrare più velocemente nell'app."
                    ) {
                        Toggle(isOn: biometricBinding) {
                            HStack(spacing: 12) {
                                Image(systemName: authViewModel.biometricIconName)
                                    .font(.system(size: 22, weight: .semibold))
                                    .foregroundStyle(Color(hex: 0xB7DEFF))
                                    .frame(width: 28)

                                VStack(alignment: .leading, spacing: 4) {
                                    Text("Accedi con \(authViewModel.biometricDisplayName)")
                                        .font(.system(size: 17, weight: .bold, design: .rounded))
                                        .foregroundStyle(.white)
                                    Text(authViewModel.biometricHint)
                                        .font(.system(size: 13, weight: .medium))
                                        .foregroundStyle(Color.white.opacity(0.68))
                                        .fixedSize(horizontal: false, vertical: true)
                                }
                            }
                        }
                        .toggleStyle(SwitchToggleStyle(tint: Color(hex: 0x2E7BE0)))
                        .disabled(authViewModel.inCaricamento || (!authViewModel.biometricSupported && !authViewModel.biometricEnabled))
                        .padding(16)
                        .background(
                            RoundedRectangle(cornerRadius: 20, style: .continuous)
                                .fill(Color.white.opacity(0.05))
                        )
                        .overlay(
                            RoundedRectangle(cornerRadius: 20, style: .continuous)
                                .stroke(Color.white.opacity(0.10), lineWidth: 1)
                        )

                        if !authViewModel.biometricMessage.isEmpty {
                            BloccoTestoView(titolo: "Sicurezza", testo: authViewModel.biometricMessage)
                        }

                        if authViewModel.biometricEnabled {
                            BloccoTestoView(
                                titolo: "Come funziona",
                                testo: "Le credenziali vengono salvate nel Portachiavi protetto di iPhone e sbloccate solo con \(authViewModel.biometricDisplayName). Se cambi password, esegui un login manuale e poi aggiorna questa opzione."
                            )
                        }
                    }

                    ImpostazioniSectionCard(
                        titolo: "Notifiche gara",
                        sottotitolo: "Promemoria locali sul dispositivo per ricordarti la gara del giorno alle 09:00."
                    ) {
                        Toggle(isOn: promemoriaBinding) {
                            HStack(spacing: 12) {
                                Image(systemName: "calendar.badge.clock")
                                    .font(.system(size: 22, weight: .semibold))
                                    .foregroundStyle(Color(hex: 0xB7DEFF))
                                    .frame(width: 28)

                                VStack(alignment: .leading, spacing: 4) {
                                    Text("Promemoria gara del giorno")
                                        .font(.system(size: 17, weight: .bold, design: .rounded))
                                        .foregroundStyle(.white)
                                    Text("Alle 09:00 ricevi un promemoria locale con squadre, orario e competizione della gara prevista per la giornata.")
                                        .font(.system(size: 13, weight: .medium))
                                        .foregroundStyle(Color.white.opacity(0.68))
                                        .fixedSize(horizontal: false, vertical: true)
                                }
                            }
                        }
                        .toggleStyle(SwitchToggleStyle(tint: Color(hex: 0x2E7BE0)))
                        .padding(16)
                        .background(
                            RoundedRectangle(cornerRadius: 20, style: .continuous)
                                .fill(Color.white.opacity(0.05))
                        )
                        .overlay(
                            RoundedRectangle(cornerRadius: 20, style: .continuous)
                                .stroke(Color.white.opacity(0.10), lineWidth: 1)
                        )

                        BloccoTestoView(
                            titolo: "Privacy",
                            testo: "Il promemoria viene generato in locale sul tuo iPhone usando le designazioni già scaricate dall'app. Nessuna credenziale aggiuntiva viene salvata sul server."
                        )
                    }

                    ImpostazioniSectionCard(
                        titolo: "Note legali",
                        sottotitolo: "Consulta termini dell'app, condizioni d'uso e informativa dettagliata su privacy e dati."
                    ) {
                        ForEach(documentiLegali) { documento in
                            NavigationLink {
                                VistaDocumentoLegale(kind: documento)
                            } label: {
                                ImpostazioniNavigationCard(
                                    icona: documento.icona,
                                    titolo: documento.titolo,
                                    sottotitolo: documento.sottotitoloMenu
                                )
                            }
                            .buttonStyle(.plain)
                        }

                        BloccoTestoView(
                            titolo: "Trasparenza",
                            testo: "Questi documenti descrivono in modo dettagliato come l'app gestisce accesso, biometria, notifiche locali, cache, dati operativi e responsabilità dell'utente. I testi sono pensati per dare piena chiarezza prima e durante l'uso dell'app."
                        )
                    }

                    ImpostazioniSectionCard(
                        titolo: "Account e sicurezza",
                        sottotitolo: "Gestisci password, credenziali del profilo e uscita da questo dispositivo."
                    ) {
                        NavigationLink(value: moduloAccount) {
                            ImpostazioniNavigationCard(
                                icona: "lock.rotation",
                                titolo: "Account",
                                sottotitolo: "Cambio password, credenziali e sicurezza del profilo"
                            )
                        }
                        .buttonStyle(.plain)

                        logoutActionCard
                            .padding(.top, 10)
                    }
                }
                .padding(.horizontal, 18)
                .padding(.top, 18)
                .padding(.bottom, 126)
            }
        }
        .task {
            authViewModel.refreshBiometricState()
        }
        .alert("Conferma uscita", isPresented: $mostraConfermaLogout) {
            Button("Annulla", role: .cancel) {}
            Button("Esci", role: .destructive) {
                onRequireLogout()
            }
        } message: {
            Text("Vuoi davvero uscire dalla sessione su questo dispositivo?")
        }
    }

    private var biometricBinding: Binding<Bool> {
        Binding(
            get: { authViewModel.biometricEnabled },
            set: { newValue in
                Task {
                    if newValue {
                        await authViewModel.enableBiometricLogin()
                    } else {
                        authViewModel.disableBiometricLogin()
                    }
                }
            }
        )
    }

    private var promemoriaBinding: Binding<Bool> {
        Binding(
            get: { promemoriaStore.remindersEnabled },
            set: { newValue in
                Task {
                    await promemoriaStore.setEnabled(newValue)
                    if newValue, let sessione = authViewModel.sessione {
                        await promemoriaStore.sync(
                            token: sessione.token,
                            userIdentifier: sessione.profile.code
                        )
                    }
                }
            }
        )
    }

    private var logoutActionCard: some View {
        Button {
            mostraConfermaLogout = true
        } label: {
            HStack(alignment: .center, spacing: 14) {
                ZStack {
                    RoundedRectangle(cornerRadius: 16, style: .continuous)
                        .fill(Color(hex: 0xD8A0A8).opacity(0.14))
                        .frame(width: 46, height: 46)

                    Image(systemName: "rectangle.portrait.and.arrow.right")
                        .font(.system(size: 18, weight: .bold))
                        .foregroundStyle(Color(hex: 0xFFECEF))
                }

                VStack(alignment: .leading, spacing: 5) {
                    Text("Esci dalla sessione")
                        .font(.system(size: 17, weight: .bold, design: .rounded))
                        .foregroundStyle(.white)

                    Text("Chiudi l'accesso su questo iPhone e torna subito alla schermata login.")
                        .font(.system(size: 13, weight: .medium))
                        .foregroundStyle(Color.white.opacity(0.76))
                        .fixedSize(horizontal: false, vertical: true)
                }

                Spacer(minLength: 0)

                Text("Logout")
                    .font(.system(size: 11, weight: .bold))
                    .textCase(.uppercase)
                    .foregroundStyle(Color(hex: 0xF7E4E7))
                    .padding(.horizontal, 10)
                    .padding(.vertical, 7)
                    .background(
                        Capsule(style: .continuous)
                            .fill(Color(hex: 0xD8A0A8).opacity(0.12))
                    )
                    .overlay(
                        Capsule(style: .continuous)
                            .stroke(Color(hex: 0xE2B9BF).opacity(0.22), lineWidth: 1)
                    )
            }
            .padding(18)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(
                RoundedRectangle(cornerRadius: 22, style: .continuous)
                    .fill(
                        LinearGradient(
                            colors: [
                                Color(hex: 0x17365F).opacity(0.90),
                                Color(hex: 0x102746).opacity(0.94)
                            ],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
            )
            .overlay(alignment: .leading) {
                RoundedRectangle(cornerRadius: 4, style: .continuous)
                    .fill(
                        LinearGradient(
                            colors: [
                                Color(hex: 0xD8A0A8).opacity(0.85),
                                Color(hex: 0xE7C1C7).opacity(0.50)
                            ],
                            startPoint: .top,
                            endPoint: .bottom
                        )
                    )
                    .frame(width: 4)
                    .padding(.vertical, 16)
                    .padding(.leading, 10)
            }
            .overlay(
                RoundedRectangle(cornerRadius: 22, style: .continuous)
                    .stroke(Color.white.opacity(0.10), lineWidth: 1)
            )
            .shadow(color: Color.black.opacity(0.10), radius: 12, y: 6)
        }
        .buttonStyle(.plain)
    }
}

struct SfondoSezioniAppView: View {
    var body: some View {
        ZStack {
            LinearGradient(
                colors: [
                    Color(hex: 0x0A1E4D),
                    Color(hex: 0x0C2A63),
                    Color(hex: 0x081735)
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )

            RadialGradient(
                colors: [
                    Color(hex: 0x2E7BE0).opacity(0.24),
                    .clear
                ],
                center: .topTrailing,
                startRadius: 24,
                endRadius: 420
            )

            RadialGradient(
                colors: [
                    Color(hex: 0x1A94FF).opacity(0.15),
                    .clear
                ],
                center: .bottomLeading,
                startRadius: 18,
                endRadius: 340
            )

            RadialGradient(
                colors: [
                    Color(hex: 0x5F9DFF).opacity(0.08),
                    .clear
                ],
                center: .center,
                startRadius: 30,
                endRadius: 360
            )
        }
    }
}

private struct ImpostazioniSectionCard<Content: View>: View {
    let titolo: String
    let sottotitolo: String
    let content: Content

    init(
        titolo: String,
        sottotitolo: String,
        @ViewBuilder content: () -> Content
    ) {
        self.titolo = titolo
        self.sottotitolo = sottotitolo
        self.content = content()
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            VStack(alignment: .leading, spacing: 4) {
                Text(titolo)
                    .font(.system(size: 22, weight: .bold, design: .rounded))
                    .foregroundStyle(.white)
                Text(sottotitolo)
                    .font(.system(size: 14, weight: .medium))
                    .foregroundStyle(Color.white.opacity(0.68))
                    .fixedSize(horizontal: false, vertical: true)
            }

            content
        }
        .padding(18)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 26, style: .continuous)
                .fill(
                    LinearGradient(
                        colors: [
                            Color(hex: 0x143C78).opacity(0.88),
                            Color(hex: 0x0E284E).opacity(0.94)
                        ],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
        )
        .overlay(
            RoundedRectangle(cornerRadius: 26, style: .continuous)
                .stroke(Color.white.opacity(0.10), lineWidth: 1)
        )
    }
}

private struct ImpostazioniNavigationCard: View {
    let icona: String
    let titolo: String
    let sottotitolo: String

    var body: some View {
        HStack(spacing: 14) {
            Image(systemName: icona)
                .font(.system(size: 20, weight: .semibold))
                .foregroundStyle(Color(hex: 0xB7DEFF))
                .frame(width: 40, height: 40)
                .background(
                    RoundedRectangle(cornerRadius: 14, style: .continuous)
                        .fill(Color.white.opacity(0.08))
                )

            VStack(alignment: .leading, spacing: 4) {
                Text(titolo)
                    .font(.system(size: 17, weight: .bold, design: .rounded))
                    .foregroundStyle(.white)
                Text(sottotitolo)
                    .font(.system(size: 13, weight: .medium))
                    .foregroundStyle(Color.white.opacity(0.68))
                    .fixedSize(horizontal: false, vertical: true)
            }

            Spacer(minLength: 0)

            Image(systemName: "chevron.right")
                .font(.system(size: 13, weight: .bold))
                .foregroundStyle(Color(hex: 0x9DD7FF))
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .fill(Color.white.opacity(0.05))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .stroke(Color.white.opacity(0.10), lineWidth: 1)
        )
    }
}
