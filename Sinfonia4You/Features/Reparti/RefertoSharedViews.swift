//
//  RefertoSharedViews.swift
//  Sinfonia4You
//
//  Componenti condivisi per i flussi referti (direttore + assistenti).
//

import SwiftUI

struct RefertoFooterButton: View {
    let title: String
    let systemIcon: String
    let tint: Color
    var isDisabled: Bool = false
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 10) {
                Image(systemName: systemIcon)
                    .font(.system(size: 18, weight: .bold))
                Text(title)
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundStyle(.white)
            }
            .frame(maxWidth: .infinity, minHeight: 54)
            .padding(.horizontal, 14)
            .background(
                RoundedRectangle(cornerRadius: 18, style: .continuous)
                    .fill(
                        LinearGradient(
                            colors: isDisabled ? [Color.white.opacity(0.04), Color.white.opacity(0.04)] : [tint.opacity(0.95), tint.opacity(0.72)],
                            startPoint: .leading,
                            endPoint: .trailing
                        )
                    )
            )
            .overlay(
                RoundedRectangle(cornerRadius: 18, style: .continuous)
                    .stroke(Color.white.opacity(isDisabled ? 0.08 : 0.14), lineWidth: 1)
            )
            .opacity(isDisabled ? 0.52 : 1)
        }
        .buttonStyle(.plain)
        .disabled(isDisabled)
    }
}

struct RefertoSvolgimentoOptionView: View {
    let option: RefertoSvolgimentoOptionDTO
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(alignment: .top, spacing: 14) {
                Image(systemName: isSelected ? "largecircle.fill.circle" : "circle")
                    .font(.system(size: 20, weight: .semibold))
                    .foregroundStyle(isSelected ? Color(hex: 0xF4A62A) : Color.white.opacity(0.45))
                    .padding(.top, 4)

                VStack(alignment: .leading, spacing: 6) {
                    Text(option.title)
                        .font(.system(size: 20, weight: .bold, design: .rounded))
                        .foregroundStyle(isSelected ? Color(hex: 0xFFD37A) : .white)

                    if !option.description.isEmpty {
                        Text(option.description)
                            .font(.system(size: 14, weight: .medium))
                            .foregroundStyle(Color.white.opacity(0.72))
                            .fixedSize(horizontal: false, vertical: true)
                    }
                }
                Spacer(minLength: 0)
            }
            .padding(18)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(
                RoundedRectangle(cornerRadius: 20, style: .continuous)
                    .fill(
                        isSelected
                            ? Color(hex: 0xF4A62A).opacity(0.16)
                            : Color.white.opacity(0.04)
                    )
            )
            .overlay(
                RoundedRectangle(cornerRadius: 20, style: .continuous)
                    .stroke(
                        isSelected ? Color(hex: 0xF4A62A).opacity(0.92) : Color.white.opacity(0.10),
                        lineWidth: 1.2
                    )
            )
        }
        .buttonStyle(.plain)
    }
}

struct RefertoDirectorPlayerEditorView: View {
    let row: RefertoDirectorPlayerRowState
    let people: [RefertoPersonaDisponibileDTO]
    let documentOptions: [RefertoSelectOptionDTO]
    let accent: Color
    let onNumberChange: (String) -> Void
    let onPersonChange: (String) -> Void
    let onCaptainChange: (String) -> Void
    let onDocumentTypeChange: (String) -> Void
    let onDocumentNumberChange: (String) -> Void

    private let shirtNumbers = (1...99).map { String($0) }
    private let captainOptions = [
        RefertoSelectOptionDTO(value: "", title: "Nessuno"),
        RefertoSelectOptionDTO(value: "C", title: "Capitano"),
        RefertoSelectOptionDTO(value: "V", title: "Vice-capitano"),
    ]
    private var isComplete: Bool {
        !row.shirtNumber.isEmpty &&
        !row.personId.isEmpty &&
        !row.documentType.isEmpty &&
        !row.documentNumber.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }
    private var hasAnyValue: Bool {
        !row.shirtNumber.isEmpty ||
        !row.personId.isEmpty ||
        !row.captainCode.isEmpty ||
        !row.documentType.isEmpty ||
        !row.documentNumber.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }
    private var isIncomplete: Bool {
        hasAnyValue && !isComplete
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .center, spacing: 12) {
                Text("#\(row.order)")
                    .font(.system(size: 13, weight: .bold))
                    .foregroundStyle(accent)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 6)
                    .background(
                        Capsule(style: .continuous)
                            .fill(accent.opacity(0.14))
                    )

