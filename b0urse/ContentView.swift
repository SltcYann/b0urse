import Observation
import SwiftUI

struct ContentView: View {
    @State private var budgetStore = BudgetStore()
    @State private var isPresentingBursaryForm = false
    @State private var isPresentingIncomeForm = false
    @State private var isPresentingSubscriptionForm = false
    @State private var isPresentingExpenseForm = false

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 28) {
                    BursaryBalanceCard(
                        bursaryAmount: budgetStore.monthlyBursaryAmount,
                        otherIncomeAmount: budgetStore.additionalIncomeAmount,
                        subscriptionCost: budgetStore.monthlySubscriptionCost,
                        expenseCost: budgetStore.oneTimeExpenseCost
                    )

                    BursaryIncomeButton(
                        emoji: budgetStore.bursaryEmoji,
                        levelName: budgetStore.bursaryLevel.displayName,
                        amount: budgetStore.monthlyBursaryAmount,
                        action: { isPresentingBursaryForm = true }
                    )

                    AdditionalIncomeSection(
                        incomes: budgetStore.additionalIncomes,
                        addIncome: { isPresentingIncomeForm = true },
                        onDelete: budgetStore.deleteAdditionalIncome
                    )

                    SubscriptionSection(
                        subscriptions: budgetStore.subscriptions,
                        addSubscription: { isPresentingSubscriptionForm = true },
                        addExpense: { isPresentingExpenseForm = true },
                        onDelete: budgetStore.deleteSubscription
                    )

                    if !budgetStore.oneTimeExpenses.isEmpty {
                        OneTimeExpenseSection(
                            expenses: budgetStore.oneTimeExpenses,
                            onDelete: budgetStore.deleteOneTimeExpense
                        )
                    }
                }
                .padding(24)
            }
            .toolbar(removing: .title)
            .sheet(isPresented: $isPresentingBursaryForm) {
                BursaryFormView(
                    bursaryLevel: budgetStore.bursaryLevel,
                    emoji: budgetStore.bursaryEmoji
                ) { level, emoji in
                    budgetStore.updateBursary(level: level, emoji: emoji)
                }
            }
            .sheet(isPresented: $isPresentingIncomeForm) {
                AddIncomeView { name, amount, emoji in
                    budgetStore.addAdditionalIncome(name: name, amount: amount, emoji: emoji)
                }
            }
            .sheet(isPresented: $isPresentingSubscriptionForm) {
                AddSubscriptionView { name, price, emoji in
                    budgetStore.addSubscription(name: name, price: price, emoji: emoji)
                }
            }
            .sheet(isPresented: $isPresentingExpenseForm) {
                AddOneTimeExpenseView { name, amount, emoji in
                    budgetStore.addOneTimeExpense(name: name, amount: amount, emoji: emoji)
                }
            }
        }
    }
}

private struct BursaryBalanceCard: View {
    let bursaryAmount: Double
    let otherIncomeAmount: Double
    let subscriptionCost: Double
    let expenseCost: Double

    private var availableIncome: Double {
        bursaryAmount + otherIncomeAmount
    }

    private var remainingAmount: Double {
        availableIncome - subscriptionCost - expenseCost
    }

    private var status: BalanceStatus {
        BalanceStatus(remainingAmount: remainingAmount, availableIncome: availableIncome)
    }

    var body: some View {
        GlassEffectContainer {
            VStack(spacing: 16) {
                Text("Argent restant")
                    .font(.headline)
                    .foregroundStyle(.secondary)

                BalanceGauge(
                    remainingAmount: remainingAmount,
                    availableIncome: availableIncome,
                    color: status.color
                )
                .frame(maxWidth: 320)
                .frame(height: 180)

                Text(remainingAmount, format: .currency(code: "EUR"))
                    .font(.system(.largeTitle, design: .rounded, weight: .bold))
                    .foregroundStyle(status.color)

                Text(status.message)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)

                Grid(alignment: .leading, horizontalSpacing: 20, verticalSpacing: 8) {
                    GridRow {
                        SummaryMetric(title: "Bourse", amount: bursaryAmount)
                        SummaryMetric(title: "Autres revenus", amount: otherIncomeAmount)
                        SummaryMetric(title: "Dépenses", amount: subscriptionCost + expenseCost)
                    }
                }
                .padding(.top, 4)
            }
            .padding(28)
            .frame(maxWidth: .infinity)
            .glassEffect(.regular.tint(status.color.opacity(0.15)), in: .rect(cornerRadius: 28))
        }
    }
}

