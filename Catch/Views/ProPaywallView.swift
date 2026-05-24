import SwiftUI
import StoreKit

struct ProPaywallView: View {
    @EnvironmentObject var appState: AppState
    @Environment(\.dismiss) private var dismiss
    @StateObject private var store = CatchProStore()
    @State private var selectedPlan: CatchProPlan = .annual
    @State private var selectedFeaturePage = 0
    var onClose: (() -> Void)?
    var onUnlock: (() -> Void)?

    private let heroPills: [ProHeroPill] = [
        ProHeroPill(title: "Widgets", symbol: "square.grid.2x2.fill", color: Color(hex: "5AC8FA"), rotation: -12, xOffset: -96, yOffset: 12),
        ProHeroPill(title: "Can I catch it?", symbol: "figure.walk", color: Color(hex: "34C759"), rotation: 9, xOffset: 118, yOffset: 28),
        ProHeroPill(title: "Leave now", symbol: "bell.badge.fill", color: Color(hex: "FF9F0A"), rotation: -7, xOffset: -64, yOffset: 68),
        ProHeroPill(title: "Live Board", symbol: "rectangle.3.group.bubble.left.fill", color: Color(hex: "5AC8FA"), rotation: 7, xOffset: 124, yOffset: 86),
        ProHeroPill(title: "Pinned buses", symbol: "pin.fill", color: Color(hex: "BF5AF2"), rotation: -5, xOffset: -18, yOffset: 120),
        ProHeroPill(title: "Icons", symbol: "app.badge.fill", color: Color(hex: "BF5AF2"), rotation: 5, xOffset: 138, yOffset: 124)
    ]

    private let benefits: [ProBenefit] = [
        ProBenefit(
            title: "Smart leave-now alerts",
            subtitle: "Know when to leave before the bus gets too tight.",
            symbol: "bell.badge.fill",
            color: Color(hex: "FF9F0A")
        ),
        ProBenefit(
            title: "Live Board",
            subtitle: "Pin your stop to Dynamic Island, widgets, and Live Activities.",
            symbol: "rectangle.3.group.bubble.left.fill",
            color: Color(hex: "5AC8FA")
        ),
        ProBenefit(
            title: "Route memory",
            subtitle: "Catch learns the buses and timings you actually take.",
            symbol: "brain.head.profile",
            color: Color(hex: "FFD60A")
        ),
        ProBenefit(
            title: "Widgets",
            subtitle: "Keep pinned buses on Home and Lock Screen.",
            symbol: "square.grid.2x2.fill",
            color: Color(hex: "5AC8FA")
        ),
        ProBenefit(
            title: "Can I catch it?",
            subtitle: "Know if the next bus is easy, tight, or safer later.",
            symbol: "figure.walk",
            color: Color(hex: "34C759")
        ),
        ProBenefit(
            title: "All app icons",
            subtitle: "Unlock every Catch icon style.",
            symbol: "app.badge.fill",
            color: Color(hex: "BF5AF2")
        )
    ]

    private var benefitPages: [[ProBenefit]] {
        stride(from: 0, to: benefits.count, by: 3).map {
            Array(benefits[$0..<min($0 + 3, benefits.count)])
        }
    }

    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()