                if isIncomplete {
                    Text("Incompleto")
                        .font(.system(size: 11, weight: .bold))
                        .foregroundStyle(Color(hex: 0xFF8B8B))
                        .padding(.horizontal, 10)
                        .padding(.vertical, 6)
                        .background(
                            Capsule(style: .continuous)
                                .fill(Color(hex: 0xFF5D73).opacity(0.18))
                        )
                }

                RefertoInlineMenuField(
                    title: "Numero",
                    value: row.shirtNumber.isEmpty ? "Seleziona" : row.shirtNumber,
                    options: shirtNumbers.map { RefertoSelectOptionDTO(value: $0, title: $0) },
                    selected: row.shirtNumber,
                    onSelect: onNumberChange
                )

                RefertoInlineMenuField(
                    title: "Ruolo",
                    value: displayTitle(for: row.captainCode, in: captainOptions, empty: "Normale"),
                    options: captainOptions,
                    selected: row.captainCode,
                    onSelect: onCaptainChange
                )
            }

            RefertoInlineMenuField(
                title: "Calciatore",
                value: displayTitle(for: row.personId, in: people.map { RefertoSelectOptionDTO(value: $0.personId, title: $0.label) }, empty: "Seleziona tesserato"),
                options: people.map { RefertoSelectOptionDTO(value: $0.personId, title: $0.label) },
                selected: row.personId,
                onSelect: onPersonChange
            )

            HStack(spacing: 12) {
                RefertoInlineMenuField(
                    title: "Documento",
                    value: displayTitle(for: row.documentType, in: documentOptions, empty: "Tipo documento"),
                    options: documentOptions,
                    selected: row.documentType,
                    onSelect: onDocumentTypeChange
                )

                TextField("Numero documento", text: Binding(
                    get: { row.documentNumber },
                    set: { onDocumentNumberChange($0) }
                ))
                .textInputAutocapitalization(.characters)
                .autocorrectionDisabled()
                .font(.system(size: 15, weight: .medium))
                .foregroundStyle(.white)
                .padding(.horizontal, 14)
                .padding(.vertical, 12)
                .frame(maxWidth: .infinity)
                .background(
                    RoundedRectangle(cornerRadius: 16, style: .continuous)
                        .fill(Color.white.opacity(0.05))
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 16, style: .continuous)
                        .stroke(Color.white.opacity(0.10), lineWidth: 1)
                )
            }
        }
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .fill(isIncomplete ? Color(hex: 0x7D1F2A).opacity(0.18) : Color.white.opacity(0.03))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .stroke(isIncomplete ? Color(hex: 0xFF6B7C).opacity(0.92) : Color.white.opacity(0.08), lineWidth: 1)
        )
    }

    private func displayTitle(for value: String, in options: [RefertoSelectOptionDTO], empty: String) -> String {
        options.first(where: { $0.value == value })?.title ?? empty
    }
}

struct RefertoDirectorStaffEditorView: View {
    let row: RefertoDirectorStaffRowState
    let people: [RefertoPersonaDisponibileDTO]
    let roleOptions: [RefertoSelectOptionDTO]
    let documentOptions: [RefertoSelectOptionDTO]
    let onRoleChange: (String) -> Void
    let onPersonChange: (String) -> Void
    let onDocumentTypeChange: (String) -> Void
    let onDocumentNumberChange: (String) -> Void
    private var isComplete: Bool {
        !row.roleId.isEmpty &&
        !row.personId.isEmpty &&
        !row.documentType.isEmpty &&
        !row.documentNumber.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }
    private var hasAnyValue: Bool {
        !row.roleId.isEmpty ||
        !row.personId.isEmpty ||
        !row.documentType.isEmpty ||
        !row.documentNumber.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }
    private var isIncomplete: Bool {
        hasAnyValue && !isComplete
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 12) {
                Text("#\(row.order)")
                    .font(.system(size: 13, weight: .bold))
                    .foregroundStyle(Color(hex: 0x7BD389))
                    .padding(.horizontal, 10)
                    .padding(.vertical, 6)
                    .background(
                        Capsule(style: .continuous)
                            .fill(Color(hex: 0x7BD389).opacity(0.14))
                    )

                if isIncomplete {
                    Text("Incompleto")
                        .font(.system(size: 11, weight: .bold))
                        .foregroundStyle(Color(hex: 0xFF8B8B))
                        .padding(.horizontal, 10)
                        .padding(.vertical, 6)
                        .background(
                            Capsule(style: .continuous)
                                .fill(Color(hex: 0xFF5D73).opacity(0.18))
                        )
                }

                RefertoInlineMenuField(
                    title: "Ruolo",
                    value: roleOptions.first(where: { $0.value == row.roleId })?.title ?? "Seleziona ruolo",
                    options: roleOptions,
                    selected: row.roleId,
                    onSelect: onRoleChange
                )
            }

