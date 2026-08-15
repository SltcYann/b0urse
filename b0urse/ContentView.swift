import AppKit
import SwiftUI

struct Abonnement: Codable, Equatable, Identifiable {
    let id: UUID
    var nom: String
    var prix: String
    var emoji: String

    init(id: UUID = UUID(), nom: String = "", prix: String = "", emoji: String = "📦") {
        self.id = id
        self.nom = nom
        self.prix = prix
        self.emoji = emoji
    }

    private enum CodingKeys: String, CodingKey {
        case id
        case nom = "name"
        case prix = "price"
        case emoji
    }
}

struct DepensePonctuelle: Codable, Equatable, Identifiable {
    let id: UUID
    var nom: String
    var montant: String
    var emoji: String

    init(id: UUID = UUID(), nom: String = "", montant: String = "", emoji: String = "🧾") {
        self.id = id
        self.nom = nom
        self.montant = montant
        self.emoji = emoji
    }

    private enum CodingKeys: String, CodingKey {
        case id
        case nom = "name"
        case montant = "amount"
        case emoji
    }
}

struct ContentView: View {
    @State private var abonnements = LocalStorage.load(
        [Abonnement].self,
        forKey: LocalStorage.cleAbonnements
    ) ?? []
    @State private var abonnementModifie: Abonnement?
    @State private var depensesPonctuelles = LocalStorage.load(
        [DepensePonctuelle].self,
        forKey: LocalStorage.cleDepensesPonctuelles
    ) ?? []
    @State private var depenseModifiee: DepensePonctuelle?
    @AppStorage("scholarshipTier") private var echelonBourse: EchelonBourse = .echelon7

    private var bourseMensuelle: Double {
        echelonBourse.montantMensuel
    }

    private var totalAbonnements: Double {
        abonnements.reduce(0) { $0 + montant(depuis: $1.prix) }
    }

    private var totalDepensesPonctuelles: Double {
        depensesPonctuelles.reduce(0) { $0 + montant(depuis: $1.montant) }
    }

    private var montantRestant: Double {
        max(bourseMensuelle - totalAbonnements - totalDepensesPonctuelles, 0)
    }

    private var pourcentageRestant: Double {
        guard bourseMensuelle > 0 else { return 0 }
        return min(montantRestant / bourseMensuelle, 1)
    }

    private var niveauSolde: NiveauSolde {
        NiveauSolde(pourcentage: pourcentageRestant)
    }

