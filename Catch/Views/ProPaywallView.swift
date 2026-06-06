import SwiftUI
import StoreKit

private enum CatchPaywallLegalURL {
    static let privacy = URL(string: "https://adiarya05.github.io/Catch/privacy.html")!
    static let terms = URL(string: "https://adiarya05.github.io/Catch/terms.html")!
}

struct ProPaywallView: View {
    @EnvironmentObject var appState: AppState
    @Environment(\.dismiss) private var dismiss
    @Environment(\.openURL) private var openURL
    @StateObject private var store = CatchProStore()
    @State private var selectedPlan: CatchProPlan = .monthly
    @State private var selectedFeaturePage = 0
    @State private var isPricingExpanded = false
    @State private var isTrialButtonPulsing = false
    var onClose: (() -> Void)?
    var onUnlock: (() -> Void)?

    private let benefits: [ProBenefit] = [
        ProBenefit(
            title: "Smart leave-now alerts",
            subtitle: "Know when to leave before it gets tight.",
            symbol: "bell.badge.fill",
            color: Color(hex: "FF9F0A")
        ),
        ProBenefit(
            title: "Live Board",
            subtitle: "Pin stops to Dynamic Island, widgets, and Live Activities.",
            symbol: "rectangle.3.group.bubble.left.fill",
            color: Color(hex: "5AC8FA")
        ),
        ProBenefit(
            title: "Widgets",
            subtitle: "Keep pinned buses on Home and Lock Screen.",
            symbol: "square.grid.2x2.fill",
            color: Color(hex: "5AC8FA")
        ),
        ProBenefit(
            title: "Unlimited saved stops",
            subtitle: "Save every stop and place you use often.",
            symbol: "bookmark.fill",
            color: Color(hex: "30D158")
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
            Color(hex: "292929").ignoresSafeArea()

            VStack(spacing: 0) {
                paywallContent
                .frame(maxWidth: .infinity)
            }
            .ignoresSafeArea()
        }
        .preferredColorScheme(.dark)
        .task {
            await store.loadProducts()
            #if !DEBUG
            if !appState.isProMember, await store.refreshEntitlements() {
                appState.setProMembership(true)
            }
            #endif
        }
    }

    private var paywallContent: some View {
        GeometryReader { proxy in
            let compact = proxy.size.height < 820
            let expanded = isPricingExpanded
            let iconSize: CGFloat = expanded ? 58 : (compact ? 78 : 92)
            let iconRadius: CGFloat = expanded ? 15 : (compact ? 20 : 24)
            let featureSize: CGFloat = expanded ? 22 : (compact ? 24 : 26)
            VStack(spacing: 0) {
                Spacer(minLength: expanded ? 62 : (compact ? 72 : 94))

                Image("CatchIcon")
                    .resizable()
                    .scaledToFill()
                    .frame(width: iconSize, height: iconSize)
                    .clipShape(RoundedRectangle(cornerRadius: iconRadius, style: .continuous))
                    .overlay(
                        RoundedRectangle(cornerRadius: iconRadius, style: .continuous)
                            .stroke(Color.white.opacity(0.12), lineWidth: 1)
                    )

                VStack(spacing: expanded ? 12 : (compact ? 14 : 16)) {
                    featureLine("Widgets", symbol: "square.grid.2x2.fill", color: Color(hex: "5AC8FA"), badge: "New", size: featureSize)
                    featureLine("Live Board", symbol: "rectangle.3.group.bubble.left.fill", color: Color(hex: "5AC8FA"), size: featureSize)
                    featureLine("Smart leave-now alerts", symbol: "bell.badge.fill", color: Color(hex: "FF9F0A"), size: featureSize)
                    featureLine("Can I catch it?", symbol: "figure.walk", color: Color(hex: "34C759"), size: featureSize)
                    featureLine("Unlimited saved stops", symbol: "bookmark.fill", color: Color(hex: "30D158"), size: featureSize)
                    featureLine("All app icons", symbol: "app.badge.fill", color: Color(hex: "BF5AF2"), size: featureSize)
                }
                .padding(.top, expanded ? 28 : (compact ? 40 : 56))

                Spacer(minLength: expanded ? 20 : (compact ? 28 : 42))

                pricingSection
                    .padding(.horizontal, 32)

                Button {
                    Haptics.tap(.medium)
                    #if DEBUG
                    appState.setProMembership(true)
                    unlockPaywall()
                    #else
                    Task {
                        let didUnlock = await store.purchase(selectedPlan)
                        if didUnlock {
                            appState.setProMembership(true)
                            unlockPaywall()
                        }
                    }
                    #endif
                } label: {
                    AnimatedTrialButtonLabel(
                        title: store.subscribeButtonTitle(for: selectedPlan),
                        height: compact ? 76 : 86,
                        isAnimating: isTrialButtonPulsing
                    )
                }
                .buttonStyle(.plain)
            .disabled(store.isPurchasing)
            .padding(.horizontal, 32)
            .padding(.top, expanded ? 12 : (compact ? 14 : 20))

            restoreFooter
                    .padding(.top, expanded ? 14 : (compact ? 18 : 24))
                    .padding(.bottom, expanded ? 16 : (compact ? 18 : 28))
            }
            .frame(width: proxy.size.width, height: proxy.size.height)
        }
        .onAppear {
            isTrialButtonPulsing = true
        }
    }