            GeometryReader { proxy in
                VStack(spacing: 0) {
                    heroHeader
                        .frame(height: min(184, proxy.size.height * 0.22))

                    paywallCard(availableHeight: proxy.size.height)
                        .offset(y: -14)
                }
                .frame(maxWidth: 520)
                .frame(maxWidth: .infinity)
                .frame(height: proxy.size.height, alignment: .top)
            }
        }
        .preferredColorScheme(.dark)
        .task {
            await store.loadProducts()
            if !appState.isProMember, await store.refreshEntitlements() {
                appState.setProMembership(true)
            }
        }
    }

    private var heroHeader: some View {
        ZStack(alignment: .topTrailing) {
            LinearGradient(
                colors: [
                    Color(hex: "052A21"),
                    Color(hex: "0B5F35"),
                    Color(hex: "104626")
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )

            RadialGradient(
                colors: [Color(hex: "21D07A").opacity(0.42), .clear],
                center: .topLeading,
                startRadius: 12,
                endRadius: 320
            )

            ForEach(heroPills) { pill in
                HeroFeaturePill(pill: pill)
                    .rotationEffect(.degrees(pill.rotation))
                    .offset(x: pill.xOffset, y: pill.yOffset)
            }

            Text("PRO")
                .font(.system(size: 52, weight: .black))
                .tracking(52 * -0.025)
                .foregroundStyle(Color(hex: "0B7D5B").opacity(0.55))
                .padding(.top, 58)

            GlassCircleIconButton(
                systemName: "xmark",
                size: 42,
                iconSize: 17,
                foregroundColor: .white.opacity(0.82)
            ) {
                closePaywall()
            }
            .padding(.top, 36)
            .padding(.trailing, 20)
        }
        .clipShape(
            UnevenRoundedRectangle(
                topLeadingRadius: 44,
                bottomLeadingRadius: 0,
                bottomTrailingRadius: 0,
                topTrailingRadius: 44,
                style: .continuous
            )
        )
        .padding(.horizontal, 14)
    }

    private func paywallCard(availableHeight: CGFloat) -> some View {
        let compact = availableHeight < 920
        return VStack(alignment: .leading, spacing: 0) {
            HStack(alignment: .center) {
                Image("CatchIcon")
                    .resizable()
                    .scaledToFill()
                    .frame(width: compact ? 50 : 58, height: compact ? 50 : 58)
                    .clipShape(RoundedRectangle(cornerRadius: compact ? 13 : 15, style: .continuous))
                    .overlay(
                        RoundedRectangle(cornerRadius: compact ? 13 : 15, style: .continuous)
                            .stroke(Color.white.opacity(0.10), lineWidth: 1)
                    )

                Spacer()

                Button {
                    Haptics.tap()
                    Task {
                        let didRestore = await store.restorePurchases()
                        if didRestore {
                            appState.setProMembership(true)
                            unlockPaywall()
                        }
                    }
                } label: {
                    HStack(spacing: 6) {
                        Image(systemName: "arrow.counterclockwise")
                        Text("Restore")
                    }
                    .font(.system(size: 16, weight: .bold))
                    .tracking(16 * -0.025)
                    .foregroundStyle(Color(hex: "FFD60A"))
                    .padding(.horizontal, 12)
                    .padding(.vertical, 8)
                    .background(Color(hex: "FFD60A").opacity(0.12))
                    .clipShape(Capsule())
                }
                .buttonStyle(.plain)
                .disabled(store.isPurchasing)
            }

            Text("Free was the warm-up.")
                .font(.system(size: compact ? 29 : 33, weight: .regular))
                .tracking((compact ? 29 : 33) * -0.025)
                .foregroundStyle(.white)
                .lineLimit(1)
                .minimumScaleFactor(0.72)
                .padding(.top, compact ? 12 : 16)

            Text("Catch Pro is for the buses and routines you actually rely on.")
                .font(.system(size: compact ? 15 : 16, weight: .semibold))
                .tracking((compact ? 15 : 16) * -0.025)
                .foregroundStyle(.white.opacity(0.70))
                .lineLimit(2)
                .minimumScaleFactor(0.82)
                .padding(.top, 5)

            TabView(selection: $selectedFeaturePage) {
                ForEach(Array(benefitPages.enumerated()), id: \.offset) { pageIndex, page in
                    VStack(spacing: compact ? 9 : 11) {
                        ForEach(page) { benefit in
                            ProBenefitRow(benefit: benefit, compact: compact)
                        }
                    }
                    .tag(pageIndex)
                }
            }
            .tabViewStyle(.page(indexDisplayMode: .never))
            .frame(height: compact ? 150 : 170)
            .padding(.top, compact ? 11 : 14)

            HStack(spacing: 8) {
                ForEach(0..<benefitPages.count, id: \.self) { index in
                    Circle()
                        .fill(index == selectedFeaturePage ? Color.white : Color.white.opacity(0.16))
                        .frame(width: 8, height: 8)
                }
            }
            .frame(maxWidth: .infinity)
            .padding(.top, compact ? 6 : 8)

            planPicker
                .padding(.top, compact ? 10 : 14)

            subscribeSection
                .padding(.top, compact ? 10 : 14)
        }
        .padding(.horizontal, compact ? 24 : 28)
        .padding(.top, compact ? 16 : 20)
        .padding(.bottom, compact ? 12 : 18)
        .background(Color(hex: "1C1C1E"))
        .clipShape(UnevenRoundedRectangle(topLeadingRadius: 34, bottomLeadingRadius: 34, bottomTrailingRadius: 34, topTrailingRadius: 34, style: .continuous))
        .padding(.horizontal, 14)
    }

    @ViewBuilder
    private var planPicker: some View {
        HStack(spacing: 12) {
            ForEach(CatchProPlan.allCases, id: \.self) { plan in
                ProPlanCard(
                    plan: plan,
                    displayPrice: store.planDisplayPrice(for: plan),
                    subtitle: store.planSubtitle(for: plan),
                    badgeText: plan == .annual ? store.annualDiscountBadgeText : nil,
                    isSelected: selectedPlan == plan
                ) {
                    Haptics.tap()
                    withAnimation(.spring(response: 0.34, dampingFraction: 0.86)) {
                        selectedPlan = plan
                    }
                }
            }
        }
    }

    private var subscribeSection: some View {
        VStack(spacing: 12) {
            if let message = store.statusMessage, store.statusIsError {
                Text(message)
                    .font(.system(size: 12, weight: .bold))
                    .tracking(12 * -0.025)
                    .foregroundStyle(Color(hex: "FF453A"))
                    .multilineTextAlignment(.center)
                    .lineLimit(2)
                    .minimumScaleFactor(0.82)
                    .padding(.horizontal, 6)
            }

            Button {
                Haptics.tap(.medium)
                Task {
                    let didUnlock = await store.purchase(selectedPlan)
                    if didUnlock {
                        appState.setProMembership(true)
                        unlockPaywall()
                    }
                }
            } label: {
                HStack(spacing: 10) {
                    Text("Start 7 Day")
                    Text("Free")
                        .font(.system(size: 15, weight: .bold))
                        .tracking(15 * -0.025)
                        .foregroundStyle(.white)
                        .padding(.horizontal, 11)
                        .padding(.vertical, 6)
                        .background(Color.black.opacity(0.70))
                        .clipShape(Capsule())
                    Text("Trial")
                }
                .font(.system(size: 21, weight: .bold))
                .tracking(21 * -0.025)
                .foregroundStyle(.black)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 15)
                .background(Color.white)
                .clipShape(RoundedRectangle(cornerRadius: 30, style: .continuous))
            }
            .buttonStyle(.plain)
            .disabled(store.isPurchasing)

            Text("No charge today, then \(store.renewalText(for: selectedPlan)). Cancel anytime.")
                .font(.system(size: 13, weight: .bold))
                .tracking(13 * -0.025)
                .foregroundStyle(.white.opacity(0.46))
                .multilineTextAlignment(.center)
                .lineLimit(2)
                .minimumScaleFactor(0.82)
                .padding(.top, 2)
        }
    }

    private func closePaywall() {
        if let onClose {
            onClose()
        } else {
            dismiss()
        }
    }

    private func unlockPaywall() {
        if let onUnlock {
            onUnlock()
        } else {
            dismiss()
        }
    }
}

