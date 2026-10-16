import QuotaBarKit
import SwiftUI

/// The panel for one subscription: freshness header, one row per quota window,
/// then controls. Rendered inside an `NPPopover`, so this is ordinary SwiftUI —
/// bars, colour, and full-contrast text, not menu rows.
///
/// The snapshot is looked up from the model by id on every render rather than
/// being handed in as a value. The popover's hosting controller is built once,
/// so a snapshot captured at construction would pin the panel to whatever it
/// showed when the item was created — a panel stuck on "loading" forever while
/// the menu bar label and the provider picker both update.
struct SubscriptionMenuView: View {
    @ObservedObject var model: AppModel
    let subscriptionId: String

    var body: some View {
        Group {
            if let snapshot = model.snapshot(id: subscriptionId) {
                content(for: snapshot)
            } else {
                Text("Loading…")
                    .font(.system(size: 12))
                    .foregroundStyle(.secondary)
                    .frame(width: StatusItemHost.panelWidth, alignment: .leading)
                    .padding(12)
            }
        }
        .onAppear { model.refreshIfStale(id: subscriptionId) }
    }

    @ViewBuilder
    private func content(for snapshot: SubscriptionSnapshot) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            header(snapshot)
            Divider()
            body(snapshot)
            Divider()
            controls
        }
        .padding(12)
        .frame(width: StatusItemHost.panelWidth, alignment: .leading)
    }

    // MARK: - Header

    private func header(_ snapshot: SubscriptionSnapshot) -> some View {
        VStack(alignment: .leading, spacing: 3) {
            HStack(spacing: 6) {
                Text(snapshot.displayName)
                    .font(.system(size: 13, weight: .semibold))
                if snapshot.stale {
                    chip("stale", color: .orange)
                }
                Spacer(minLength: 4)
                Text(snapshot.verdict.glyph)
                    .font(.system(size: 12, weight: .bold))
                    .foregroundStyle(VerdictStyle.color(for: snapshot.verdict))
            }

            Text(ageText(snapshot))
                .font(.system(size: 11))
                .foregroundStyle(.tertiary)
        }
    }

    private func chip(_ text: String, color: Color) -> some View {
        Text(text)
            .font(.system(size: 10, weight: .medium))
            .padding(.horizontal, 4)
            .padding(.vertical, 1)
            .background(color.opacity(0.2), in: Capsule())
    }

    private func ageText(_ snapshot: SubscriptionSnapshot) -> String {
        let host = snapshot.endpoint.map { " · \($0.host ?? $0.absoluteString)" } ?? ""
        if let updatedAt = snapshot.updatedAt {
            return "updated \(DurationFormat.age(updatedAt, now: Clock.now()))\(host)"
        }
        if let attempted = snapshot.lastAttemptAt {
            return "no data · last tried \(DurationFormat.age(attempted, now: Clock.now()))\(host)"
        }
        return "fetching\(host)"
    }

    // MARK: - Body

    @ViewBuilder
    private func body(_ snapshot: SubscriptionSnapshot) -> some View {
        switch snapshot.state {
        case .loading:
            HStack(spacing: 6) {
                ProgressView().controlSize(.small)
                Text("Loading…").font(.system(size: 12))
            }
            .foregroundStyle(.secondary)
        case .error(let code):
            errorBody(snapshot, code: code)
        case .live:
            if snapshot.windows.isEmpty {
                Text("No quota windows reported.")
                    .font(.system(size: 12))
                    .foregroundStyle(.secondary)
            } else {
                VStack(alignment: .leading, spacing: 12) {
                    ForEach(snapshot.windows) { window in
                        WindowRowView(window: window)
                    }
                }
            }
        }
    }

    private func errorBody(_ snapshot: SubscriptionSnapshot, code: String) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(errorText(snapshot, code: code))
                .font(.system(size: 12, weight: .medium))
                .foregroundStyle(Color.red)
                .fixedSize(horizontal: false, vertical: true)
            Text("Credentials: \(model.credentialLocation(for: snapshot.id))")
                .font(.system(size: 10))
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    private func errorText(_ snapshot: SubscriptionSnapshot, code: String) -> String {
        guard let provider = model.provider(for: snapshot.id) else {
            return "Refresh failed (\(code))."
        }
        return QuotaErrorCode.displayText(for: code, provider: provider)
    }

    // MARK: - Controls

    private var controls: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 6) {
                refreshButton
                Spacer(minLength: 4)
                HStack(spacing: 4) {
                    Text("every")
                        .font(.system(size: 11))
                        .foregroundStyle(.secondary)
                    Picker("", selection: intervalBinding) {
                        ForEach(AppModel.intervalChoices, id: \.self) { ms in
                            Text(DurationFormat.duration(ms)).tag(ms)
                        }
                    }
                    .labelsHidden()
                    .pickerStyle(.menu)
                    .frame(width: 82)
                }
            }

            Divider()
            ProviderPicker(model: model)
            Divider()

            Button("Quit QuotaBar") { model.quit() }
                .buttonStyle(.borderless)
                .font(.system(size: 11))
        }
    }

    /// Refresh shows what it is doing: a spinner and a changed label while the
    /// request is in flight, and the data-age line updates the moment it lands.
    /// A button that silently does nothing reads as a broken button.
    @ViewBuilder
    private var refreshButton: some View {
        Button {
            model.refreshAll()
        } label: {
            HStack(spacing: 4) {
                if model.isRefreshing {
                    ProgressView().controlSize(.small).scaleEffect(0.7)
                    Text("Refreshing…").font(.system(size: 11))
                } else {
                    Image(systemName: "arrow.clockwise").font(.system(size: 10))
                    Text("Refresh").font(.system(size: 11))
                }
            }
        }
        .buttonStyle(.borderless)
        .disabled(model.isRefreshing)
    }

    private var intervalBinding: Binding<Double> {
        Binding(get: { model.settings.intervalMs }, set: { model.setInterval($0) })
    }
}

/// The provider picker: a single-selection popup naming the provider whose
/// limits the panel and the menu bar item are showing.
///
/// It replaces a checklist on purpose. A checklist could express "two providers
/// shown, one displayed" — which is exactly the state that made it unclear which
/// provider the panel was about. A single-selection control cannot represent
/// that, so the ambiguity is gone rather than documented.
struct ProviderPicker: View {
    @ObservedObject var model: AppModel

    /// Empty string means "none", which leaves only the recovery item.
    private static let noneTag = ""

    var body: some View {
        HStack(spacing: 4) {
            Text("provider")
                .font(.system(size: 11))
                .foregroundStyle(.secondary)
            Picker("", selection: selection) {
                ForEach(model.snapshots) { item in
                    Text(item.displayName).tag(item.id)
                }
                Text("Show none").tag(Self.noneTag)
            }
            .labelsHidden()
            .pickerStyle(.menu)
            .frame(width: 140)
        }
    }

    private var selection: Binding<String> {
        Binding(
            get: { model.selectedProviderId ?? Self.noneTag },
            set: { value in
                model.selectProvider(value == Self.noneTag ? nil : value)
            }
        )
    }
}

/// One colour per verdict, shared by the glyph and the usage bar so severity is
/// legible without reading the numbers.
enum VerdictStyle {
    static func color(for verdict: Verdict) -> Color {
        switch verdict {
        case .ok: .green
        case .tight: .yellow
        case .short: .orange
        case .blocked: .red
        case .unknown: .secondary
        }
    }
}