    private func featureLine(_ title: String, symbol: String, color: Color, badge: String? = nil, size: CGFloat) -> some View {
        HStack(spacing: 9) {
            Image(systemName: symbol)
                .font(.system(size: size * 0.54, weight: .black))
                .foregroundStyle(color)
                .frame(width: size * 0.95, height: size * 0.95)
                .background(Color.white.opacity(0.07))
                .clipShape(Circle())

            Text(title)
                .font(.system(size: size, weight: .bold))
                .tracking(size * -0.025)
                .foregroundStyle(.white.opacity(0.82))
                .lineLimit(1)
                .minimumScaleFactor(0.72)

            if let badge {
                Text(badge)
                    .font(.system(size: 15, weight: .bold))
                    .tracking(15 * -0.025)
                    .foregroundStyle(.white)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 5)
                    .background(Color(hex: "0A84FF"))
                    .clipShape(Capsule())
            }
        }
        .frame(maxWidth: .infinity)
        .padding(.horizontal, 28)
    }

    private var pricingSection: some View {
        VStack(spacing: 10) {
            if isPricingExpanded {
                ForEach(CatchProPlan.allCases, id: \.self) { plan in
                    JoiPlanRow(
                        plan: plan,
                        price: store.fullPriceText(for: plan),
                        subtitle: store.joiSubtitle(for: plan),
                        badgeText: plan == .annual ? store.annualPercentChangeText : nil,
                        isSelected: selectedPlan == plan
                    ) {
                        Haptics.tap()
                        withAnimation(.spring(response: 0.34, dampingFraction: 0.88)) {
                            selectedPlan = plan
                        }
                    }
                    .transition(.opacity.combined(with: .move(edge: .top)))
                }
            } else {
                JoiCollapsedPlanRow(
                    plan: selectedPlan,
                    price: store.fullPriceText(for: selectedPlan),
                    subtitle: store.joiSubtitle(for: selectedPlan)
                ) {
                    Haptics.tap()
                    withAnimation(.spring(response: 0.38, dampingFraction: 0.86)) {
                        isPricingExpanded = true
                    }
                }
            }

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
        }
    }

    private var restoreFooter: some View {
        VStack(spacing: 9) {
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
                    Text("Restore purchases")
                    Image(systemName: "arrow.right.circle.fill")
                }
                .font(.system(size: 18, weight: .bold))
                .tracking(18 * -0.025)
                .foregroundStyle(.white.opacity(0.30))
            }
            .buttonStyle(.plain)
            .disabled(store.isPurchasing)

            Text("Manage or cancel in App Store settings.")
                .font(.system(size: 16, weight: .semibold))
                .tracking(16 * -0.025)
                .foregroundStyle(.white.opacity(0.20))
                .lineLimit(1)
                .minimumScaleFactor(0.76)

            Text("Renews automatically after trial unless canceled.")
                .font(.system(size: 13, weight: .semibold))
                .tracking(13 * -0.025)
                .foregroundStyle(.white.opacity(0.16))
                .lineLimit(1)
                .minimumScaleFactor(0.70)

            HStack(spacing: 10) {
                Button("Terms") {
                    openURL(CatchPaywallLegalURL.terms)
                }

                Text("•")

                Button("Privacy") {
                    openURL(CatchPaywallLegalURL.privacy)
                }
            }
            .font(.system(size: 13, weight: .bold))
            .tracking(13 * -0.025)
            .foregroundStyle(.white.opacity(0.24))
            .buttonStyle(.plain)
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