            RefertoInlineMenuField(
                title: "Persona",
                value: people.first(where: { $0.personId == row.personId })?.label ?? "Seleziona persona",
                options: people.map { RefertoSelectOptionDTO(value: $0.personId, title: $0.label) },
                selected: row.personId,
                onSelect: onPersonChange
            )

            HStack(spacing: 12) {
                RefertoInlineMenuField(
                    title: "Documento",
                    value: documentOptions.first(where: { $0.value == row.documentType })?.title ?? "Tipo documento",
                    options: documentOptions,
                    selected: row.documentType,
                    onSelect: onDocumentTypeChange
                )

                TextField("Numero documento", text: Binding(
                    get: { row.documentNumber },
                    set: { onDocumentNumberChange($0) }
                ))
                .textInputAutocapitalization(.characters)
                .autocorrectionDisabled()
                .font(.system(size: 15, weight: .medium))
                .foregroundStyle(.white)
                .padding(.horizontal, 14)
                .padding(.vertical, 12)
                .frame(maxWidth: .infinity)
                .background(
                    RoundedRectangle(cornerRadius: 16, style: .continuous)
                        .fill(Color.white.opacity(0.05))
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 16, style: .continuous)
                        .stroke(Color.white.opacity(0.10), lineWidth: 1)
                )
            }
        }
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .fill(isIncomplete ? Color(hex: 0x7D1F2A).opacity(0.18) : Color.white.opacity(0.03))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .stroke(isIncomplete ? Color(hex: 0xFF6B7C).opacity(0.92) : Color.white.opacity(0.08), lineWidth: 1)
        )
    }
}

struct RefertoDirectorDurataRowEditorView: View {
    let row: RefertoDirectorDurationRowState
    let options: [RefertoSelectOptionDTO]
    let accent: Color
    let canRemove: Bool
    let onTypeChange: (String) -> Void
    let onMinutesChange: (String) -> Void
    let onNoteChange: (String) -> Void
    let onRemove: () -> Void

    private var isIncomplete: Bool {
        row.durationType.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ||
        row.minutes.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    private var eventValue: String {
        options.first(where: { $0.value == row.durationType })?.title ?? "Seleziona evento"
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .center, spacing: 12) {
                Text(row.markerType == "I" ? "Intervallo" : "Evento \(row.order)")
                    .font(.system(size: 13, weight: .bold))
                    .foregroundStyle(accent)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 6)
                    .background(
                        Capsule(style: .continuous)
                            .fill(accent.opacity(0.14))
                    )

                if isIncomplete {
                    Text("Incompleto")
                        .font(.system(size: 11, weight: .bold))
                        .foregroundStyle(Color(hex: 0xFF8B8B))
                        .padding(.horizontal, 10)
                        .padding(.vertical, 6)
                        .background(
                            Capsule(style: .continuous)
                                .fill(Color(hex: 0xFF5D73).opacity(0.18))
                        )
                }

                Spacer(minLength: 8)

                if canRemove {
                    Button(action: onRemove) {
                        Label("Rimuovi", systemImage: "minus.circle.fill")
                    }
                    .buttonStyle(.plain)
                    .foregroundStyle(Color.white.opacity(0.72))
                }
            }

            RefertoInlineMenuField(
                title: "Tipo evento",
                value: eventValue,
                options: options,
                selected: row.durationType,
                onSelect: onTypeChange
            )