private struct ProHeroPill: Identifiable {
    let id = UUID()
    let title: String
    let symbol: String
    let color: Color
    let rotation: Double
    let xOffset: CGFloat
    let yOffset: CGFloat
}

private struct ProBenefit: Identifiable {
    let id = UUID()
    let title: String
    let subtitle: String
    let symbol: String
    let color: Color
}

private struct HeroFeaturePill: View {
    let pill: ProHeroPill

    var body: some View {
        HStack(spacing: 10) {
            Image(systemName: pill.symbol)
                .font(.system(size: 14, weight: .black))
                .foregroundStyle(.white)
                .frame(width: 31, height: 31)
                .background(pill.color.opacity(0.92))
                .clipShape(Circle())

            Text(pill.title)
                .font(.system(size: 16, weight: .semibold))
                .tracking(16 * -0.025)
                .foregroundStyle(.white.opacity(0.88))
                .lineLimit(1)
        }
        .padding(.leading, 8)
        .padding(.trailing, 15)
        .padding(.vertical, 6)
        .background(Color.white.opacity(0.12))
        .overlay(
            Capsule()
                .stroke(Color.white.opacity(0.22), lineWidth: 1)
        )
        .clipShape(Capsule())
    }
}

private struct ProBenefitRow: View {
    let benefit: ProBenefit
    let compact: Bool