private struct ProBenefit: Identifiable {
    let id = UUID()
    let title: String
    let subtitle: String
    let symbol: String
    let color: Color
}

private struct ProBenefitRow: View {
    let benefit: ProBenefit
    let compact: Bool

    var body: some View {
        HStack(alignment: .center, spacing: compact ? 12 : 14) {
            Image(systemName: benefit.symbol)
                .font(.system(size: compact ? 14 : 16, weight: .black))
                .foregroundStyle(benefit.color)
                .frame(width: compact ? 38 : 44, height: compact ? 38 : 44)
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
                    .font(.system(size: compact ? 11 : 13, weight: .semibold))
                    .tracking((compact ? 11 : 13) * -0.025)
                    .foregroundStyle(.white.opacity(0.58))
                    .lineLimit(2)
                    .minimumScaleFactor(0.82)
            }

            Spacer(minLength: 0)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

private struct AnimatedTrialButtonLabel: View {
    let title: String
    let height: CGFloat
    let isAnimating: Bool

    var body: some View {
        WaveTrialText(title: title, isAnimating: isAnimating)
            .frame(maxWidth: .infinity)
            .frame(height: height)
            .background(Color.white.opacity(0.90))
            .clipShape(RoundedRectangle(cornerRadius: 28, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 28, style: .continuous)
                    .stroke(Color.white.opacity(isAnimating ? 0.56 : 0.18), lineWidth: 1)
                    .animation(.easeInOut(duration: 0.78).repeatForever(autoreverses: true), value: isAnimating)
            )
            .shadow(color: .white.opacity(isAnimating ? 0.24 : 0.12), radius: isAnimating ? 18 : 10, y: 0)
    }
}

private struct WaveTrialText: View {
    let title: String
    let isAnimating: Bool

    var body: some View {
        GeometryReader { proxy in
            TimelineView(.animation) { timeline in
                let cycleDuration = 2.75
                let sweepDuration = 1.28
                let shineWidth: CGFloat = 170
                let time = isAnimating ? timeline.date.timeIntervalSinceReferenceDate : 0
                let cycleTime = time.truncatingRemainder(dividingBy: cycleDuration)
                let isSweeping = isAnimating && cycleTime <= sweepDuration
                let rawProgress = min(cycleTime / sweepDuration, 1)
                let progress = rawProgress * rawProgress * (3 - 2 * rawProgress)
                let travel = proxy.size.width + shineWidth * 2
                let shineX = (-shineWidth) + (travel * progress)

                ZStack {
                    trialText
                        .foregroundStyle(Color.black.opacity(0.92))

                    Rectangle()
                        .fill(
                            LinearGradient(
                                colors: [
                                    .clear,
                                    Color.black.opacity(0.10),
                                    Color(white: 0.72).opacity(0.92),
                                    Color.black.opacity(0.16),
                                    .clear
                                ],
                                startPoint: .leading,
                                endPoint: .trailing
                            )
                        )
                        .frame(width: shineWidth, height: proxy.size.height)
                        .blur(radius: 0.7)
                        .offset(x: shineX - (proxy.size.width / 2))
                        .opacity(isSweeping ? 1 : 0)
                        .mask(trialText)
                        .allowsHitTesting(false)
                }
                .frame(width: proxy.size.width, height: proxy.size.height)
                .drawingGroup(opaque: false)
            }
        }
    }

    private var trialText: some View {
        Text(title)
            .font(.system(size: 24, weight: .bold))
            .tracking(24 * -0.025)
            .lineLimit(1)
            .minimumScaleFactor(0.86)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

private struct JoiCollapsedPlanRow: View {
    let plan: CatchProPlan
    let price: String
    let subtitle: String
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 14) {
                VStack(alignment: .leading, spacing: 5) {
                    HStack(spacing: 7) {
                        Text(plan.title)
                            .font(.system(size: 22, weight: .bold))
                            .tracking(22 * -0.025)
                            .foregroundStyle(.white.opacity(0.82))

                        Image(systemName: "chevron.right.circle.fill")
                            .font(.system(size: 18, weight: .bold))
                            .foregroundStyle(.white.opacity(0.28))
                    }

                    Text(subtitle)
                        .font(.system(size: 18, weight: .semibold))
                        .tracking(18 * -0.025)
                        .foregroundStyle(.white.opacity(0.30))
                        .lineLimit(1)
                        .minimumScaleFactor(0.68)
                }

                Spacer(minLength: 8)

                Text(price)
                    .font(.system(size: 22, weight: .bold))
                    .tracking(22 * -0.025)
                    .foregroundStyle(.white.opacity(0.86))
                    .lineLimit(1)
                    .minimumScaleFactor(0.72)
            }
            .padding(.horizontal, 24)
            .frame(height: 90)
            .background(Color.white.opacity(0.10))
            .clipShape(RoundedRectangle(cornerRadius: 24, style: .continuous))
        }
        .buttonStyle(.plain)
    }
}

private struct JoiPlanRow: View {
    let plan: CatchProPlan
    let price: String
    let subtitle: String
    let badgeText: String?
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 14) {
                VStack(alignment: .leading, spacing: 5) {
                    Text(plan.title)
                        .font(.system(size: 22, weight: .bold))
                        .tracking(22 * -0.025)
                        .foregroundStyle(.white.opacity(0.82))
                        .lineLimit(1)

                    Text(subtitle)
                        .font(.system(size: 16, weight: .semibold))
                        .tracking(16 * -0.025)
                        .foregroundStyle(.white.opacity(0.30))
                        .lineLimit(1)
                        .minimumScaleFactor(0.54)
                        .allowsTightening(true)
                }
                .layoutPriority(1)

                Spacer(minLength: 4)

                if let badgeText {
                    Text(badgeText)
                        .font(.system(size: 14, weight: .black))
                        .tracking(14 * -0.025)
                        .foregroundStyle(Color(hex: "FF2D55"))
                        .padding(.horizontal, 9)
                        .padding(.vertical, 4)
                        .background(Color(hex: "FF2D55").opacity(0.18))
                        .clipShape(Capsule())
                }

                Text(price)
                    .font(.system(size: 22, weight: .bold))
                    .tracking(22 * -0.025)
                    .foregroundStyle(.white.opacity(0.86))
                    .lineLimit(1)
                    .minimumScaleFactor(0.72)
                    .fixedSize(horizontal: true, vertical: false)
            }
            .padding(.horizontal, 20)
            .frame(height: 86)
            .background(Color.white.opacity(isSelected ? 0.12 : 0.09))
            .overlay(
                RoundedRectangle(cornerRadius: 24, style: .continuous)
                    .stroke(isSelected ? Color.white.opacity(0.18) : Color.clear, lineWidth: 1)
            )
            .clipShape(RoundedRectangle(cornerRadius: 24, style: .continuous))
        }
        .buttonStyle(.plain)
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
        case .annual: "com.adityaarya.catch.pro.yearly"
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
        case .monthly: Decimal(string: "3.99") ?? Decimal(3)
        case .annual: Decimal(string: "29.99") ?? Decimal(29)
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
            return product(for: plan)?.displayPrice ?? currencyString(CatchProPlan.monthly.fallbackPrice)
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
            let annualPrice = product(for: plan)?.displayPrice ?? currencyString(CatchProPlan.annual.fallbackPrice)
            return "\(annualPrice) billed yearly"
        }
    }

    func planDisplayPrice(for plan: CatchProPlan) -> String {
        decimalString(priceDecimal(for: plan))
    }

    func planSubtitle(for plan: CatchProPlan) -> String {
        switch plan {
        case .monthly:
            return "Billed monthly"
        case .annual:
            return "\(currencyString(priceDecimal(for: .annual) / Decimal(12)))/mo, billed yearly"
        }
    }

    func fullPriceText(for plan: CatchProPlan) -> String {
        currencyString(priceDecimal(for: plan))
    }

    func joiSubtitle(for plan: CatchProPlan) -> String {
        switch plan {
        case .monthly:
            return hasIntroOffer(for: plan) ? "3 days free, then monthly" : "Billed monthly"
        case .annual:
            return hasIntroOffer(for: plan) ? "3 days free, then billed yearly" : "Billed yearly"
        }
    }

    func subscribeButtonTitle(for plan: CatchProPlan) -> String {
        hasIntroOffer(for: plan) ? "Start 3-Day Trial" : "Continue"
    }

    private func hasIntroOffer(for plan: CatchProPlan) -> Bool {
        guard let product = product(for: plan) else { return true }
        return product.subscription?.introductoryOffer != nil
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
        if let percentValue = discountPercent(monthlyPrice: monthlyPrice, annualPrice: annualPrice) {
            return "Save \(percentValue)%"
        }

        guard let fallbackPercentValue = discountPercent(
            monthlyPrice: CatchProPlan.monthly.fallbackPrice,
            annualPrice: CatchProPlan.annual.fallbackPrice
        ) else { return nil }
        return "Save \(fallbackPercentValue)%"
    }

    var annualPercentChangeText: String? {
        guard let percentValue = discountPercent(
            monthlyPrice: priceDecimal(for: .monthly),
            annualPrice: priceDecimal(for: .annual)
        ) ?? discountPercent(
            monthlyPrice: CatchProPlan.monthly.fallbackPrice,
            annualPrice: CatchProPlan.annual.fallbackPrice
        ) else { return nil }
        return "-\(percentValue)%"
    }

    private func discountPercent(monthlyPrice: Decimal, annualPrice: Decimal) -> Int? {
        let yearlyMonthlyCost = monthlyPrice * Decimal(12)
        let savings = yearlyMonthlyCost - annualPrice
        guard savings > 0, yearlyMonthlyCost > 0 else { return nil }
        let percent = savings / yearlyMonthlyCost * Decimal(100)
        let percentValue = NSDecimalNumber(decimal: percent).intValue
        guard percentValue > 0 else { return nil }
        return percentValue
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
        formatter.currencyCode = productCurrencyCode ?? "SGD"
        formatter.maximumFractionDigits = 2
        formatter.minimumFractionDigits = NSDecimalNumber(decimal: value).doubleValue.rounded() == NSDecimalNumber(decimal: value).doubleValue ? 0 : 2
        return formatter.string(from: value as NSDecimalNumber) ?? "$\(value)"
    }

    private var productCurrencyCode: String? {
        products.first?.priceFormatStyle.currencyCode
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