private struct BalanceGauge: View {
    let remainingAmount: Double
    let availableIncome: Double
    let color: Color

    private var progress: Double {
        guard availableIncome > 0 else { return 0 }
        return min(max(remainingAmount / availableIncome, 0), 1)
    }

    var body: some View {
        ZStack(alignment: .bottom) {
            HalfCircle()
                .stroke(.quaternary, style: StrokeStyle(lineWidth: 22, lineCap: .round))

            HalfCircle()
                .trim(from: 0, to: progress)
                .stroke(color, style: StrokeStyle(lineWidth: 22, lineCap: .round))
                .animation(.smooth, value: progress)

            VStack(spacing: 4) {
                Text("après tes dépenses")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Text("\(Int(progress * 100)) %")
                    .font(.system(.title, design: .rounded, weight: .bold))
            }
            .padding(.bottom, 4)
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Il reste \(remainingAmount.formatted(.currency(code: "EUR"))) sur tes revenus")
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

private struct SummaryMetric: View {
    let title: LocalizedStringResource
    let amount: Double

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(title)
                .font(.caption)
                .foregroundStyle(.secondary)
            Text(amount, format: .currency(code: "EUR"))
                .font(.subheadline.weight(.semibold))
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

private struct BursaryIncomeButton: View {
    let emoji: String
    let levelName: LocalizedStringResource
    let amount: Double
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 12) {
                EmojiIcon(emoji: emoji, tint: .accentColor)

                VStack(alignment: .leading, spacing: 2) {
                    Text("Bourse reçue")
                        .font(.body.weight(.medium))
                    Text(levelName)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                Spacer()

                Text(amount, format: .currency(code: "EUR"))
                    .font(.headline)

                Image(systemName: "chevron.right")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.tertiary)
            }
            .padding(16)
        }
        .buttonStyle(.plain)
        .glassEffect(.regular.interactive(), in: .rect(cornerRadius: 18))
        .accessibilityLabel("Bourse reçue, \(amount.formatted(.currency(code: "EUR")))")
    }
}

private struct AdditionalIncomeSection: View {
    let incomes: [AdditionalIncome]
    let addIncome: () -> Void
    let onDelete: (AdditionalIncome) -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            SectionHeader(
                title: "Autres revenus",
                actionLabel: "Ajouter un revenu",
                action: addIncome
            )

            if incomes.isEmpty {
                Button(action: addIncome) {
                    Label("Ajouter un revenu", systemImage: "plus")
                        .font(.subheadline.weight(.medium))
                        .padding(.vertical, 4)
                }
                .buttonStyle(.glass)
            } else {
                GlassEffectContainer(spacing: 12) {
                    VStack(spacing: 12) {
                        ForEach(incomes) { income in
                            IncomeRow(
                                income: income,
                                onDelete: { onDelete(income) }
                            )
                            .glassEffect(in: .rect(cornerRadius: 18))
                        }
                    }
                }
            }
        }
    }
}

private struct SubscriptionSection: View {
    let subscriptions: [Subscription]
    let addSubscription: () -> Void
    let addExpense: () -> Void
    let onDelete: (Subscription) -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            SectionHeader(
                title: "Mes abonnements",
                actionLabel: "Ajouter une entrée",
                menuAction: AddEntryMenu(
                    addSubscription: addSubscription,
                    addExpense: addExpense
                )
            )

            if subscriptions.isEmpty {
                ContentUnavailableView(
                    "Pas encore d’abonnement",
                    systemImage: "repeat",
                    description: Text("Utilise le bouton + pour ajouter un abonnement ou une dépense ponctuelle.")
                )
                .frame(maxWidth: .infinity)
                .padding(.vertical, 28)
                .glassEffect(in: .rect(cornerRadius: 24))
            } else {
                GlassEffectContainer(spacing: 12) {
                    VStack(spacing: 12) {
                        ForEach(subscriptions) { subscription in
                            SubscriptionRow(
                                subscription: subscription,
                                onDelete: { onDelete(subscription) }
                            )
                            .glassEffect(in: .rect(cornerRadius: 18))
                        }
                    }
                }
            }
        }
    }
}