    var body: some View {
        HStack(spacing: compact ? 12 : 14) {
            Image(systemName: benefit.symbol)
                .font(.system(size: compact ? 15 : 17, weight: .black))
                .foregroundStyle(benefit.color)
                .frame(width: compact ? 40 : 46, height: compact ? 40 : 46)
                .background(Color.white.opacity(0.06))
                .clipShape(RoundedRectangle(cornerRadius: compact ? 14 : 16, style: .continuous))

            VStack(alignment: .leading, spacing: 3) {
                Text(benefit.title)
                    .font(.system(size: compact ? 16 : 18, weight: .bold))
                    .tracking((compact ? 16 : 18) * -0.025)
                    .foregroundStyle(.white)
                    .lineLimit(1)
                    .minimumScaleFactor(0.82)

                Text(benefit.subtitle)
                    .font(.system(size: compact ? 12 : 14, weight: .semibold))
                    .tracking((compact ? 12 : 14) * -0.025)
                    .foregroundStyle(.white.opacity(0.58))
                    .lineLimit(2)
                    .minimumScaleFactor(0.82)
            }
        }
    }
}

private struct ProPlanCard: View {
    let plan: CatchProPlan
    let displayPrice: String
    let subtitle: String
    let badgeText: String?
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            VStack(alignment: .leading, spacing: 7) {
                HStack(alignment: .top) {
                    Text(plan.title)
                        .font(.system(size: 17, weight: .semibold))
                        .tracking(17 * -0.025)
                        .foregroundStyle(.white.opacity(0.72))

                    Spacer(minLength: 4)

                    if let badgeText {
                        Text(badgeText)
                            .font(.system(size: 13, weight: .black))
                            .tracking(13 * -0.025)
                            .foregroundStyle(Color(hex: "FF2D55"))
                            .padding(.horizontal, 9)
                            .padding(.vertical, 4)
                            .background(Color(hex: "FF2D55").opacity(0.18))
                            .clipShape(Capsule())
                    }
                }

                HStack(alignment: .firstTextBaseline, spacing: 6) {
                    Text("$")
                        .font(.system(size: 18, weight: .medium))
                        .foregroundStyle(.white.opacity(0.76))

                    Text(displayPrice)
                        .font(.system(size: 32, weight: .regular))
                        .tracking(32 * -0.025)
                        .foregroundStyle(.white)
                        .lineLimit(1)
                        .minimumScaleFactor(0.72)
                }

                Text(subtitle)
                    .font(.system(size: 13, weight: .semibold))
                    .tracking(13 * -0.025)
                    .foregroundStyle(.white.opacity(0.38))
                    .lineLimit(1)
                    .minimumScaleFactor(0.72)
            }
            .padding(14)
            .frame(maxWidth: .infinity, minHeight: 96, alignment: .leading)
            .background(Color.white.opacity(0.06))
            .overlay(
                RoundedRectangle(cornerRadius: 24, style: .continuous)
                    .stroke(isSelected ? Color.white.opacity(0.94) : Color.white.opacity(0.03), lineWidth: isSelected ? 2 : 1)
            )
            .clipShape(RoundedRectangle(cornerRadius: 24, style: .continuous))
        }
        .buttonStyle(.plain)
    }
}