            HStack(spacing: 12) {
                TextField(
                    row.markerType == "I" ? "Minuti intervallo" : "Minuti",
                    text: Binding(
                        get: { row.minutes },
                        set: { onMinutesChange($0) }
                    )
                )
                .keyboardType(.numberPad)
                .font(.system(size: 15, weight: .medium))
                .foregroundStyle(.white)
                .padding(.horizontal, 14)
                .padding(.vertical, 12)
                .frame(maxWidth: .infinity)
                .background(
                    RoundedRectangle(cornerRadius: 16, style: .continuous)
                        .fill(Color.white.opacity(0.05))
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 16, style: .continuous)
                        .stroke(Color.white.opacity(0.10), lineWidth: 1)
                )

                VStack(alignment: .leading, spacing: 4) {
                    Text("INIZIO")
                        .font(.system(size: 10, weight: .bold))
                        .foregroundStyle(Color(hex: 0xA8D0FF))
                    Text(row.startTime.isEmpty ? "--:--" : row.startTime)
                        .font(.system(size: 16, weight: .bold, design: .rounded))
                        .foregroundStyle(.white)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.horizontal, 14)
                .padding(.vertical, 12)
                .background(
                    RoundedRectangle(cornerRadius: 16, style: .continuous)
                        .fill(Color.white.opacity(0.05))
                )

                VStack(alignment: .leading, spacing: 4) {
                    Text("FINE")
                        .font(.system(size: 10, weight: .bold))
                        .foregroundStyle(Color(hex: 0xA8D0FF))
                    Text(row.endTime.isEmpty ? "--:--" : row.endTime)
                        .font(.system(size: 16, weight: .bold, design: .rounded))
                        .foregroundStyle(.white)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.horizontal, 14)
                .padding(.vertical, 12)
                .background(
                    RoundedRectangle(cornerRadius: 16, style: .continuous)
                        .fill(Color.white.opacity(0.05))
                )
            }

            TextField(
                row.markerType == "I" ? "Note intervallo" : "Note evento",
                text: Binding(
                    get: { row.note },
                    set: { onNoteChange($0) }
                ),
                axis: .vertical
            )
            .lineLimit(2...4)
            .font(.system(size: 15, weight: .medium))
            .foregroundStyle(.white)
            .padding(.horizontal, 14)
            .padding(.vertical, 12)
            .frame(maxWidth: .infinity)
            .background(
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .fill(Color.white.opacity(0.05))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .stroke(Color.white.opacity(0.10), lineWidth: 1)
            )
        }
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .fill(isIncomplete ? Color(hex: 0x7D1F2A).opacity(0.18) : Color.white.opacity(0.03))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .stroke(isIncomplete ? Color(hex: 0xFF6B7C).opacity(0.92) : Color.white.opacity(0.08), lineWidth: 1)
        )
    }
}

let refertoSheetBackground = LinearGradient(
    colors: [
        Color(hex: 0x1A4F9B),
        Color(hex: 0x183B7D),
        Color(hex: 0x112A5E),
    ],
    startPoint: .topLeading,
    endPoint: .bottomTrailing
)