private struct AddEntryMenu: View {
    let addSubscription: () -> Void
    let addExpense: () -> Void

    var body: some View {
        Menu {
            Button(action: addSubscription) {
                Label("Ajouter un abonnement", systemImage: "repeat")
            }

            Button(action: addExpense) {
                Label("Ajouter une dépense ponctuelle", systemImage: "creditcard")
            }
        } label: {
            Image(systemName: "plus")
                .font(.headline.weight(.semibold))
                .frame(width: 40, height: 36)
                .glassEffect(.regular.interactive(), in: .rect(cornerRadius: 12))
        }
        .accessibilityLabel("Ajouter une entrée")
        .accessibilityHint("Choisis un abonnement ou une dépense ponctuelle")
    }
}

private struct OneTimeExpenseSection: View {
    let expenses: [OneTimeExpense]
    let onDelete: (OneTimeExpense) -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            SectionHeader(title: "Dépenses ponctuelles")

            GlassEffectContainer(spacing: 12) {
                VStack(spacing: 12) {
                    ForEach(expenses) { expense in
                        OneTimeExpenseRow(
                            expense: expense,
                            onDelete: { onDelete(expense) }
                        )
                        .glassEffect(in: .rect(cornerRadius: 18))
                    }
                }
            }
        }
    }
}

private struct SectionHeader: View {
    let title: LocalizedStringResource
    let actionLabel: LocalizedStringResource?
    let action: (() -> Void)?
    let menuAction: AddEntryMenu?

    init(title: LocalizedStringResource) {
        self.title = title
        actionLabel = nil
        action = nil
        menuAction = nil
    }

    init(title: LocalizedStringResource, actionLabel: LocalizedStringResource, action: @escaping () -> Void) {
        self.title = title
        self.actionLabel = actionLabel
        self.action = action
        menuAction = nil
    }

    init(title: LocalizedStringResource, actionLabel: LocalizedStringResource, menuAction: AddEntryMenu) {
        self.title = title
        self.actionLabel = actionLabel
        action = nil
        self.menuAction = menuAction
    }

    var body: some View {
        HStack {
            Text(title)
                .font(.title3.weight(.semibold))

            Spacer()

            if let menuAction {
                menuAction
            } else if let action, let actionLabel {
                Button(action: action) {
                    Label(actionLabel, systemImage: "plus")
                }
                .buttonStyle(.plain)
                .accessibilityLabel(actionLabel)
            }
        }
    }
}

private struct EmojiIcon: View {
    let emoji: String
    let tint: Color

    var body: some View {
        Text(emoji)
            .font(.title3)
            .frame(width: 32, height: 32)
            .background(tint.opacity(0.15), in: Circle())
            .accessibilityHidden(true)
    }
}

private struct IncomeRow: View {
    let income: AdditionalIncome
    let onDelete: () -> Void

    var body: some View {
        HStack(spacing: 12) {
            EmojiIcon(emoji: income.emoji, tint: .green)

            Text(income.name)
                .font(.body.weight(.medium))

            Spacer()

            Text(income.amount, format: .currency(code: "EUR"))
                .font(.headline)

            DeleteButton(name: income.name, action: onDelete)
        }
        .padding(16)
    }
}

private struct SubscriptionRow: View {
    let subscription: Subscription
    let onDelete: () -> Void

    var body: some View {
        HStack(spacing: 12) {
            EmojiIcon(emoji: subscription.emoji, tint: .accentColor)

            Text(subscription.name)
                .font(.body.weight(.medium))

            Spacer()

            Text(subscription.price, format: .currency(code: "EUR"))
                .font(.headline)

            DeleteButton(name: subscription.name, action: onDelete)
        }
        .padding(16)
    }
}

private struct OneTimeExpenseRow: View {
    let expense: OneTimeExpense
    let onDelete: () -> Void

    var body: some View {
        HStack(spacing: 12) {
            EmojiIcon(emoji: expense.emoji, tint: .orange)

            Text(expense.name)
                .font(.body.weight(.medium))

            Spacer()

            Text(expense.amount, format: .currency(code: "EUR"))
                .font(.headline)

            DeleteButton(name: expense.name, action: onDelete)
        }
        .padding(16)
    }
}

private struct DeleteButton: View {
    let name: String
    let action: () -> Void