private struct ProCollapsedPlanCard: View {
    let plan: CatchProPlan
    let displayPrice: String
    let subtitle: String
    let badgeText: String?
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 12) {
                VStack(alignment: .leading, spacing: 4) {
                    HStack(spacing: 7) {
                        Text(plan.title)
                            .font(.system(size: 21, weight: .bold))
                            .tracking(21 * -0.025)
                            .foregroundStyle(.white.opacity(0.82))

                        Image(systemName: "chevron.right.circle.fill")
                            .font(.system(size: 18, weight: .bold))
                            .foregroundStyle(.white.opacity(0.28))
                    }

                    Text(subtitle)
                        .font(.system(size: 18, weight: .semibold))
                        .tracking(18 * -0.025)
                        .foregroundStyle(.white.opacity(0.38))
                        .lineLimit(1)
                        .minimumScaleFactor(0.74)
                }

                Spacer()

                if let badgeText {
                    Text(badgeText)
                        .font(.system(size: 14, weight: .black))
                        .tracking(14 * -0.025)
                        .foregroundStyle(Color(hex: "FF2D55"))
                        .padding(.horizontal, 10)
                        .padding(.vertical, 5)
                        .background(Color(hex: "FF2D55").opacity(0.18))
                        .clipShape(Capsule())
                }

                Text("$\(displayPrice)")
                    .font(.system(size: 23, weight: .semibold))
                    .tracking(23 * -0.025)
                    .foregroundStyle(.white.opacity(0.86))
                    .lineLimit(1)
                    .minimumScaleFactor(0.72)
            }
            .padding(.horizontal, 22)
            .frame(height: 104)
            .background(Color.white.opacity(0.07))
            .clipShape(RoundedRectangle(cornerRadius: 25, style: .continuous))
        }
        .buttonStyle(.plain)
    }
}

enum CatchProPlan: CaseIterable {
    case monthly
    case annual

    var productID: String {
        switch self {
        case .monthly: "com.adityaarya.catch.pro.monthly"
        case .annual: "com.adityaarya.catch.pro.annual"
        }
    }

    var title: String {
        switch self {
        case .monthly: "Monthly"
        case .annual: "Annual"
        }
    }

    var fallbackPrice: Decimal {
        switch self {
        case .monthly: Decimal(string: "4.99") ?? Decimal(4)
        case .annual: Decimal(string: "39.99") ?? Decimal(39)
        }
    }
}

@MainActor
final class CatchProStore: ObservableObject {
    @Published private(set) var products: [Product] = []
    @Published var isPurchasing = false
    @Published var statusMessage: String?
    @Published var statusIsError = false

    private static let productIDs = Set(CatchProPlan.allCases.map(\.productID))

    func loadProducts() async {
        do {
            products = try await Product.products(for: Self.productIDs)
                .sorted { lhs, rhs in
                    productOrder(lhs.id) < productOrder(rhs.id)
                }
            if products.isEmpty {
                statusMessage = "Subscriptions are ready in the UI. Add these product IDs in App Store Connect to test purchases."
                statusIsError = false
            } else {
                statusMessage = nil
            }
        } catch {
            statusMessage = "Could not load subscriptions."
            statusIsError = true
        }
    }

    func product(for plan: CatchProPlan) -> Product? {
        products.first { $0.id == plan.productID }
    }

    func priceText(for plan: CatchProPlan) -> String {
        switch plan {
        case .monthly:
            return product(for: plan)?.displayPrice ?? "$2"
        case .annual:
            let annualPrice = priceDecimal(for: plan)
            return "\(currencyString(annualPrice / Decimal(12)))/mo"
        }
    }

    func subtitleText(for plan: CatchProPlan) -> String {
        switch plan {
        case .monthly:
            return "Monthly subscription to Catch"
        case .annual:
            let annualPrice = product(for: plan)?.displayPrice ?? "$30"
            return "\(annualPrice) billed yearly"
        }
    }

    func planDisplayPrice(for plan: CatchProPlan) -> String {
        decimalString(priceDecimal(for: plan))
    }

    func planSubtitle(for plan: CatchProPlan) -> String {
        switch plan {
        case .monthly:
            return "Monthly subscription to Catch"
        case .annual:
            return "\(currencyString(priceDecimal(for: .annual) / Decimal(12)))/mo, billed yearly"
        }
    }

    func renewalText(for plan: CatchProPlan) -> String {
        switch plan {
        case .monthly:
            return "\(currencyString(priceDecimal(for: .monthly)))/month"
        case .annual:
            return "\(currencyString(priceDecimal(for: .annual)))/year"
        }
    }

