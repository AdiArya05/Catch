import SwiftUI

struct ProfileView: View {
    @EnvironmentObject var appState: AppState
    @Environment(\.dismiss) private var dismiss
    @Environment(\.colorScheme) private var colorScheme

    private var bgColor: Color { colorScheme == .dark ? Color(hex: "0F0F0F") : Color(hex: "F5F5F5") }
    private var cardBg: Color { colorScheme == .dark ? Color(hex: "1C1C1E") : Color(hex: "E8E8E8") }
    private var dashColor: Color { colorScheme == .dark ? Color(hex: "3A3A3A") : Color(hex: "CCCCCC") }

    private var logs: [CommuteLogEntry] {
        appState.commuteLogs().filter { $0.source == "detected" || $0.source == "live_board" }
    }

    private var totalCommutes: Int { logs.count }

    private var mostCheckedBus: String {
        let all = logs.flatMap { $0.busServices }
        guard !all.isEmpty else { return "—" }
        let counts = Dictionary(all.map { ($0, 1) }, uniquingKeysWith: +)
        return counts.sorted { $0.value == $1.value ? $0.key < $1.key : $0.value > $1.value }.first?.key ?? "—"
    }

    private var usualStop: String {
        guard !logs.isEmpty else { return "—" }
        let counts = Dictionary(logs.map { ($0.stopName, 1) }, uniquingKeysWith: +)
        return counts.sorted { $0.value == $1.value ? $0.key < $1.key : $0.value > $1.value }.first?.key ?? "—"
    }

    private var favouritePlace: String {
        let names = logs.compactMap { log in
            appState.savedLocations.first(where: { $0.busStopCode == log.stopCode })?.name
        }
        let counts = Dictionary(names.map { ($0, 1) }, uniquingKeysWith: +)
        return counts.sorted { $0.value == $1.value ? $0.key < $1.key : $0.value > $1.value }.first?.key ?? "—"
    }

    var body: some View {
        ZStack(alignment: .topTrailing) {
            ScrollView {
                VStack(spacing: 20) {
                    Text("Profile")
                        .font(.system(size: 24, weight: .bold))
                        .tracking(24 * -0.025)
                        .foregroundColor(.primary)
                        .frame(maxWidth: .infinity)
                        .padding(.top, 28)
                        .padding(.bottom, 8)

                    receiptCard
                    statsGrid
                    tripHistory
                    footer
                }
                .padding(.horizontal, 24)
                .padding(.top, 12)
                .padding(.bottom, 40)
            }
            .background(bgColor)

            ProfileCloseButton {
                dismiss()
            }
            .padding(.top, 28)
            .padding(.trailing, 24)
        }
        .preferredColorScheme(appState.isDarkMode ? .dark : .light)
    }

    // MARK: - Receipt