struct RefertoDirectorAddPersonSheetView: View {
    let teamName: String
    @Binding var draft: RefertoManualPersonDraftState
    let isLoading: Bool
    let onCancel: () -> Void
    let onSubmit: () -> Void

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 18) {
                    VStack(alignment: .leading, spacing: 6) {
                        Text(teamName.isEmpty ? "Nuova persona squadra" : teamName)
                            .font(.system(size: 24, weight: .bold, design: .rounded))
                            .foregroundStyle(.white)

                        Text("Inserisci una persona mancante nell'archivio della squadra. Dopo il salvataggio sarà selezionabile tra titolari, panchina e dirigenti.")
                            .font(.system(size: 14, weight: .medium))
                            .foregroundStyle(Color.white.opacity(0.72))
                            .fixedSize(horizontal: false, vertical: true)
                    }

                    HStack(spacing: 12) {
                        formTextField(title: "Matricola", placeholder: "Opzionale", text: $draft.matricola, keyboard: .numberPad)
                        sexPicker
                    }

                    HStack(spacing: 12) {
                        formTextField(title: "Cognome", placeholder: "Obbligatorio", text: $draft.lastName)
                        formTextField(title: "Nome", placeholder: "Obbligatorio", text: $draft.firstName)
                    }

                    HStack(spacing: 12) {
                        formTextField(title: "Data di nascita", placeholder: "GG/MM/AAAA", text: $draft.birthDate, keyboard: .numbersAndPunctuation)
                        formTextField(title: "Codice fiscale", placeholder: "Opzionale", text: $draft.taxCode)
                    }

                    HStack(spacing: 12) {
                        formTextField(title: "Codice comune", placeholder: "Opzionale", text: $draft.birthPlaceCode)
                        formTextField(title: "Luogo di nascita", placeholder: "Opzionale", text: $draft.birthPlaceLabel)
                    }

                    Text("Sinfonia4You salva obbligatoriamente cognome, nome e data di nascita. Luogo di nascita, matricola e codice fiscale restano facoltativi in questo passaggio.")
                        .font(.system(size: 13, weight: .medium))
                        .foregroundStyle(Color.white.opacity(0.60))
                }
                .padding(20)
            }
            .background(refertoSheetBackground.ignoresSafeArea())
            .navigationTitle("Aggiungi persona")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Annulla", action: onCancel)
                        .foregroundStyle(.white)
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button(isLoading ? "Salvataggio..." : "Conferma", action: onSubmit)
                        .disabled(isLoading)
                }
            }
        }
        .sinfoniaNavigationRoot()
    }

    private var sexPicker: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("SESSO")
                .font(.system(size: 11, weight: .bold))
                .foregroundStyle(Color.white.opacity(0.50))

            Picker("Sesso", selection: $draft.sex) {
                Text("Maschile").tag("M")
                Text("Femminile").tag("F")
            }
            .pickerStyle(.segmented)
            .padding(10)
            .background(
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .fill(Color.white.opacity(0.05))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .stroke(Color.white.opacity(0.10), lineWidth: 1)
            )
        }
        .frame(maxWidth: .infinity)
    }

    private func formTextField(
        title: String,
        placeholder: String,
        text: Binding<String>,
        keyboard: UIKeyboardType = .default
    ) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(title.uppercased())
                .font(.system(size: 11, weight: .bold))
                .foregroundStyle(Color.white.opacity(0.50))

            TextField(placeholder, text: text)
                .keyboardType(keyboard)
                .textInputAutocapitalization(.characters)
                .autocorrectionDisabled()
                .font(.system(size: 15, weight: .medium))
                .foregroundStyle(.white)
                .padding(.horizontal, 14)
                .padding(.vertical, 12)
                .frame(maxWidth: .infinity)
                .background(
                    RoundedRectangle(cornerRadius: 16, style: .continuous)
                        .fill(Color.white.opacity(0.05))
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 16, style: .continuous)
                        .stroke(Color.white.opacity(0.10), lineWidth: 1)
                )
        }
        .frame(maxWidth: .infinity)
    }
}

struct RefertoDirectorRemovePersonSheetView: View {
    let teamName: String
    let people: [RefertoPersonaDisponibileDTO]
    @Binding var selectedPersonId: String
    let isLoading: Bool
    let onCancel: () -> Void
    let onConfirm: () -> Void

    var body: some View {
        NavigationStack {
            VStack(alignment: .leading, spacing: 18) {
                Text(teamName.isEmpty ? "Seleziona la persona da rimuovere" : "Rimuovi persona da \(teamName)")
                    .font(.system(size: 24, weight: .bold, design: .rounded))
                    .foregroundStyle(.white)

                Text("La persona verrà storicizzata come su Sinfonia4You e non sarà più disponibile nelle liste di questa squadra.")
                    .font(.system(size: 14, weight: .medium))
                    .foregroundStyle(Color.white.opacity(0.72))
                    .fixedSize(horizontal: false, vertical: true)

                RefertoInlineMenuField(
                    title: "Persona",
                    value: people.first(where: { $0.personId == selectedPersonId })?.label ?? "Seleziona persona",
                    options: people.map { RefertoSelectOptionDTO(value: $0.personId, title: $0.label) },
                    selected: selectedPersonId,
                    onSelect: { selectedPersonId = $0 }
                )

                Text("Se la persona è già usata in titolari, panchina o dirigenti, il portale la rimuove dalla disponibilità della squadra e la riga viene svuotata.")
                    .font(.system(size: 13, weight: .medium))
                    .foregroundStyle(Color.white.opacity(0.60))

                Spacer(minLength: 0)
            }
            .padding(20)
            .background(refertoSheetBackground.ignoresSafeArea())
            .navigationTitle("Rimuovi persona")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Annulla", action: onCancel)
                        .foregroundStyle(.white)
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button(isLoading ? "Rimozione..." : "Conferma", action: onConfirm)
                        .disabled(isLoading || selectedPersonId.isEmpty)
                }
            }
        }
        .sinfoniaNavigationRoot()
    }
}