    var annualDiscountBadgeText: String? {
        let monthlyPrice = priceDecimal(for: .monthly)
        let annualPrice = priceDecimal(for: .annual)
        let yearlyMonthlyCost = monthlyPrice * Decimal(12)
        let savings = yearlyMonthlyCost - annualPrice
        guard savings > 0, yearlyMonthlyCost > 0 else { return nil }
        let percent = savings / yearlyMonthlyCost * Decimal(100)
        return "-\(NSDecimalNumber(decimal: percent).intValue)%"
    }

    func purchase(_ plan: CatchProPlan) async -> Bool {
        guard let product = product(for: plan) else {
            statusMessage = "Create \(plan.productID) in App Store Connect first."
            statusIsError = true
            return false
        }

        isPurchasing = true
        defer { isPurchasing = false }

        do {
            let result = try await product.purchase()
            switch result {
            case .success(let verification):
                let transaction = try checkVerified(verification)
                await transaction.finish()
                return await refreshEntitlements()
            case .userCancelled, .pending:
                return false
            @unknown default:
                return false
            }
        } catch {
            statusMessage = "Purchase could not be completed."
            statusIsError = true
            return false
        }
    }

    func restorePurchases() async -> Bool {
        isPurchasing = true
        defer { isPurchasing = false }

        do {
            try await AppStore.sync()
            let isActive = await refreshEntitlements()
            if !isActive {
                statusMessage = "No active Catch Pro purchase found."
                statusIsError = true
            }
            return isActive
        } catch {
            statusMessage = "Could not restore purchases."
            statusIsError = true
            return false
        }
    }

    func refreshEntitlements() async -> Bool {
        let isActive = await Self.hasActiveProEntitlement()
        if isActive {
            statusMessage = nil
        }
        return isActive
    }

    static func hasActiveProEntitlement() async -> Bool {
        for await entitlement in Transaction.currentEntitlements {
            guard let transaction = try? checkVerified(entitlement) else { continue }
            if productIDs.contains(transaction.productID),
               transaction.revocationDate == nil,
               transaction.expirationDate.map({ $0 > Date() }) ?? true {
                return true
            }
        }
        return false
    }

    var annualSavingsText: String? {
        let monthlyPrice = priceDecimal(for: .monthly)
        let annualPrice = priceDecimal(for: .annual)
        let yearlyMonthlyCost = monthlyPrice * Decimal(12)
        let savings = yearlyMonthlyCost - annualPrice
        guard savings > 0 else { return nil }
        return "Save \(currencyString(savings))"
    }

    func monthlyEquivalentText(for plan: CatchProPlan) -> String {
        let annualPrice = priceDecimal(for: plan)
        guard plan == .annual else { return "\(currencyString(annualPrice))/month" }
        return "\(currencyString(annualPrice / Decimal(12)))/month"
    }

    private func productOrder(_ id: String) -> Int {
        id == CatchProPlan.annual.productID ? 0 : 1
    }

    private func priceDecimal(for plan: CatchProPlan) -> Decimal {
        product(for: plan)?.price ?? plan.fallbackPrice
    }

    private func currencyString(_ value: Decimal) -> String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .currency
        formatter.currencyCode = Locale.current.currency?.identifier ?? "USD"
        formatter.maximumFractionDigits = 2
        formatter.minimumFractionDigits = NSDecimalNumber(decimal: value).doubleValue.rounded() == NSDecimalNumber(decimal: value).doubleValue ? 0 : 2
        return formatter.string(from: value as NSDecimalNumber) ?? "$\(value)"
    }

    private func decimalString(_ value: Decimal) -> String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .decimal
        formatter.maximumFractionDigits = 2
        formatter.minimumFractionDigits = NSDecimalNumber(decimal: value).doubleValue.rounded() == NSDecimalNumber(decimal: value).doubleValue ? 0 : 2
        return formatter.string(from: value as NSDecimalNumber) ?? "\(value)"
    }

    private static func checkVerified<T>(_ result: VerificationResult<T>) throws -> T {
        switch result {
        case .unverified:
            throw StoreError.failedVerification
        case .verified(let safe):
            return safe
        }
    }

    private func checkVerified<T>(_ result: VerificationResult<T>) throws -> T {
        try Self.checkVerified(result)
    }

    private enum StoreError: Error {
        case failedVerification
    }
}