    var body: some View {
        Button(role: .destructive, action: action) {
            Image(systemName: "trash")
        }
        .buttonStyle(.plain)
        .accessibilityLabel("Supprimer \(name)")
    }
}

private struct BursaryFormView: View {
    @Environment(\.dismiss) private var dismiss

    @State private var bursaryLevel: BursaryLevel
    @State private var emoji: String
    let onSave: (BursaryLevel, String) -> Void

    init(
        bursaryLevel: BursaryLevel,
        emoji: String,
        onSave: @escaping (BursaryLevel, String) -> Void
    ) {
        _bursaryLevel = State(initialValue: bursaryLevel)
        _emoji = State(initialValue: emoji)
        self.onSave = onSave
    }

    var body: some View {
        NavigationStack {
            Form {
                Section("Bourse Crous 2026-2027") {
                    Picker("Échelon", selection: $bursaryLevel) {
                        ForEach(BursaryLevel.allCases) { level in
                            Text(level.pickerTitle)
                                .tag(level)
                        }
                    }
                    .pickerStyle(.menu)

                    TextField("Emoji", text: $emoji)
                }

                Section {
                    Text(bursaryLevel.explanation)
                }
            }
            .navigationTitle("Bourse reçue")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Annuler") {
                        dismiss()
                    }
                }

                ToolbarItem(placement: .confirmationAction) {
                    Button("Enregistrer") {
                        onSave(bursaryLevel, emoji.normalizedEmoji(or: "🎓"))
                        dismiss()
                    }
                }
            }
        }
    }
}

private struct AddIncomeView: View {
    @Environment(\.dismiss) private var dismiss

    @State private var name = ""
    @State private var amount = 0.0
    @State private var emoji = "💶"

    let onSave: (String, Double, String) -> Void

    private var trimmedName: String {
        name.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    var body: some View {
        NavigationStack {
            Form {
                Section("Revenu complémentaire") {
                    TextField("Nom", text: $name)
                    TextField("Montant", value: $amount, format: .currency(code: "EUR"))
                    TextField("Emoji", text: $emoji)
                }
            }
            .navigationTitle("Nouveau revenu")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Annuler") {
                        dismiss()
                    }
                }

                ToolbarItem(placement: .confirmationAction) {
                    Button("Ajouter") {
                        onSave(trimmedName, amount, emoji.normalizedEmoji(or: "💶"))
                        dismiss()
                    }
                    .disabled(trimmedName.isEmpty || amount <= 0)
                }
            }
        }
    }
}

private struct AddSubscriptionView: View {
    @Environment(\.dismiss) private var dismiss

    @State private var name = ""
    @State private var price = 0.0
    @State private var emoji = "🔁"

    let onSave: (String, Double, String) -> Void

    private var trimmedName: String {
        name.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    var body: some View {
        NavigationStack {
            Form {
                Section("Abonnement mensuel") {
                    TextField("Nom", text: $name)
                    TextField("Prix", value: $price, format: .currency(code: "EUR"))
                    TextField("Emoji", text: $emoji)
                }
            }
            .navigationTitle("Nouvel abonnement")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Annuler") {
                        dismiss()
                    }
                }

                ToolbarItem(placement: .confirmationAction) {
                    Button("Ajouter") {
                        onSave(trimmedName, price, emoji.normalizedEmoji(or: "🔁"))
                        dismiss()
                    }
                    .disabled(trimmedName.isEmpty || price <= 0)
                }
            }
        }
    }
}

private struct AddOneTimeExpenseView: View {
    @Environment(\.dismiss) private var dismiss

    @State private var name = ""
    @State private var amount = 0.0
    @State private var emoji = "🧾"

    let onSave: (String, Double, String) -> Void

    private var trimmedName: String {
        name.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    var body: some View {
        NavigationStack {
            Form {
                Section("Dépense ponctuelle") {
                    TextField("Nom", text: $name)
                    TextField("Montant", value: $amount, format: .currency(code: "EUR"))
                    TextField("Emoji", text: $emoji)
                }
            }
            .navigationTitle("Nouvelle dépense")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Annuler") {
                        dismiss()
                    }
                }

                ToolbarItem(placement: .confirmationAction) {
                    Button("Ajouter") {
                        onSave(trimmedName, amount, emoji.normalizedEmoji(or: "🧾"))
                        dismiss()
                    }
                    .disabled(trimmedName.isEmpty || amount <= 0)
                }
            }
        }
    }
}