    var body: some View {
        NavigationStack {
            ZStack {
                AppBackground(niveauSolde: niveauSolde)

                VStack(spacing: 20) {
                    SuiviBourse(
                        echelonBourse: $echelonBourse,
                        montantRestant: montantRestant,
                        pourcentageRestant: pourcentageRestant,
                        niveauSolde: niveauSolde
                    )
                    .padding(.horizontal, 24)
                    .padding(.top, 24)

                    ScrollView {
                        HStack(alignment: .top, spacing: 54) {
                            VStack(alignment: .leading, spacing: 14) {
                                Text("Abonnements")
                                    .font(.title2.weight(.semibold))

                                AddEntryButton(accessibilityLabel: "Ajouter un abonnement") {
                                    abonnementModifie = Abonnement()
                                }

                                ForEach(abonnements) { abonnement in
                                    Button {
                                        abonnementModifie = abonnement
                                    } label: {
                                        LigneAbonnement(abonnement: abonnement)
                                    }
                                    .buttonStyle(.plain)
                                    .glassEffect(
                                        .regular.interactive(),
                                        in: RoundedRectangle(cornerRadius: 20)
                                    )
                                }
                            }
                            .frame(maxWidth: .infinity, alignment: .leading)

                            Capsule()
                                .frame(width: 6)
                                .frame(maxHeight: .infinity)
                                .glassEffect(.regular, in: Capsule())

                            VStack(alignment: .leading, spacing: 14) {
                                Text("Dépenses ponctuelles")
                                    .font(.title2.weight(.semibold))

                                AddEntryButton(accessibilityLabel: "Ajouter une dépense ponctuelle") {
                                    depenseModifiee = DepensePonctuelle()
                                }

                                ForEach(depensesPonctuelles) { depense in
                                    Button {
                                        depenseModifiee = depense
                                    } label: {
                                        LigneDepensePonctuelle(depense: depense)
                                    }
                                    .buttonStyle(.plain)
                                    .glassEffect(
                                        .regular.interactive(),
                                        in: RoundedRectangle(cornerRadius: 20)
                                    )
                                }
                            }
                            .frame(maxWidth: .infinity, alignment: .leading)
                        }
                        .frame(minHeight: 240, alignment: .top)
                        .animation(
                            .smooth(duration: 0.5),
                            value: abonnements.count + depensesPonctuelles.count
                        )
                        .padding(.horizontal, 24)
                        .padding(.top, 24)
                        .padding(.bottom, 24)
                    }
                    .scrollIndicators(.hidden)
                    .mask {
                        VStack(spacing: 0) {
                            LinearGradient(
                                colors: [.clear, .black],
                                startPoint: .top,
                                endPoint: .bottom
                            )
                            .frame(height: 20)

                            Rectangle()
                                .fill(.black)
                        }
                    }
                }
            }
            .sheet(item: $abonnementModifie) { abonnement in
                EditeurAbonnement(
                    abonnement: abonnement,
                    estNouveau: !abonnements.contains { $0.id == abonnement.id },
                    niveauSolde: niveauSolde
                ) { abonnementMisAJour in
                    enregistrer(abonnementMisAJour)
                } lorsSuppression: {
                    abonnements.removeAll { $0.id == abonnement.id }
                }
            }
            .sheet(item: $depenseModifiee) { depense in
                EditeurDepensePonctuelle(
                    depense: depense,
                    estNouveau: !depensesPonctuelles.contains { $0.id == depense.id },
                    niveauSolde: niveauSolde
                ) { depenseMiseAJour in
                    enregistrer(depenseMiseAJour)
                } lorsSuppression: {
                    depensesPonctuelles.removeAll { $0.id == depense.id }
                }
            }
            .onChange(of: abonnements) { _, nouveauxAbonnements in
                LocalStorage.save(nouveauxAbonnements, forKey: LocalStorage.cleAbonnements)
            }
            .onChange(of: depensesPonctuelles) { _, nouvellesDepenses in
                LocalStorage.save(nouvellesDepenses, forKey: LocalStorage.cleDepensesPonctuelles)
            }
        }
    }

    private func enregistrer(_ abonnement: Abonnement) {
        if let indice = abonnements.firstIndex(where: { $0.id == abonnement.id }) {
            abonnements[indice] = abonnement
        } else {
            abonnements.append(abonnement)
        }
    }

    private func enregistrer(_ depense: DepensePonctuelle) {
        if let indice = depensesPonctuelles.firstIndex(where: { $0.id == depense.id }) {
            depensesPonctuelles[indice] = depense
        } else {
            depensesPonctuelles.append(depense)
        }
    }

    private func montant(depuis texte: String) -> Double {
        Double(texte.replacingOccurrences(of: ",", with: ".")) ?? 0
    }
}

private enum LocalStorage {
    static let cleAbonnements = "subscriptions"
    static let cleDepensesPonctuelles = "oneTimeExpenses"
    private static let decoder = JSONDecoder()
    private static let encoder = JSONEncoder()

    static func load<Value: Decodable>(_ type: Value.Type, forKey key: String) -> Value? {
        guard let data = UserDefaults.standard.data(forKey: key) else { return nil }
        return try? decoder.decode(type, from: data)
    }

    static func save<Value: Encodable>(_ value: Value, forKey key: String) {
        guard let data = try? encoder.encode(value) else { return }
        UserDefaults.standard.set(data, forKey: key)
    }
}

private struct SuiviBourse: View {
    @Binding var echelonBourse: EchelonBourse
    @State private var selectionEchelonAffichee = false

    let montantRestant: Double
    let pourcentageRestant: Double
    let niveauSolde: NiveauSolde

    private var couleurEtat: Color {
        niveauSolde.couleur
    }