    private var receiptCard: some View {
        VStack(spacing: 0) {
            zigzagEdge
                .fill(cardBg)
                .frame(height: 12)
                .scaleEffect(x: 1, y: -1)

            VStack(spacing: 0) {
                HStack {
                    Text("🚌")
                        .font(.system(size: 14))
                    Text("YOUR COMMUTE RECEIPT")
                        .font(.system(size: 12, weight: .bold))
                        .tracking(12 * 0.08)
                        .foregroundColor(.primary)
                    Text("🎫")
                        .font(.system(size: 14))
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 14)

                dashedLine

                VStack(spacing: 12) {
                    receiptRow(label: "MOST USED BUS", value: "Bus \(mostCheckedBus)")
                    receiptRow(label: "USUAL STOP", value: usualStop)
                    receiptRow(label: "MOST USED PLACE", value: favouritePlace)
                }
                .padding(.vertical, 14)
                .padding(.horizontal, 20)

                dashedLine

                HStack {
                    Text("DETECTED")
                        .font(.system(size: 12, weight: .bold))
                        .tracking(12 * 0.08)
                        .foregroundColor(Color(hex: "8E8E93"))
                    Spacer()
                    Text("\(totalCommutes) trips 🧳")
                        .font(.system(size: 16, weight: .bold))
                        .foregroundColor(.primary)
                }
                .padding(.vertical, 14)
                .padding(.horizontal, 20)

                dashedLine

                Text("THANK YOU FOR CATCHING ⭐")
                    .font(.system(size: 12, weight: .bold))
                    .tracking(12 * 0.08)
                    .foregroundColor(.primary)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 12)
            }
            .background(cardBg)

            zigzagEdge
                .fill(cardBg)
                .frame(height: 12)
        }
    }

    private var zigzagEdge: some Shape {
        ZigzagShape()
    }

    private func receiptRow(label: String, value: String) -> some View {
        HStack {
            Text(label)
                .font(.system(size: 11, weight: .bold))
                .tracking(11 * 0.06)
                .foregroundColor(Color(hex: "8E8E93"))
            Spacer()
            Text(value)
                .font(.system(size: 15, weight: .bold))
                .foregroundColor(.primary)
        }
    }

    private var dashedLine: some View {
        GeometryReader { geo in
            let dashW: CGFloat = 6
            let gap: CGFloat = 4
            let count = Int(geo.size.width / (dashW + gap))
            HStack(spacing: gap) {
                ForEach(0..<count, id: \.self) { _ in
                    RoundedRectangle(cornerRadius: 1)
                        .fill(dashColor)
                        .frame(width: dashW, height: 1.5)
                }
            }
            .frame(maxWidth: .infinity)
        }
        .frame(height: 2)
        .padding(.horizontal, 12)
    }

    // MARK: - Stats Grid

    private var statsGrid: some View {
        let columns = [GridItem(.flexible(), spacing: 12), GridItem(.flexible(), spacing: 12)]
        return LazyVGrid(columns: columns, spacing: 12) {
            statCard(icon: "bus.fill", iconBg: Color(hex: "5AC8FA"), label: "Most Used Bus", value: "Bus \(mostCheckedBus)", detail: nil)
            statCard(icon: "mappin.circle.fill", iconBg: Color(hex: "F5A623"), label: "Usual Stop", value: usualStop, detail: nil)
            statCard(icon: "heart.fill", iconBg: Color(hex: "4CD964"), label: "Most Used Place", value: favouritePlace, detail: nil)
            statCard(icon: "chart.line.uptrend.xyaxis", iconBg: Color(hex: "BF5AF2"), label: "Detected Trips", value: "\(totalCommutes)", detail: "from Live Board")
        }
    }

    private func statCard(icon: String, iconBg: Color, label: String, value: String, detail: String?) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack(spacing: 8) {
                Image(systemName: icon)
                    .font(.system(size: 13, weight: .bold))
                    .foregroundColor(.white)
                    .frame(width: 26, height: 26)
                    .background(iconBg)
                    .clipShape(RoundedRectangle(cornerRadius: 7))
                Text(label)
                    .font(.system(size: 12))
                    .foregroundColor(Color(hex: "8E8E93"))
            }
            .padding(.bottom, 10)

            dashedLine
                .padding(.horizontal, -16)
                .padding(.bottom, 8)

            Text(value)
                .font(.system(size: 18, weight: .bold))
                .foregroundColor(.primary)
                .lineLimit(1)
                .minimumScaleFactor(0.6)

            if let detail = detail {
                Text(detail)
                    .font(.system(size: 12))
                    .foregroundColor(Color(hex: "8E8E93"))
                    .padding(.top, 2)
            }
        }
        .frame(maxWidth: .infinity, minHeight: 120, alignment: .leading)
        .padding(16)
        .background(cardBg)
        .clipShape(RoundedRectangle(cornerRadius: 14))
    }

    private var tripHistory: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text("Your recorded trips").font(.headline)
            Text("Catch records trips from Live Board arrivals and strengthens them when location shows you were near the stop and moved away. These are estimates, not confirmed boardings. Simply opening Live Board doesn’t count.")
                .font(.footnote).foregroundStyle(.secondary)
            if logs.isEmpty {
                Text("No detected trips yet.").font(.subheadline.bold())
            }
            ForEach(Array(logs.sorted { $0.timestamp > $1.timestamp }.prefix(30).enumerated()), id: \.offset) { _, log in
                VStack(alignment: .leading, spacing: 4) {
                    Text("Bus \(log.busServices.joined(separator: ", ")) · \(log.stopName)").font(.subheadline.bold())
                    Text(log.timestamp, format: .dateTime.day().month().year().hour().minute()).font(.caption).foregroundStyle(.secondary)
                }
                Divider()
            }
            let olderCount = appState.commuteLogs().filter { $0.source != "detected" && $0.source != "live_board" }.count
            if olderCount > 0 {
                Text("\(olderCount) older records are preserved, but excluded from these totals because their trip source wasn’t recorded.")
                    .font(.footnote).foregroundStyle(.secondary)
            }
        }
        .padding(20).frame(maxWidth: .infinity, alignment: .leading)
        .background(cardBg, in: RoundedRectangle(cornerRadius: 16))
    }

    private var footer: some View {
        VStack(spacing: 8) {
            Image("CatchIcon")
                .resizable()
                .scaledToFill()
                .frame(width: 34, height: 34)
                .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
                .overlay(
                    RoundedRectangle(cornerRadius: 8, style: .continuous)
                        .stroke(Color.white.opacity(0.10), lineWidth: 1)
                )

            Text("Catch")
                .font(.system(size: 19, weight: .bold))
                .tracking(19 * -0.025)
                .foregroundColor(Color(hex: "555555"))
            Text("Made by Aditya Arya")
                .font(.system(size: 15, weight: .medium))
                .tracking(15 * -0.025)
                .foregroundColor(Color(hex: "444444"))
        }
        .frame(maxWidth: .infinity)
        .padding(.top, 20)
        .padding(.bottom, 12)
    }
}

private struct ProfileCloseButton: View {
    let action: () -> Void

    var body: some View {
        Button {
            Haptics.tap()
            action()
        } label: {
            Image(systemName: "xmark")
                .font(.system(size: 22, weight: .bold))
                .foregroundStyle(.secondary)
                .frame(width: 54, height: 54)
                .contentShape(Circle())
        }
        .buttonStyle(.plain)
        .glassEffect(.regular.interactive(), in: Circle())
        .accessibilityLabel("Close")
    }
}

// MARK: - Zigzag Shape

struct ZigzagShape: Shape {
    func path(in rect: CGRect) -> Path {
        var path = Path()
        let zigWidth: CGFloat = 10
        let zigHeight = rect.height
        let count = Int(ceil(rect.width / zigWidth))

        path.move(to: CGPoint(x: 0, y: 0))

        for i in 0..<count {
            let x = CGFloat(i) * zigWidth
            path.addLine(to: CGPoint(x: x + zigWidth / 2, y: zigHeight))
            path.addLine(to: CGPoint(x: x + zigWidth, y: 0))
        }

        path.addLine(to: CGPoint(x: rect.width, y: 0))
        path.closeSubpath()
        return path
    }
}
