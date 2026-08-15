import AppKit
import SwiftUI

struct Subscription: Codable, Equatable, Identifiable {
    let id: UUID
    var name: String
    var price: String
    var emoji: String

    init(id: UUID = UUID(), name: String = "", price: String = "", emoji: String = "📦") {
        self.id = id
        self.name = name
        self.price = price
        self.emoji = emoji
    }
}

struct OneTimeExpense: Codable, Equatable, Identifiable {
    let id: UUID
    var name: String
    var amount: String
    var emoji: String

    init(id: UUID = UUID(), name: String = "", amount: String = "", emoji: String = "🧾") {
        self.id = id
        self.name = name
        self.amount = amount
        self.emoji = emoji
    }
}

struct ContentView: View {
    @State private var subscriptions = LocalStorage.load(
        [Subscription].self,
        forKey: LocalStorage.subscriptionsKey
    ) ?? []
    @State private var editedSubscription: Subscription?
    @State private var oneTimeExpenses = LocalStorage.load(
        [OneTimeExpense].self,
        forKey: LocalStorage.oneTimeExpensesKey
    ) ?? []
    @State private var editedExpense: OneTimeExpense?
    @AppStorage("scholarshipTier") private var scholarshipTier: ScholarshipTier = .level7

    private var monthlyScholarship: Double {
        scholarshipTier.monthlyAmount
    }

    private var subscriptionTotal: Double {
        subscriptions.reduce(0) { total, subscription in
            total + amount(from: subscription.price)
        }
    }

    private var oneTimeExpenseTotal: Double {
        oneTimeExpenses.reduce(0) { total, expense in
            total + amount(from: expense.amount)
        }
    }

    private var remainingAmount: Double {
        max(monthlyScholarship - subscriptionTotal - oneTimeExpenseTotal, 0)
    }

    private var remainingPercentage: Double {
        guard monthlyScholarship > 0 else { return 0 }
        return min(remainingAmount / monthlyScholarship, 1)
    }

    private var balanceLevel: BalanceLevel {
        BalanceLevel(percentage: remainingPercentage)
    }