    var body: some View {
        VStack(spacing: 12) {
            HStack {
                Spacer()

                Button {
                    selectionEchelonAffichee.toggle()
                } label: {
                    HStack(spacing: 10) {
                        Text(echelonBourse.titreSelection)
                            .lineLimit(1)

                        Image(systemName: "chevron.down")
                            .font(.caption2.weight(.semibold))
                            .foregroundStyle(.secondary)
                    }
                }
                .buttonStyle(.glass)
                .fixedSize()
                .accessibilityLabel("Échelon de bourse")
                .popover(isPresented: $selectionEchelonAffichee, arrowEdge: .bottom) {
                    VStack(alignment: .leading, spacing: 4) {
                        ForEach(EchelonBourse.allCases) { echelon in
                            Button {
                                echelonBourse = echelon
                                selectionEchelonAffichee = false
                            } label: {
                                HStack {
                                    Text(echelon.titreSelection)

                                    Spacer()

                                    if echelonBourse == echelon {
                                        Image(systemName: "checkmark")
                                    }
                                }
                                .contentShape(.rect)
                            }
                            .buttonStyle(.plain)
                            .padding(.horizontal, 10)
                            .padding(.vertical, 7)
                        }
                    }
                    .padding(8)
                    .frame(minWidth: 290)
                }
            }

            ZStack(alignment: .bottom) {
                HalfCircle()
                    .stroke(.white.opacity(0.2), style: StrokeStyle(lineWidth: 18, lineCap: .round))

                HalfCircle()
                    .trim(from: 0, to: max(pourcentageRestant, 0.001))
                    .stroke(couleurEtat, style: StrokeStyle(lineWidth: 18, lineCap: .round))
                    .opacity(pourcentageRestant == 0 ? 0 : 1)
                    .animation(.smooth(duration: 0.7), value: pourcentageRestant)

                VStack(spacing: 2) {
                    Text(pourcentageRestant, format: .percent.precision(.fractionLength(0)))
                        .font(.system(size: 38, weight: .bold, design: .rounded))
                        .foregroundStyle(couleurEtat)
                        .contentTransition(.numericText(value: pourcentageRestant))
                    Text("\(montantRestant, format: .number.precision(.fractionLength(2))) € restants")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
                .padding(.bottom, 4)
            }
            .frame(maxWidth: 320)
            .frame(height: 180)
            .animation(.easeInOut(duration: 0.45), value: couleurEtat)
        }
        .padding(22)
        .glassEffect(.regular, in: RoundedRectangle(cornerRadius: 28))
    }
}

private enum EchelonBourse: String, CaseIterable, Codable, Identifiable {
    case aucun = "none"
    case echelon0Bis = "level0Bis"
    case echelon1 = "level1"
    case echelon2 = "level2"
    case echelon3 = "level3"
    case echelon4 = "level4"
    case echelon5 = "level5"
    case echelon6 = "level6"
    case echelon7 = "level7"

    var id: Self { self }

    var montantAnnuel: Double {
        switch self {
        case .aucun:
            0
        case .echelon0Bis:
            1_454
        case .echelon1:
            2_163
        case .echelon2:
            3_071
        case .echelon3:
            3_828
        case .echelon4:
            4_587
        case .echelon5:
            5_212
        case .echelon6:
            5_506
        case .echelon7:
            6_335
        }
    }

    var montantMensuel: Double {
        montantAnnuel / 10
    }

    var nom: String {
        switch self {
        case .aucun:
            "Pas de bourse"
        case .echelon0Bis:
            "Échelon 0 bis"
        case .echelon1:
            "Échelon 1"
        case .echelon2:
            "Échelon 2"
        case .echelon3:
            "Échelon 3"
        case .echelon4:
            "Échelon 4"
        case .echelon5:
            "Échelon 5"
        case .echelon6:
            "Échelon 6"
        case .echelon7:
            "Échelon 7"
        }
    }

    var titreSelection: String {
        guard self != .aucun else { return nom }
        return "\(nom) · \(montantMensuel.formatted(.currency(code: "EUR"))) / mois"
    }
}

private enum NiveauSolde: Equatable {
    case confortable
    case alerte
    case critique

    init(pourcentage: Double) {
        if pourcentage > 0.5 {
            self = .confortable
        } else if pourcentage > 0.2 {
            self = .alerte
        } else {
            self = .critique
        }
    }