@MainActor
@Observable
private final class BudgetStore {
    private enum StorageKey {
        static let bursaryLevel = "bursaryLevel"
        static let bursaryEmoji = "bursaryEmoji"
        static let subscriptions = "subscriptions"
        static let additionalIncomes = "additionalIncomes"
        static let oneTimeExpenses = "oneTimeExpenses"
    }

    var bursaryLevel: BursaryLevel {
        didSet {
            UserDefaults.standard.set(bursaryLevel.rawValue, forKey: StorageKey.bursaryLevel)
        }
    }

    var bursaryEmoji: String {
        didSet {
            UserDefaults.standard.set(bursaryEmoji, forKey: StorageKey.bursaryEmoji)
        }
    }

    private(set) var subscriptions: [Subscription] {
        didSet {
            persist(subscriptions, forKey: StorageKey.subscriptions)
        }
    }

    private(set) var additionalIncomes: [AdditionalIncome] {
        didSet {
            persist(additionalIncomes, forKey: StorageKey.additionalIncomes)
        }
    }

    private(set) var oneTimeExpenses: [OneTimeExpense] {
        didSet {
            persist(oneTimeExpenses, forKey: StorageKey.oneTimeExpenses)
        }
    }

    private(set) var monthlySubscriptionCost = 0.0
    private(set) var additionalIncomeAmount = 0.0
    private(set) var oneTimeExpenseCost = 0.0

    var monthlyBursaryAmount: Double {
        bursaryLevel.monthlyAmount
    }

    init() {
        bursaryLevel = BursaryLevel(
            rawValue: UserDefaults.standard.string(forKey: StorageKey.bursaryLevel) ?? ""
        ) ?? .none
        bursaryEmoji = UserDefaults.standard.string(forKey: StorageKey.bursaryEmoji) ?? "🎓"
        subscriptions = Self.load(Subscription.self, forKey: StorageKey.subscriptions)
        additionalIncomes = Self.load(AdditionalIncome.self, forKey: StorageKey.additionalIncomes)
        oneTimeExpenses = Self.load(OneTimeExpense.self, forKey: StorageKey.oneTimeExpenses)
        recomputeCosts()
    }

    func updateBursary(level: BursaryLevel, emoji: String) {
        bursaryLevel = level
        bursaryEmoji = emoji
    }

    func addAdditionalIncome(name: String, amount: Double, emoji: String) {
        additionalIncomes.append(AdditionalIncome(id: UUID(), name: name, amount: amount, emoji: emoji))
        recomputeCosts()
    }

    func addSubscription(name: String, price: Double, emoji: String) {
        subscriptions.append(Subscription(id: UUID(), name: name, price: price, emoji: emoji))
        recomputeCosts()
    }

    func addOneTimeExpense(name: String, amount: Double, emoji: String) {
        oneTimeExpenses.append(OneTimeExpense(id: UUID(), name: name, amount: amount, emoji: emoji))
        recomputeCosts()
    }

    func deleteAdditionalIncome(_ income: AdditionalIncome) {
        additionalIncomes.removeAll { $0.id == income.id }
        recomputeCosts()
    }

    func deleteSubscription(_ subscription: Subscription) {
        subscriptions.removeAll { $0.id == subscription.id }
        recomputeCosts()
    }

    func deleteOneTimeExpense(_ expense: OneTimeExpense) {
        oneTimeExpenses.removeAll { $0.id == expense.id }
        recomputeCosts()
    }

    private func recomputeCosts() {
        monthlySubscriptionCost = subscriptions.reduce(0) { $0 + $1.price }
        additionalIncomeAmount = additionalIncomes.reduce(0) { $0 + $1.amount }
        oneTimeExpenseCost = oneTimeExpenses.reduce(0) { $0 + $1.amount }
    }

    private func persist<T: Encodable>(_ value: T, forKey key: String) {
        guard let data = try? JSONEncoder().encode(value) else { return }
        UserDefaults.standard.set(data, forKey: key)
    }

    private static func load<T: Decodable>(_ type: T.Type, forKey key: String) -> [T] {
        guard
            let data = UserDefaults.standard.data(forKey: key),
            let values = try? JSONDecoder().decode([T].self, from: data)
        else {
            return []
        }

        return values
    }
}

