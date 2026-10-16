import QuotaBarKit
import SwiftUI

/// The panel for one subscription: freshness header, one row per quota window,
/// then controls. Rendered inside an `NPPopover`, so this is ordinary SwiftUI —
/// bars, colour, and full-contrast text, not menu rows.
///
/// The snapshot is looked up from the model on every render rather than being
/// handed in as a value, and which subscription to show is read from the model
/// rather than captured. The popover's hosting controller is built once for the
/// life of the app, so anything captured at construction pins the panel to
/// whatever it showed when the item was created - a panel stuck on "loading"
/// forever, or one that cannot follow a provider switch.
struct SubscriptionMenuView: View {
    @ObservedObject var model: AppModel

    var body: some View {
        Group {
            if let snapshot = model.shown {
                content(for: snapshot)
            } else {
                Text("Loading…")
                    .font(.system(size: 12))
                    .foregroundStyle(.secondary)
                    .frame(width: StatusItemHost.panelWidth, alignment: .leading)
                    .padding(12)
            }
        }
        .onAppear { if let id = model.shown?.id { model.refreshIfStale(id: id) } }
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

    /// Actions on the left, settings on the right, both columns two rows deep.
    /// One grid rather than three bands with dividers: the bands separated
    /// controls that belonged together and let each row pick its own width.
    private var controls: some View {
        HStack(alignment: .top, spacing: ControlGrid.columnSpacing) {
            VStack(alignment: .leading, spacing: ControlGrid.rowSpacing) {
                refreshButton
                quitButton
            }
            Spacer(minLength: 0)
            VStack(alignment: .leading, spacing: ControlGrid.rowSpacing) {
                intervalPicker
                ProviderPicker(model: model)
            }
            .frame(width: ControlGrid.columnWidth, alignment: .leading)
        }
    }

    private var intervalPicker: some View {
        ControlGrid.row(label: "every") {
            Picker("", selection: intervalBinding) {
                ForEach(AppModel.intervalChoices, id: \.self) { ms in
                    Text(DurationFormat.duration(ms)).tag(ms)
                }
            }
            .labelsHidden()
            .pickerStyle(.menu)
            .frame(width: ControlGrid.pickerWidth)
        }
    }

    private var quitButton: some View {
        Button("Quit QuotaBar") { model.quit() }
            .buttonStyle(.borderless)
            .font(.system(size: 11))
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
        ControlGrid.row(label: "provider") {
            Picker("", selection: selection) {
                ForEach(model.snapshots) { item in
                    Text(item.displayName).tag(item.id)
                }
                Text("Show none").tag(Self.noneTag)
            }
            .labelsHidden()
            .pickerStyle(.menu)
            .frame(width: ControlGrid.pickerWidth)
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

/// Shared metrics for the panel's controls.
///
/// Every labelled control is built through `row(label:content:)`, so the label
/// column and the picker column have one width each. Without this each control
/// sized itself: "every" and "provider" are different words, and the two
/// pickers were separately framed at 82 and 140 points, so nothing lined up.
enum ControlGrid {
    static let labelWidth: CGFloat = 46
    static let pickerWidth: CGFloat = 104
    static let columnWidth: CGFloat = labelWidth + 4 + pickerWidth
    static let columnSpacing: CGFloat = 8
    static let rowSpacing: CGFloat = 6

    static func row<Content: View>(label: String, @ViewBuilder content: () -> Content) -> some View {
        HStack(spacing: 4) {
            Text(label)
                .font(.system(size: 11))
                .foregroundStyle(.secondary)
                .frame(width: labelWidth, alignment: .leading)
            content()
        }
    }
}