    var couleur: Color {
        switch self {
        case .confortable:
            .green
        case .alerte:
            .orange
        case .critique:
            .red
        }
    }
}

private struct HalfCircle: Shape {
    func path(in rect: CGRect) -> Path {
        let radius = min(rect.width / 2, rect.height)
        let center = CGPoint(x: rect.midX, y: rect.maxY)

        var path = Path()
        path.addArc(
            center: center,
            radius: radius,
            startAngle: .degrees(180),
            endAngle: .degrees(0),
            clockwise: false
        )
        return path
    }
}

private struct AppBackground: View {
    var niveauSolde: NiveauSolde = .confortable

    private var colors: [Color] {
        switch niveauSolde {
        case .confortable:
            [.indigo.opacity(0.4), .green.opacity(0.3), .cyan.opacity(0.25)]
        case .alerte:
            [.indigo.opacity(0.4), .orange.opacity(0.35), .yellow.opacity(0.2)]
        case .critique:
            [.purple.opacity(0.4), .red.opacity(0.35), .orange.opacity(0.2)]
        }
    }

    var body: some View {
        LinearGradient(
            colors: colors,
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
        .ignoresSafeArea()
        .animation(.easeInOut(duration: 0.9), value: niveauSolde)
    }
}

private struct AddEntryButton: View {
    let accessibilityLabel: LocalizedStringKey
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Image(systemName: "plus")
                .font(.system(size: 34, weight: .medium))
                .frame(width: 84, height: 84)
                .contentShape(RoundedRectangle(cornerRadius: 18))
                .glassEffect(
                    .regular.interactive(),
                    in: RoundedRectangle(cornerRadius: 18)
                )
        }
        .buttonStyle(.plain)
        .accessibilityLabel(accessibilityLabel)
    }
}

private struct LigneAbonnement: View {
    let abonnement: Abonnement

    var body: some View {
        HStack(spacing: 12) {
            Text(abonnement.emoji)
                .font(.title)

            Text(abonnement.nom)
                .font(.headline)

            Spacer()

            Text(abonnement.prix.isEmpty ? "—" : "\(abonnement.prix) €")
                .foregroundStyle(.secondary)
        }
        .contentShape(.rect)
        .padding(18)
    }
}

private struct LigneDepensePonctuelle: View {
    let depense: DepensePonctuelle

    var body: some View {
        HStack(spacing: 12) {
            Text(depense.emoji)
                .font(.title)

            Text(depense.nom)
                .font(.headline)

            Spacer()

            Text(depense.montant.isEmpty ? "—" : "\(depense.montant) €")
                .foregroundStyle(.secondary)
        }
        .contentShape(.rect)
        .padding(18)
    }
}

private struct EditeurAbonnement: View {
    @Environment(\.dismiss) private var fermer
    @State private var abonnement: Abonnement

    let estNouveau: Bool
    let niveauSolde: NiveauSolde
    let lorsEnregistrement: (Abonnement) -> Void
    let lorsSuppression: () -> Void

    init(
        abonnement: Abonnement,
        estNouveau: Bool,
        niveauSolde: NiveauSolde,
        lorsEnregistrement: @escaping (Abonnement) -> Void,
        lorsSuppression: @escaping () -> Void
    ) {
        _abonnement = State(initialValue: abonnement)
        self.estNouveau = estNouveau
        self.niveauSolde = niveauSolde
        self.lorsEnregistrement = lorsEnregistrement
        self.lorsSuppression = lorsSuppression
    }

    var body: some View {
        ZStack {
            AppBackground(niveauSolde: niveauSolde)

            VStack(spacing: 22) {
                Text(estNouveau ? "Nouvel abonnement" : "Modifier l’abonnement")
                    .font(.title.bold())

                EmojiField(text: $abonnement.emoji)

                GlassTextField(title: "Nom", text: $abonnement.nom)
                GlassTextField(title: "Prix mensuel", text: $abonnement.prix, suffix: "€")

                HStack(spacing: 12) {
                    if !estNouveau {
                        Button {
                            lorsSuppression()
                            fermer()
                        } label: {
                            Image(systemName: "trash")
                                .font(.title3)
                        }
                        .buttonStyle(.glass)
                        .accessibilityLabel("Supprimer l’abonnement")
                    }

                    Button("Annuler") {
                        fermer()
                    }
                    .buttonStyle(.glass)

                    Button("Enregistrer") {
                        lorsEnregistrement(abonnement)
                        fermer()
                    }
                    .buttonStyle(.glass)
                    .disabled(abonnement.nom.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                }
            }
            .padding(32)
            .frame(maxWidth: 520)
            .glassEffect(.regular, in: RoundedRectangle(cornerRadius: 32))
            .padding(32)
        }
        .frame(minWidth: 560, minHeight: 580)
    }
}

private struct EditeurDepensePonctuelle: View {
    @Environment(\.dismiss) private var fermer
    @State private var depense: DepensePonctuelle

