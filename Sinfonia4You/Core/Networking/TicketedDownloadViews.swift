import SwiftUI

/// Apre una risorsa protetta del backend senza mai esporre il token di
/// sessione nella URL.
///
/// `Link`, `AsyncImage` e QuickLook non permettono di allegare l'header
/// `Authorization`: la soluzione precedente era mettere il token di sessione in
/// query string, dove finiva nei log del server e restava valido per ore.
/// Qui la URL viene costruita al momento del tocco, con un ticket monouso che
/// scade in pochi secondi.
///
/// Sostituisce `Link(destination:)`. Il ticket non viene messo in cache:
/// essendo monouso, riutilizzarlo produrrebbe un errore al secondo tentativo.
struct TicketedDownloadLink<Label: View>: View {
    let provider: () async -> URL?
    @ViewBuilder let label: () -> Label

    @Environment(\.openURL) private var openURL
    @State private var inCorso = false
    @State private var mostraErrore = false

    var body: some View {
        Button {
            guard !inCorso else { return }
            inCorso = true
            Task {
                let url = await provider()
                await MainActor.run {
                    inCorso = false
                    if let url {
                        openURL(url)
                    } else {
                        mostraErrore = true
                    }
                }
            }
        } label: {
            label()
                .opacity(inCorso ? 0.45 : 1)
        }
        .buttonStyle(.plain)
        .disabled(inCorso)
        .alert("Download non riuscito", isPresented: $mostraErrore) {
            Button("Ok", role: .cancel) {}
        } message: {
            Text("Non e' stato possibile preparare il file. Riprova tra qualche istante.")
        }
    }
}