    var body: some View {
        NavigationStack {
            ZStack {
                AppBackground(balanceLevel: balanceLevel)

                VStack(spacing: 20) {
                    ScholarshipTracker(
                        scholarshipTier: $scholarshipTier,
                        remainingAmount: remainingAmount,
                        remainingPercentage: remainingPercentage
                    )
                    .padding(.horizontal, 24)
                    .padding(.top, 24)

                    ScrollView {
                        HStack(alignment: .top, spacing: 54) {
                            VStack(alignment: .leading, spacing: 14) {
                                Text("Abonnements")
                                    .font(.title2.weight(.semibold))

                                AddEntryButton(accessibilityLabel: "Ajouter un abonnement") {
                                    editedSubscription = Subscription()
                                }

                                ForEach(subscriptions) { subscription in
                                    Button {
                                        editedSubscription = subscription
                                    } label: {
                                        SubscriptionRow(subscription: subscription)
                                    }
                                    .buttonStyle(.plain)
                                    .glassEffect(
                                        .regular.interactive(),
                                        in: RoundedRectangle(cornerRadius: 20)
                                    )
                                }
                            }
                            .frame(maxWidth: .infinity, alignment: .leading)

                            VStack(alignment: .leading, spacing: 14) {
                                Text("Dépenses ponctuelles")
                                    .font(.title2.weight(.semibold))

                                AddEntryButton(accessibilityLabel: "Ajouter une dépense ponctuelle") {
                                    editedExpense = OneTimeExpense()
                                }

                                ForEach(oneTimeExpenses) { expense in
                                    Button {
                                        editedExpense = expense
                                    } label: {
                                        OneTimeExpenseRow(expense: expense)
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
                        .overlay {
                            GeometryReader { geometry in
                                Color.clear
                                    .frame(width: 6, height: geometry.size.height)
                                    .glassEffect(.regular, in: Capsule())
                                    .position(
                                        x: geometry.size.width / 2,
                                        y: geometry.size.height / 2
                                    )
                                    .animation(
                                        .smooth(duration: 0.5),
                                        value: geometry.size.height
                                    )
                            }
                            .allowsHitTesting(false)
                        }
                        .animation(
                            .smooth(duration: 0.5),
                            value: subscriptions.count + oneTimeExpenses.count
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
            .sheet(item: $editedSubscription) { subscription in
                SubscriptionEditor(
                    subscription: subscription,
                    isNew: !subscriptions.contains { $0.id == subscription.id }
                ) { updatedSubscription in
                    save(updatedSubscription)
                }
            }
            .sheet(item: $editedExpense) { expense in
                OneTimeExpenseEditor(
                    expense: expense,
                    isNew: !oneTimeExpenses.contains { $0.id == expense.id }
                ) { updatedExpense in
                    save(updatedExpense)
                }
            }
            .onChange(of: subscriptions) { _, newSubscriptions in
                LocalStorage.save(newSubscriptions, forKey: LocalStorage.subscriptionsKey)
            }
            .onChange(of: oneTimeExpenses) { _, newExpenses in
                LocalStorage.save(newExpenses, forKey: LocalStorage.oneTimeExpensesKey)
            }
        }
    }

    private func save(_ subscription: Subscription) {
        if let index = subscriptions.firstIndex(where: { $0.id == subscription.id }) {
            subscriptions[index] = subscription
        } else {
            subscriptions.append(subscription)
        }
    }

    private func save(_ expense: OneTimeExpense) {
        if let index = oneTimeExpenses.firstIndex(where: { $0.id == expense.id }) {
            oneTimeExpenses[index] = expense
        } else {
            oneTimeExpenses.append(expense)
        }
    }

    private func amount(from text: String) -> Double {
        Double(text.replacingOccurrences(of: ",", with: ".")) ?? 0
    }
}

private enum LocalStorage {
    static let subscriptionsKey = "subscriptions"
    static let oneTimeExpensesKey = "oneTimeExpenses"

    static func load<Value: Decodable>(_ type: Value.Type, forKey key: String) -> Value? {
        guard let data = UserDefaults.standard.data(forKey: key) else { return nil }
        return try? JSONDecoder().decode(type, from: data)
    }

    static func save<Value: Encodable>(_ value: Value, forKey key: String) {
        guard let data = try? JSONEncoder().encode(value) else { return }
        UserDefaults.standard.set(data, forKey: key)
    }
}

private struct ScholarshipTracker: View {
    @Binding var scholarshipTier: ScholarshipTier
    @State private var isSelectingScholarship = false

    let remainingAmount: Double
    let remainingPercentage: Double

    private var statusColor: Color {
        BalanceLevel(percentage: remainingPercentage).color
    }

    var body: some View {
        VStack(spacing: 12) {
            HStack {
                Spacer()

                Button {
                    isSelectingScholarship.toggle()
                } label: {
                    HStack(spacing: 10) {
                        Text(scholarshipTier.selectionTitle)
                            .lineLimit(1)

                        Image(systemName: "chevron.down")
                            .font(.caption2.weight(.semibold))
                            .foregroundStyle(.secondary)
                    }
                }
                .buttonStyle(.glass)
                .fixedSize()
                .accessibilityLabel("Échelon de bourse")
                .popover(isPresented: $isSelectingScholarship, arrowEdge: .bottom) {
                    VStack(alignment: .leading, spacing: 4) {
                        ForEach(ScholarshipTier.allCases) { tier in
                            Button {
                                scholarshipTier = tier
                                isSelectingScholarship = false
                            } label: {
                                HStack {
                                    Text(tier.selectionTitle)

                                    Spacer()

                                    if scholarshipTier == tier {
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
                    .trim(from: 0, to: remainingPercentage)
                    .stroke(statusColor, style: StrokeStyle(lineWidth: 18, lineCap: .round))
                    .animation(.smooth(duration: 0.7), value: remainingPercentage)

                VStack(spacing: 2) {
                    Text(remainingPercentage, format: .percent.precision(.fractionLength(0)))
                        .font(.system(size: 38, weight: .bold, design: .rounded))
                        .foregroundStyle(statusColor)
                        .contentTransition(.numericText(value: remainingPercentage))
                    Text("\(remainingAmount, format: .number.precision(.fractionLength(2))) € restants")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
                .padding(.bottom, 4)
            }
            .frame(maxWidth: 320)
            .frame(height: 180)
            .animation(.easeInOut(duration: 0.45), value: statusColor)
        }
        .padding(22)
        .glassEffect(.regular, in: RoundedRectangle(cornerRadius: 28))
    }
}

private enum ScholarshipTier: String, CaseIterable, Codable, Identifiable {
    case none
    case level0Bis
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
        case .level0Bis:
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

    var name: String {
        switch self {
        case .none:
            "Pas de bourse"
        case .level0Bis:
            "Échelon 0 bis"
        case .level1:
            "Échelon 1"
        case .level2:
            "Échelon 2"
        case .level3:
            "Échelon 3"
        case .level4:
            "Échelon 4"
        case .level5:
            "Échelon 5"
        case .level6:
            "Échelon 6"
        case .level7:
            "Échelon 7"
        }
    }

    var selectionTitle: String {
        guard self != .none else { return name }
        return "\(name) · \(monthlyAmount.formatted(.currency(code: "EUR"))) / mois"
    }
}

private enum BalanceLevel: Equatable {
    case comfortable
    case warning
    case critical

    init(percentage: Double) {
        if percentage > 0.5 {
            self = .comfortable
        } else if percentage > 0.2 {
            self = .warning
        } else {
            self = .critical
        }
    }

    var color: Color {
        switch self {
        case .comfortable:
            .green
        case .warning:
            .orange
        case .critical:
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
    var balanceLevel: BalanceLevel = .comfortable

    private var colors: [Color] {
        switch balanceLevel {
        case .comfortable:
            [.indigo.opacity(0.4), .green.opacity(0.3), .cyan.opacity(0.25)]
        case .warning:
            [.indigo.opacity(0.4), .orange.opacity(0.35), .yellow.opacity(0.2)]
        case .critical:
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
        .animation(.easeInOut(duration: 0.9), value: balanceLevel)
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

private struct SubscriptionRow: View {
    let subscription: Subscription

    var body: some View {
        HStack(spacing: 12) {
            Text(subscription.emoji)
                .font(.title)

            Text(subscription.name)
                .font(.headline)

            Spacer()

            Text(subscription.price.isEmpty ? "—" : "\(subscription.price) €")
                .foregroundStyle(.secondary)
        }
        .contentShape(.rect)
        .padding(18)
    }
}

private struct OneTimeExpenseRow: View {
    let expense: OneTimeExpense

    var body: some View {
        HStack(spacing: 12) {
            Text(expense.emoji)
                .font(.title)

            Text(expense.name)
                .font(.headline)

            Spacer()

            Text(expense.amount.isEmpty ? "—" : "\(expense.amount) €")
                .foregroundStyle(.secondary)
        }
        .contentShape(.rect)
        .padding(18)
    }
}

private struct SubscriptionEditor: View {
    @Environment(\.dismiss) private var dismiss
    @State private var subscription: Subscription

    let isNew: Bool
    let onSave: (Subscription) -> Void

    init(subscription: Subscription, isNew: Bool, onSave: @escaping (Subscription) -> Void) {
        _subscription = State(initialValue: subscription)
        self.isNew = isNew
        self.onSave = onSave
    }

    var body: some View {
        ZStack {
            AppBackground()

            VStack(spacing: 22) {
                Text(isNew ? "Nouvel abonnement" : "Modifier l’abonnement")
                    .font(.title.bold())

                EditorEmojiField(text: $subscription.emoji)

                GlassTextField(title: "Nom", text: $subscription.name)
                GlassTextField(title: "Prix mensuel", text: $subscription.price)

                HStack(spacing: 12) {
                    Button("Annuler") {
                        dismiss()
                    }
                    .buttonStyle(.glass)

                    Button("Enregistrer") {
                        onSave(subscription)
                        dismiss()
                    }
                    .buttonStyle(.glass)
                    .disabled(subscription.name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
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

private struct OneTimeExpenseEditor: View {
    @Environment(\.dismiss) private var dismiss
    @State private var expense: OneTimeExpense

    let isNew: Bool
    let onSave: (OneTimeExpense) -> Void

    init(expense: OneTimeExpense, isNew: Bool, onSave: @escaping (OneTimeExpense) -> Void) {
        _expense = State(initialValue: expense)
        self.isNew = isNew
        self.onSave = onSave
    }

    var body: some View {
        ZStack {
            AppBackground()

            VStack(spacing: 22) {
                Text(isNew ? "Nouvelle dépense" : "Modifier la dépense")
                    .font(.title.bold())

                EditorEmojiField(text: $expense.emoji)

                GlassTextField(title: "Nom", text: $expense.name)
                GlassTextField(title: "Montant", text: $expense.amount)

                HStack(spacing: 12) {
                    Button("Annuler") {
                        dismiss()
                    }
                    .buttonStyle(.glass)

                    Button("Enregistrer") {
                        onSave(expense)
                        dismiss()
                    }
                    .buttonStyle(.glass)
                    .disabled(expense.name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
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

private struct EditorEmojiField: View {
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

    var body: some View {
        TextField(title, text: $text)
            .textFieldStyle(.plain)
            .multilineTextAlignment(.center)
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
            .frame(maxWidth: 420)
            .glassEffect(.regular.interactive(), in: RoundedRectangle(cornerRadius: 14))
    }
}

#Preview {
    ContentView()
}