    let estNouveau: Bool
    let niveauSolde: NiveauSolde
    let lorsEnregistrement: (DepensePonctuelle) -> Void
    let lorsSuppression: () -> Void

    init(
        depense: DepensePonctuelle,
        estNouveau: Bool,
        niveauSolde: NiveauSolde,
        lorsEnregistrement: @escaping (DepensePonctuelle) -> Void,
        lorsSuppression: @escaping () -> Void
    ) {
        _depense = State(initialValue: depense)
        self.estNouveau = estNouveau
        self.niveauSolde = niveauSolde
        self.lorsEnregistrement = lorsEnregistrement
        self.lorsSuppression = lorsSuppression
    }

    var body: some View {
        ZStack {
            AppBackground(niveauSolde: niveauSolde)

            VStack(spacing: 22) {
                Text(estNouveau ? "Nouvelle dépense" : "Modifier la dépense")
                    .font(.title.bold())

                EmojiField(text: $depense.emoji)

                GlassTextField(title: "Nom", text: $depense.nom)
                GlassTextField(title: "Montant", text: $depense.montant)

                HStack(spacing: 12) {
                    if !estNouveau {
                        Button {
                            lorsSuppression()
                            fermer()
                        } label: {
                            Image(systemName: "trash")
                                .font(.title3)
                        }
                        .buttonStyle(.glass)
                        .accessibilityLabel("Supprimer la dépense")
                    }

                    Button("Annuler") {
                        fermer()
                    }
                    .buttonStyle(.glass)

                    Button("Enregistrer") {
                        lorsEnregistrement(depense)
                        fermer()
                    }
                    .buttonStyle(.glass)
                    .disabled(depense.nom.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                }
            }
            .padding(32)
            .frame(maxWidth: 520)
            .glassEffect(.regular, in: RoundedRectangle(cornerRadius: 32))
            .padding(32)
        }
        .frame(minWidth: 560, minHeight: 580)
    }
}

private struct EmojiField: View {
    @Binding var text: String
    @State private var emojiInput = ""
    @FocusState private var isEmojiInputFocused: Bool

    var body: some View {
        Button {
            emojiInput = ""
            isEmojiInputFocused = true

            Task { @MainActor in
                NSApplication.shared.orderFrontCharacterPalette(nil)
            }
        } label: {
            Text(text.isEmpty ? "😀" : text)
                .font(.system(size: 52))
                .frame(width: 132, height: 132)
                .contentShape(RoundedRectangle(cornerRadius: 28))
                .glassEffect(.regular.interactive(), in: RoundedRectangle(cornerRadius: 28))
        }
        .buttonStyle(.plain)
        .accessibilityLabel("Choisir un émoji")
        .overlay {
            TextField("", text: $emojiInput)
                .textFieldStyle(.plain)
                .focused($isEmojiInputFocused)
                .frame(width: 1, height: 1)
                .opacity(0.001)
                .allowsHitTesting(false)
                .onChange(of: emojiInput) { _, newValue in
                    guard !newValue.isEmpty else { return }
                    text = newValue
                    isEmojiInputFocused = false
                }
        }
    }
}

private struct GlassTextField: View {
    let title: LocalizedStringKey
    @Binding var text: String
    let suffix: String?

    init(title: LocalizedStringKey, text: Binding<String>, suffix: String? = nil) {
        self.title = title
        _text = text
        self.suffix = suffix
    }

    var body: some View {
        HStack(spacing: 8) {
            TextField(title, text: $text)
                .textFieldStyle(.plain)
                .multilineTextAlignment(.center)

            if let suffix {
                Text(suffix)
                    .foregroundStyle(.secondary)
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .frame(maxWidth: 420)
        .glassEffect(.regular.interactive(), in: RoundedRectangle(cornerRadius: 14))
    }
}

#Preview {
    ContentView()
}