struct RefertoInlineMenuField: View {
    let title: String
    let value: String
    let options: [RefertoSelectOptionDTO]
    let selected: String
    let onSelect: (String) -> Void

    var body: some View {
        Menu {
            ForEach(options) { option in
                Button {
                    onSelect(option.value)
                } label: {
                    HStack {
                        Text(option.title)
                        if option.value == selected {
                            Spacer()
                            Image(systemName: "checkmark")
                        }
                    }
                }
            }
        } label: {
            VStack(alignment: .leading, spacing: 6) {
                Text(title.uppercased())
                    .font(.system(size: 11, weight: .bold))
                    .foregroundStyle(Color.white.opacity(0.50))
                HStack {
                    Text(value)
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundStyle(.white)
                        .lineLimit(1)
                    Spacer(minLength: 8)
                    Image(systemName: "chevron.down")
                        .font(.system(size: 12, weight: .bold))
                        .foregroundStyle(Color.white.opacity(0.56))
                }
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 12)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .fill(Color.white.opacity(0.05))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .stroke(Color.white.opacity(0.10), lineWidth: 1)
            )
        }
        .buttonStyle(.plain)
    }
}

struct RefertoAnteprimaInvioView: View {
    let dettaglio: DettaglioRefertoDTO
    let segnalazioneValue: String
    let noteText: String

    private var ufficialeCorrente: [String: String]? {
        let targetRole = testoRipulitoPerUI(dettaglio.item.activity).uppercased()
        if let directMatch = dettaglio.officials.first(where: {
            testoRipulitoPerUI($0["Ruolo"] ?? "").uppercased() == targetRole
        }) {
            return directMatch
        }

        if dettaglio.roleKind == "assistant" {
            return dettaglio.officials.first(where: {
                testoRipulitoPerUI($0["Ruolo"] ?? "").uppercased().hasPrefix("AA")
            })
        }

        return dettaglio.officials.first
    }

    private var previewBodyText: String {
        let cleanNote = testoRipulitoPerUI(noteText)
        if segnalazioneValue == "2" {
            return cleanNote.isEmpty ? "Nessun testo inserito." : cleanNote
        }
        return "NIENTE DA SEGNALARE"
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text("Anteprima invio")
                .font(.system(size: 21, weight: .semibold, design: .rounded))
                .foregroundStyle(.white)

            Text("Controlla i dati del rapporto prima di inviarlo in modo definitivo.")
                .font(.system(size: 14, weight: .medium))
                .foregroundStyle(Color.white.opacity(0.74))

            if let ufficialeCorrente {
                HStack(spacing: 12) {
                    RefertoAnteprimaCampoView(
                        titolo: "Nome",
                        valore: testoRipulitoPerUI(ufficialeCorrente["Nome"] ?? "")
                    )
                    RefertoAnteprimaCampoView(
                        titolo: "Cognome",
                        valore: testoRipulitoPerUI(ufficialeCorrente["Cognome"] ?? "")
                    )
                    RefertoAnteprimaCampoView(
                        titolo: "Sezione",
                        valore: testoRipulitoPerUI(ufficialeCorrente["Sezione"] ?? "")
                    )
                }
            }

            BloccoTestoView(
                titolo: dettaglio.segnalazioneTitle.isEmpty ? "Segnalazione" : dettaglio.segnalazioneTitle,
                testo: segnalazioneValue == "2" ? "Segnalazione eventi" : "Nulla da segnalare"
            )

            BloccoTestoView(
                titolo: dettaglio.noteTitle.isEmpty ? "Testo della segnalazione" : dettaglio.noteTitle,
                testo: previewBodyText
            )
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 22, style: .continuous)
                .fill(Color(hex: 0x14386E).opacity(0.52))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 22, style: .continuous)
                .stroke(Color(hex: 0x6EA8FF).opacity(0.28), lineWidth: 1)
        )
    }
}

struct RefertoAnteprimaCampoView: View {
    let titolo: String
    let valore: String

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(titolo.uppercased())
                .font(.system(size: 10, weight: .bold))
                .foregroundStyle(Color(hex: 0xA8D0FF))

            Text(valore.isEmpty ? "-" : valore)
                .font(.system(size: 15, weight: .bold, design: .rounded))
                .foregroundStyle(.white)
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .fill(Color.white.opacity(0.05))
        )
    }
}