private enum BursaryLevel: String, CaseIterable, Codable, Identifiable {
    case none
    case level0bis
    case level1
    case level2
    case level3
    case level4
    case level5
    case level6
    case level7

    var id: Self { self }

    var annualAmount: Double {
        switch self {
        case .none:
            0
        case .level0bis:
            1_454
        case .level1:
            2_163
        case .level2:
            3_071
        case .level3:
            3_828
        case .level4:
            4_587
        case .level5:
            5_212
        case .level6:
            5_506
        case .level7:
            6_335
        }
    }

    var monthlyAmount: Double {
        annualAmount / 10
    }

    var displayName: LocalizedStringResource {
        switch self {
        case .none:
            "Aucun échelon sélectionné"
        case .level0bis:
            "Échelon 0 bis"
        default:
            LocalizedStringResource("Échelon \(rawValue.replacingOccurrences(of: "level", with: ""))")
        }
    }

    var pickerTitle: LocalizedStringResource {
        if self == .none {
            return "Aucune bourse"
        }

        return "\(displayName) — \(monthlyAmount.formatted(.currency(code: "EUR"))) / mois"
    }

    var explanation: LocalizedStringResource {
        if self == .none {
            return "Sélectionne ton échelon pour ajouter ta bourse mensuelle au budget."
        }

        return "Montant 2026-2027 : \(annualAmount.formatted(.currency(code: "EUR"))) sur dix mois, soit \(monthlyAmount.formatted(.currency(code: "EUR"))) par mois."
    }
}

private struct AdditionalIncome: Codable, Equatable, Identifiable {
    let id: UUID
    let name: String
    let amount: Double
    let emoji: String

    init(id: UUID, name: String, amount: Double, emoji: String) {
        self.id = id
        self.name = name
        self.amount = amount
        self.emoji = emoji
    }

    private enum CodingKeys: String, CodingKey {
        case id, name, amount, emoji
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(UUID.self, forKey: .id)
        name = try container.decode(String.self, forKey: .name)
        amount = try container.decode(Double.self, forKey: .amount)
        emoji = try container.decodeIfPresent(String.self, forKey: .emoji) ?? "💶"
    }
}

private struct Subscription: Codable, Equatable, Identifiable {
    let id: UUID
    let name: String
    let price: Double
    let emoji: String

    init(id: UUID, name: String, price: Double, emoji: String) {
        self.id = id
        self.name = name
        self.price = price
        self.emoji = emoji
    }

    private enum CodingKeys: String, CodingKey {
        case id, name, price, emoji
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(UUID.self, forKey: .id)
        name = try container.decode(String.self, forKey: .name)
        price = try container.decode(Double.self, forKey: .price)
        emoji = try container.decodeIfPresent(String.self, forKey: .emoji) ?? "🔁"
    }
}

private struct OneTimeExpense: Codable, Equatable, Identifiable {
    let id: UUID
    let name: String
    let amount: Double
    let emoji: String

    init(id: UUID, name: String, amount: Double, emoji: String) {
        self.id = id
        self.name = name
        self.amount = amount
        self.emoji = emoji
    }

    private enum CodingKeys: String, CodingKey {
        case id, name, amount, emoji
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(UUID.self, forKey: .id)
        name = try container.decode(String.self, forKey: .name)
        amount = try container.decode(Double.self, forKey: .amount)
        emoji = try container.decodeIfPresent(String.self, forKey: .emoji) ?? "🧾"
    }
}

private struct BalanceStatus {
    let remainingAmount: Double
    let availableIncome: Double

    var color: Color {
        if remainingAmount <= 0 || availableIncome <= 0 {
            return .red
        }

        return remainingAmount / availableIncome <= 0.25 ? .orange : .green
    }

    var message: LocalizedStringResource {
        if remainingAmount <= 0 || availableIncome <= 0 {
            return "Tu n’as plus de budget disponible."
        }

        if remainingAmount / availableIncome <= 0.25 {
            return "Ton budget commence à être serré."
        }

        return "Ton budget est confortable."
    }
}

private extension String {
    func normalizedEmoji(or fallback: String) -> String {
        trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            ? fallback
            : trimmingCharacters(in: .whitespacesAndNewlines)
    }
}

#Preview {
    ContentView()
}
