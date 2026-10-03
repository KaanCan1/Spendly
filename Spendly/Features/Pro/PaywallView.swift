import SpendlyCore
import SpendlyUI
import StoreKit
import SwiftUI

/// Why someone hit the paywall, so the sheet can lead with the thing they were trying to do.
enum ProFeature: Identifiable {
    case categories
    case budgets
    case export
    case general

    var id: Self { self }

    var reason: LocalizedStringKey {
        switch self {
        case .categories: "the free version includes \(ProLimits.freeCustomCategories) categories of your own."
        case .budgets: "the free version includes \(ProLimits.freeBudgets) monthly budget."
        case .export: "csv export is part of spendly pro."
        case .general: "support spendly and unlock everything."
        }
    }
}

struct PaywallView: View {
    let feature: ProFeature

    @Environment(ProStore.self) private var pro
    @Environment(\.dismiss) private var dismiss
    @State private var errorMessage: String?

    var body: some View {
        VStack(alignment: .leading, spacing: 24) {
            HStack {
                Spacer()
                Button { dismiss() } label: {
                    Image(systemName: "xmark")
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundStyle(SpendlyColor.muted)
                        .frame(width: 36, height: 36)
                        .background(Circle().fill(SpendlyColor.raised))
                }
                .accessibilityLabel(Text("close"))
                .accessibilityIdentifier("paywallClose")
            }

            VStack(alignment: .leading, spacing: 8) {
                Text("spendly pro")
                    .accessibilityIdentifier("paywallTitle")
                    .font(SpendlyFont.number(40, .light))
                    .tracking(SpendlyFont.tracking(for: 40))
                    .foregroundStyle(SpendlyColor.ink)
                Text(feature.reason)
                    .font(SpendlyFont.body)
                    .foregroundStyle(SpendlyColor.muted)
            }

            VStack(alignment: .leading, spacing: 14) {
                benefit("square.grid.2x2", "unlimited categories")
                benefit("chart.bar", "a budget for every category")
                benefit("square.and.arrow.up", "csv export")
                benefit("heart", "support an independent app")
            }

            Spacer(minLength: 0)

            plans

            HStack {
                Button("restore purchases") { Task { await pro.restore() } }
                    .accessibilityIdentifier("restoreButton")
                Spacer()
                Text("cancel anytime in settings")
            }
            .font(SpendlyFont.caption)
            .foregroundStyle(SpendlyColor.muted)
        }
        .padding(24)
        .background(SpendlyColor.canvas.ignoresSafeArea())
        .presentationCornerRadius(SpendlyRadius.surface)
        .onChange(of: pro.isPro) { _, isPro in
            if isPro { dismiss() }
        }
        .alert(Text("purchase failed"), isPresented: .constant(errorMessage != nil)) {
            Button("OK") { errorMessage = nil }
        } message: {
            Text(errorMessage ?? "")
        }
    }

    private func benefit(_ symbol: String, _ title: LocalizedStringKey) -> some View {
        HStack(spacing: 14) {
            Image(systemName: symbol)
                .font(.system(size: 16, weight: .medium))
                .foregroundStyle(SpendlyColor.signature)
                .frame(width: 24)
            Text(title)
                .font(SpendlyFont.body)
                .foregroundStyle(SpendlyColor.ink)
        }
    }

    @ViewBuilder
    private var plans: some View {
        switch pro.loadState {
        case .loading:
            ProgressView()
                .frame(maxWidth: .infinity, minHeight: 120)
        case .unavailable:
            VStack(spacing: 12) {
                Text("the app store isn't reachable right now.")
                    .accessibilityIdentifier("storeUnavailable")
                    .font(SpendlyFont.caption)
                    .foregroundStyle(SpendlyColor.muted)
                Button("try again") { Task { await pro.loadProducts() } }
                    .buttonStyle(PillButtonStyle(.quiet))
            }
            .frame(maxWidth: .infinity, minHeight: 120)
        case .loaded:
            VStack(spacing: 10) {
                if let monthly = pro.monthly {
                    planButton(monthly, title: "monthly", detail: Text("\(monthly.displayPrice) / month"), highlighted: false)
                }
                if let lifetime = pro.lifetime {
                    planButton(lifetime, title: "lifetime", detail: Text("\(lifetime.displayPrice) once"), highlighted: true)
                }
            }
        }
    }

    private func planButton(_ product: Product, title: LocalizedStringKey, detail: Text, highlighted: Bool) -> some View {
        Button {
            Task {
                do {
                    try await pro.purchase(product)
                } catch {
                    errorMessage = error.localizedDescription
                }
            }
        } label: {
            HStack {
                Text(title)
                    .font(SpendlyFont.pill)
                Spacer()
                if pro.purchasing == product.id {
                    ProgressView().tint(highlighted ? SpendlyColor.onSignature : SpendlyColor.ink)
                } else {
                    detail.font(SpendlyFont.number(.subheadline, .medium))
                }
            }
            .foregroundStyle(highlighted ? SpendlyColor.onSignature : SpendlyColor.ink)
            .padding(.horizontal, 20)
            .frame(height: 56)
            .background(
                RoundedRectangle(cornerRadius: 18, style: .continuous)
                    .fill(highlighted ? SpendlyColor.signature : SpendlyColor.raised)
            )
        }
        .buttonStyle(.plain)
        .disabled(pro.purchasing != nil)
        .accessibilityIdentifier("plan-\(product.id)")
    }
}
