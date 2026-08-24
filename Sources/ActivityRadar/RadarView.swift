import ActivityRadarCore
import AppKit
import SwiftUI

private enum RadarRelativeTime {
    static func text(
        _ date: Date,
        language: RadarLanguage,
        relativeTo now: Date = Date()
    ) -> String {
        RadarL10n(language: language).relativeTime(date, relativeTo: now)
    }
}

private enum RadarColors {
    static let text = Color(nsColor: NSColor(calibratedRed: 0.15, green: 0.15, blue: 0.19, alpha: 1))
    static let secondary = Color(nsColor: NSColor(calibratedWhite: 0.39, alpha: 1))
    static let muted = Color(nsColor: NSColor(calibratedWhite: 0.46, alpha: 1))
    static let line = Color(nsColor: NSColor(calibratedWhite: 0.88, alpha: 1))
    static let blue = Color(red: 0.125, green: 0.424, blue: 0.957)
    static let blueSoft = Color(red: 0.93, green: 0.95, blue: 1)
    static let amber = Color(red: 0.925, green: 0.596, blue: 0.094)
    static let amberSoft = Color(red: 1, green: 0.96, blue: 0.89)
    static let green = Color(red: 0.22, green: 0.69, blue: 0.35)
    static let greenText = Color(red: 0.10, green: 0.43, blue: 0.19)
    static let greenSoft = Color(red: 0.91, green: 0.98, blue: 0.93)
    static let red = Color(red: 0.83, green: 0.24, blue: 0.23)
    static let redSoft = Color(red: 1, green: 0.92, blue: 0.92)
    static let graySoft = Color(nsColor: NSColor(calibratedWhite: 0.94, alpha: 1))
}

struct RadarView: View {
    @ObservedObject var model: RadarViewModel
    let onDismiss: () -> Void

    @FocusState private var searchFocused: Bool
    @State private var eventMonitor: Any?
    @State private var continuityItem: ActivityItem?
    @State private var showsWingman = false
    @State private var showsResearchClearConfirmation = false
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        ZStack {
            VisualEffectView(material: .popover, blendingMode: .behindWindow)

            VStack(spacing: 0) {
                searchHeader
                summaryBar
                taskList
                statusBanner
                footer
            }
            .background(Color.white.opacity(0.965))
        }
        .frame(minWidth: 780, idealWidth: 930, maxWidth: 1_080, minHeight: 620, idealHeight: 724, maxHeight: 840)
        .environment(\.locale, l10n.locale)
        .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .stroke(Color.white.opacity(0.75), lineWidth: 1)
        }
        .onAppear {
            installKeyboardMonitor()
            focusSearch()
        }
        .onDisappear {
            removeKeyboardMonitor()
        }
        .onReceive(NotificationCenter.default.publisher(for: .activityRadarDidShow)) { _ in
            focusSearch()
        }
        .onChange(of: model.query) { _ in
            model.queryDidChange()
            model.ensureSelection()
        }
        .onChange(of: model.scope) { _ in
            model.scopeDidChange()
        }
        .onChange(of: model.dateRange) { _ in
            model.dateRangeDidChange()
        }
        .sheet(item: $continuityItem) { item in
            RadarContinuityEditor(
                itemTitle: item.title,
                checkpoint: item.checkpoint,
                language: model.language,
                initialMetadata: model.continuityMetadata(for: item),
                hasStoredPlan: model.hasContinuityPlan(for: item),
                onSave: { importance, deadline, nextAction, waitingOn, snoozeUntil in
                    model.saveContinuity(
                        for: item,
                        importance: importance,
                        deadline: deadline,
                        nextAction: nextAction,
                        waitingOn: waitingOn,
                        snoozeUntil: snoozeUntil
                    )
                },
                onClear: {
                    model.clearContinuity(for: item)
                }
            )
        }
        .sheet(isPresented: $showsWingman) {
            WingmanView(language: model.language)
        }
        .alert(
            l10n.text(
                "Yerel araştırma olayları silinsin mi?",
                "Delete local research events?"
            ),
            isPresented: $showsResearchClearConfirmation
        ) {
            Button(l10n.text("Sil", "Delete"), role: .destructive) {
                model.clearResearchLedger()
            }
            Button(l10n.text("Vazgeç", "Cancel"), role: .cancel) {}
        } message: {
            Text(l10n.text(
                "Bu işlem yalnızca AiWingman’in sabit şemalı, görev metni içermeyen araştırma günlüğünü temizler; Codex görevlerine ve park planlarına dokunmaz.",
                "This clears only AiWingman's fixed-schema, task-text-free research log; it does not touch Codex tasks or parked plans."
            ))
        }
        .alert(
            l10n.text(
                "Görev metni içermeyen araştırma kaydı dışa aktarılsın mı?",
                "Export the task-text-free research log?"
            ),
            isPresented: Binding(
                get: { model.researchExportPreview != nil },
                set: { isPresented in
                    if !isPresented {
                        model.cancelResearchExport()
                    }
                }
            )
        ) {
            Button(l10n.text("Dosya seç…", "Choose File…")) {
                model.confirmResearchExport()
            }
            Button(l10n.text("Vazgeç", "Cancel"), role: .cancel) {
                model.cancelResearchExport()
            }
        } message: {
            Text(model.researchExportPreviewSummary ?? l10n.text("Önizleme hazırlanıyor…", "Preparing preview…"))
        }
    }

    private var l10n: RadarL10n {
        model.l10n
    }

    private var searchHeader: some View {
        HStack(spacing: 12) {
            Image(systemName: "magnifyingglass")
                .font(.system(size: 20, weight: .regular))
                .foregroundStyle(RadarColors.muted)

            TextField(l10n.text("Görev ara veya geç…", "Search or switch tasks…"), text: $model.query)
                .textFieldStyle(.plain)
                .font(.system(size: 16))
                .foregroundStyle(RadarColors.text)
                .focused($searchFocused)
                .accessibilityLabel(l10n.text("Görev ara veya geç", "Search or switch tasks"))

            if !model.query.isEmpty {
                Button {
                    model.query = ""
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundStyle(RadarColors.muted)
                }
                .buttonStyle(.plain)
                .accessibilityLabel(l10n.text("Aramayı temizle", "Clear search"))
            }

            Button {
                showsWingman = true
            } label: {
                Label(
                    l10n.text("Bir Wingman Çağır", "Call a Wingman"),
                    systemImage: "person.crop.circle.badge.sparkles"
                )
                    .font(.system(size: 12, weight: .semibold))
            }
            .buttonStyle(.borderedProminent)
            .tint(RadarColors.blue)
            .help(l10n.text(
                "Yoğun işleri, soru ağını, harness'i ve token sinyallerini gözden geçir",
                "Review busy work, question graphs, the harness, and token signals"
            ))
            .accessibilityLabel(l10n.text("Bir Wingman çağır", "Call a Wingman"))

            Button {
                model.refresh()
            } label: {
                Label(l10n.text("Şimdi yenile", "Refresh now"), systemImage: "arrow.clockwise")
                    .labelStyle(.iconOnly)
                    .font(.system(size: 13, weight: .semibold))
                    .opacity(model.isRefreshing ? 0.45 : 1)
            }
            .buttonStyle(.plain)
            .foregroundStyle(RadarColors.muted)
            .help(l10n.text("Şimdi yenile", "Refresh now"))

            Menu {
                Toggle(
                    l10n.text("Sabit şemalı, görev metni içermeyen yerel araştırma kaydı", "Fixed-schema, task-text-free local research log"),
                    isOn: Binding(
                        get: { model.researchLoggingEnabled },
                        set: { model.setResearchLoggingEnabled($0) }
                    )
                )
                Divider()
                Text(l10n.text(
                    "\(model.researchEventCount) olay · son 90 gün · ağ aktarımı yok",
                    "\(model.researchEventCount) events · last 90 days · no network transfer"
                ))
                Button(l10n.text("Önizle ve dışa aktar…", "Preview and Export…")) {
                    model.prepareResearchExport()
                }
                .disabled(model.researchEventCount == 0)
                Button(l10n.text("Yerel olayları temizle…", "Clear Local Events…"), role: .destructive) {
                    showsResearchClearConfirmation = true
                }
                .disabled(model.researchEventCount == 0)
            } label: {
                Image(systemName: model.researchLoggingEnabled ? "checkmark.shield.fill" : "shield")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(model.researchLoggingEnabled ? RadarColors.greenText : RadarColors.muted)
            }
            .menuStyle(.borderlessButton)
            .fixedSize()
            .help(l10n.text("Gizlilik korumalı araştırma modu", "Privacy-preserving research mode"))
            .accessibilityLabel(l10n.text("Gizlilik korumalı araştırma modu", "Privacy-preserving research mode"))

            Menu {
                ForEach(RadarLanguage.allCases) { language in
                    Button {
                        model.language = language
                    } label: {
                        Label(
                            language.displayName(in: model.language),
                            systemImage: model.language == language ? "checkmark" : "character"
                        )
                    }
                }
            } label: {
                Text(model.language.compactTitle)
                    .font(.system(size: 11, weight: .bold, design: .rounded))
                    .frame(minWidth: 27)
            }
            .menuStyle(.borderlessButton)
            .fixedSize()
            .help(l10n.text("Arayüz dili", "Interface language"))
            .accessibilityLabel(l10n.text("Arayüz dili", "Interface language"))
            .accessibilityValue(model.language.displayName(in: model.language))

            KeyCap(text: "⌘⇧K")
        }
        .padding(.horizontal, 14)
        .frame(height: 52)
        .background(
            RoundedRectangle(cornerRadius: 11, style: .continuous)
                .fill(Color.white)
                .shadow(color: searchFocused ? RadarColors.blue.opacity(0.12) : .clear, radius: 0, x: 0, y: 0)
        )
        .overlay {
            RoundedRectangle(cornerRadius: 11, style: .continuous)
                .stroke(searchFocused ? RadarColors.blue.opacity(0.5) : Color(nsColor: .separatorColor), lineWidth: 1)
        }
        .padding(.horizontal, 14)
        .padding(.top, 13)
        .padding(.bottom, 1)
    }

    private var summaryBar: some View {
        HStack(spacing: 18) {
            SummaryMetric(
                color: RadarColors.blue,
                text: l10n.text(
                    "\(model.recentlyActiveCount) açık turn · ≤2 dk",
                    "\(model.recentlyActiveCount) open turns · ≤2 min"
                )
            )
            SummaryMetric(
                color: RadarColors.amber,
                text: l10n.text(
                    "\(model.attentionCount) dikkat istiyor",
                    "\(model.attentionCount) need attention"
                )
            )
            SummaryMetric(
                color: RadarColors.green,
                text: l10n.text(
                    "\(model.newResultCount) yeni sonuç",
                    "\(model.newResultCount) new results"
                )
            )

            Spacer(minLength: 8)

            if model.scope == .all || !model.query.isEmpty {
                Picker(l10n.text("Tarih aralığı", "Date range"), selection: $model.dateRange) {
                    ForEach(RadarDateRange.allCases) { range in
                        Text(l10n.dateRangeTitle(range)).tag(range)
                    }
                }
                .labelsHidden()
                .pickerStyle(.menu)
                .controlSize(.small)
                .frame(width: 140)
            }

            Picker(l10n.text("Görünüm", "View"), selection: $model.scope) {
                ForEach(RadarScope.allCases) { scope in
                    Text(l10n.scopeTitle(scope)).tag(scope)
                }
            }
            .labelsHidden()
            .pickerStyle(.segmented)
            .frame(width: 118)
        }
        .padding(.horizontal, 25)
        .frame(height: 50)
        .font(.system(size: 14))
        .foregroundStyle(RadarColors.secondary)
        .overlay(alignment: .bottom) {
            Divider()
        }
    }

    private var taskList: some View {
        let visibleItems = model.filteredItems
        return ScrollViewReader { proxy in
            ScrollView {
                LazyVStack(spacing: 0) {
                    if model.isRefreshing && model.items.isEmpty {
                        loadingState
                    } else if model.isSearching && visibleItems.isEmpty {
                        searchLoadingState
                    } else if visibleItems.isEmpty {
                        emptyState
                    } else {
                        if model.scope == .focus,
                           model.query.isEmpty,
                           let abstention = model.triageAbstentionText {
                            HStack(spacing: 8) {
                                Image(systemName: "hand.raised.fill")
                                    .foregroundStyle(RadarColors.secondary)
                                Text(l10n.text("Tek öneri yok", "No single recommendation") + " · \(abstention)")
                                    .font(.system(size: 12, weight: .medium))
                                    .foregroundStyle(RadarColors.secondary)
                                Spacer()
                            }
                            .padding(.horizontal, 12)
                            .frame(minHeight: 36)
                            .background(RadarColors.graySoft)
                            .accessibilityElement(children: .combine)
                            .accessibilityLabel(
                                l10n.text("Tek öneri yok", "No single recommendation") + ". \(abstention)"
                            )
                        }
                        ForEach(Array(visibleItems.enumerated()), id: \.element.id) { index, item in
                            if let section = model.focusSection(for: item),
                               index == 0 || model.focusSection(for: visibleItems[index - 1]) != section {
                                FocusSectionHeader(
                                    title: model.focusSectionTitle(section),
                                    language: model.language
                                )
                            }
                            RadarTaskRow(
                                item: item,
                                language: model.language,
                                selected: model.selectedID == item.id,
                                isLastOpened: model.isLastOpened(item),
                                lifecycleLabel: model.lifecycleLabel(for: item),
                                lifecycleOverride: model.lifecycleOverride(for: item),
                                continuityMetadata: model.continuityMetadata(for: item),
                                triageReasons: model.triageReasonLabels(for: item),
                                recommended: model.isRecommended(item),
                                lifecycleEvidenceSummary: model.lifecycleEvidenceSummary(for: item),
                                showsLifecycleMenu: true,
                                onSelect: { model.select(item) },
                                onOpen: { model.open(item) },
                                onPark: { continuityItem = item },
                                onSetLifecycleOverride: {
                                    model.setLifecycleOverride($0, for: item)
                                }
                            )
                            .id(item.id)
                        }
                    }
                }
                .padding(.horizontal, 14)
            }
            .onChange(of: model.selectedID) { id in
                guard let id else { return }
                if reduceMotion {
                    proxy.scrollTo(id, anchor: .center)
                } else {
                    withAnimation(.easeOut(duration: 0.16)) {
                        proxy.scrollTo(id, anchor: .center)
                    }
                }
            }
        }
    }

    @ViewBuilder
    private var statusBanner: some View {
        if let error = model.errorMessage {
            HStack(spacing: 8) {
                Image(systemName: "exclamationmark.triangle.fill")
                    .foregroundStyle(RadarColors.amber)
                Text(error)
                    .lineLimit(2)
                Spacer()
                Button(l10n.text("Yeniden dene", "Try Again")) {
                    model.refresh()
                }
                .buttonStyle(.link)
            }
            .font(.system(size: 12))
            .foregroundStyle(RadarColors.secondary)
            .padding(.horizontal, 16)
            .frame(minHeight: 36)
            .background(RadarColors.amberSoft)
        } else if let message = model.actionMessage {
            HStack(spacing: 8) {
                Image(systemName: "info.circle.fill")
                    .foregroundStyle(RadarColors.blue)
                Text(message)
                    .lineLimit(1)
                Spacer()
            }
            .font(.system(size: 12))
            .foregroundStyle(RadarColors.secondary)
            .padding(.horizontal, 16)
            .frame(height: 34)
            .background(RadarColors.blueSoft)
        }
    }

    private var footer: some View {
        HStack(spacing: 18) {
            FooterHint(keys: ["↑", "↓"], label: l10n.text("Gezin", "Navigate"))
            FooterHint(keys: ["Enter"], label: l10n.text("Göreve dön", "Open task"))
            FooterHint(keys: ["Esc"], label: l10n.text("Kapat", "Close"))

            Spacer()

            if model.scope == .focus, model.query.isEmpty, !model.items.isEmpty {
                Text(
                    l10n.text(
                        "\(model.filteredItems.count)/\(model.items.count) odakta",
                        "\(model.filteredItems.count)/\(model.items.count) in focus"
                    )
                    + (model.triageAbstentionText == nil ? "" : " · " + l10n.text("tek öneri yok", "no single recommendation"))
                )
                    .foregroundStyle(RadarColors.muted)
                    .help(model.triageAbstentionText ?? l10n.text(
                        "Açıklanabilir portföy triyajı",
                        "Explainable portfolio triage"
                    ))
            } else if model.query.isEmpty, model.scope == .all {
                Text(
                    l10n.text(
                        "\(model.filteredItems.count) görev",
                        "\(model.filteredItems.count) tasks"
                    )
                    + " · \(l10n.dateRangeTitle(model.dateRange))"
                    + (model.isHistoryCapped
                        ? " · " + l10n.text("daha eski işler var", "older work exists")
                        : "")
                )
                .foregroundStyle(RadarColors.muted)
            } else if !model.query.isEmpty {
                Text(
                    l10n.text(
                        "\(model.filteredItems.count) sonuç",
                        "\(model.filteredItems.count) results"
                    )
                    + " · \(l10n.dateRangeTitle(model.dateRange))"
                    + (model.isHistoryCapped
                        ? " · " + l10n.text("daha fazlası var", "more results exist")
                        : "")
                )
                    .foregroundStyle(RadarColors.muted)
            }
            if let updated = model.lastRefreshAt {
                Text(l10n.text("Yerel veri", "Local data") + " · "
                    + RadarRelativeTime.text(updated, language: model.language))
                    .foregroundStyle(RadarColors.greenText)
            }
            Text(l10n.text("AiWingman · İş Sürekliliği", "AiWingman · Work Continuity"))
                .foregroundStyle(RadarColors.muted)
        }
        .padding(.horizontal, 14)
        .frame(height: 46)
        .font(.system(size: 12))
        .foregroundStyle(RadarColors.secondary)
        .background(Color(nsColor: NSColor(calibratedWhite: 0.985, alpha: 1)))
        .overlay(alignment: .top) {
            Divider()
        }
    }

    private var emptyState: some View {
        VStack(spacing: 9) {
            Image(systemName: "scope")
                .font(.system(size: 28, weight: .regular))
                .foregroundStyle(RadarColors.muted)
            Text(emptyStateTitle)
                .font(.system(size: 15, weight: .semibold))
                .foregroundStyle(RadarColors.text)
            Text(emptyStateDescription)
                .font(.system(size: 13))
                .foregroundStyle(RadarColors.muted)
            if model.query.isEmpty, model.scope == .focus {
                Button(l10n.text("Tüm görevleri göster", "Show All Tasks")) {
                    model.scope = .all
                }
                .buttonStyle(.bordered)
            } else if model.query.isEmpty, model.dateRange != .all {
                Button(l10n.text("Tüm zamanları göster", "Show All Time")) {
                    model.dateRange = .all
                }
                .buttonStyle(.bordered)
            } else if model.query.isEmpty {
                Button(l10n.text("Yenile", "Refresh")) {
                    model.refresh()
                }
                .buttonStyle(.bordered)
            } else {
                HStack(spacing: 10) {
                    Button(l10n.text("Aramayı temizle", "Clear Search")) {
                        model.query = ""
                    }
                    if model.dateRange != .all {
                        Button(l10n.text("Tüm zamanlarda ara", "Search All Time")) {
                            model.dateRange = .all
                        }
                    }
                }
                .buttonStyle(.bordered)
            }
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 90)
    }

    private var emptyStateTitle: String {
        if !model.query.isEmpty {
            return l10n.text("Eşleşen görev yok", "No matching tasks")
        }
        if model.scope == .focus {
            return l10n.text("Şu anda odak gerektiren görev yok", "No tasks need focus right now")
        }
        return l10n.text("Bu tarih aralığında görev yok", "No tasks in this date range")
    }

    private var emptyStateDescription: String {
        if model.isSearching {
            return l10n.text(
                "\(l10n.dateRangeTitle(model.dateRange)) içindeki yerel görevlerde aranıyor…",
                "Searching local tasks in \(l10n.dateRangeTitle(model.dateRange))…"
            )
        }
        if !model.query.isEmpty {
            return l10n.text(
                "Başlığı, projeyi veya son hareketi ara.",
                "Search the title, project, or latest activity."
            )
        }
        if model.scope == .focus {
            return l10n.text(
                "Tümü görünümüne geçebilir veya yenileyebilirsin.",
                "You can switch to All or refresh."
            )
        }
        return l10n.text(
            "Tarih aralığını genişleterek daha eski işleri geri getirebilirsin.",
            "Expand the date range to bring back older work."
        )
    }

    private var loadingState: some View {
        VStack(spacing: 11) {
            ProgressView()
                .controlSize(.small)
            Text(l10n.text(
                "Codex görevleri salt-okunur yükleniyor…",
                "Loading Codex tasks read-only…"
            ))
                .font(.system(size: 13))
                .foregroundStyle(RadarColors.muted)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 100)
    }

    private var searchLoadingState: some View {
        VStack(spacing: 11) {
            ProgressView()
                .controlSize(.small)
            Text(l10n.text(
                "\(l10n.dateRangeTitle(model.dateRange)) içindeki yerel görevlerde aranıyor…",
                "Searching local tasks in \(l10n.dateRangeTitle(model.dateRange))…"
            ))
                .font(.system(size: 13))
                .foregroundStyle(RadarColors.muted)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 100)
    }

    private func focusSearch() {
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.08) {
            searchFocused = true
        }
    }

    private func installKeyboardMonitor() {
        guard eventMonitor == nil else { return }
        eventMonitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { event in
            if event.modifierFlags.contains(.command),
               event.charactersIgnoringModifiers?.lowercased() == "f" {
                searchFocused = true
                return nil
            }

            let protectedModifiers = event.modifierFlags.intersection([.command, .control, .option])
            guard protectedModifiers.isEmpty else {
                return event
            }

            if controlOwnsNavigationKeys(event) {
                return event
            }

            switch event.keyCode {
            case 125:
                model.moveSelection(by: 1)
                return nil
            case 126:
                model.moveSelection(by: -1)
                return nil
            case 36, 76:
                model.openSelected()
                return nil
            case 53:
                onDismiss()
                return nil
            default:
                return event
            }
        }
    }

    private func controlOwnsNavigationKeys(_ event: NSEvent) -> Bool {
        guard [36, 53, 76, 125, 126].contains(event.keyCode) else {
            return false
        }
        if continuityItem != nil {
            return true
        }
        if showsWingman {
            return true
        }
        if event.window?.level == .popUpMenu {
            return true
        }
        guard let responder = NSApp.keyWindow?.firstResponder else {
            return false
        }
        if responder is NSPopUpButton
            || responder is NSButton
            || responder is NSTextField
            || responder is NSTextView
            || responder is NSDatePicker {
            return true
        }
        let className = String(describing: type(of: responder)).lowercased()
        return className.contains("popup") || className.contains("menu")
    }

    private func removeKeyboardMonitor() {
        if let eventMonitor {
            NSEvent.removeMonitor(eventMonitor)
            self.eventMonitor = nil
        }
    }

}

private struct FocusSectionHeader: View {
    let title: String
    let language: RadarLanguage

    var body: some View {
        Text(title.uppercased(with: Locale(identifier: language.localeIdentifier)))
            .font(.system(size: 11, weight: .semibold))
            .tracking(0.6)
            .foregroundStyle(RadarColors.muted)
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal, 12)
            .padding(.top, 13)
            .padding(.bottom, 5)
            .accessibilityAddTraits(.isHeader)
    }
}

private struct RadarTaskRow: View {
    let item: ActivityItem
    let language: RadarLanguage
    let selected: Bool
    let isLastOpened: Bool
    let lifecycleLabel: RadarLifecycleLabel?
    let lifecycleOverride: RadarLifecycleOverride?
    let continuityMetadata: WorkContinuityMetadata
    let triageReasons: [String]
    let recommended: Bool
    let lifecycleEvidenceSummary: String?
    let showsLifecycleMenu: Bool
    let onSelect: () -> Void
    let onOpen: () -> Void
    let onPark: () -> Void
    let onSetLifecycleOverride: (RadarLifecycleOverride?) -> Void
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    private var l10n: RadarL10n {
        RadarL10n(language: language)
    }

    var body: some View {
        VStack(spacing: 0) {
            Button(action: onSelect) {
                HStack(spacing: 12) {
                    statusIcon

                    VStack(alignment: .leading, spacing: 5) {
                        HStack(spacing: 8) {
                            Text(item.title)
                                .font(.system(size: 16, weight: .semibold))
                                .foregroundStyle(RadarColors.text)
                                .lineLimit(1)

                            if isLastOpened {
                                Text(l10n.text("Son açma isteği", "Last open request"))
                                    .font(.system(size: 11, weight: .semibold))
                                    .foregroundStyle(RadarColors.blue)
                                    .padding(.horizontal, 8)
                                    .padding(.vertical, 3)
                                    .background(RadarColors.blueSoft, in: Capsule())
                            }

                            if recommended {
                                Text(l10n.text("Şimdi bak", "Look now"))
                                    .font(.system(size: 11, weight: .semibold))
                                    .foregroundStyle(RadarColors.blue)
                                    .padding(.horizontal, 8)
                                    .padding(.vertical, 3)
                                    .background(RadarColors.blueSoft, in: Capsule())
                                    .fixedSize()
                            }

                            if let pill = signalPill {
                                Text(pill.text)
                                    .font(.system(size: 11, weight: .semibold))
                                    .foregroundStyle(pill.color)
                                    .padding(.horizontal, 8)
                                    .padding(.vertical, 3)
                                    .background(pill.background, in: Capsule())
                                    .fixedSize()
                            }

                            if let lifecycleLabel {
                                let pill = lifecyclePill(for: lifecycleLabel)
                                Text(pill.text)
                                    .font(.system(size: 11, weight: .semibold))
                                    .foregroundStyle(pill.color)
                                    .padding(.horizontal, 8)
                                    .padding(.vertical, 3)
                                    .background(pill.background, in: Capsule())
                                    .fixedSize()
                            }
                        }

                        HStack(spacing: 7) {
                            Text(item.projectName)
                            Circle()
                                .fill(statusColor)
                                .frame(width: 5, height: 5)
                            Text(statusText)
                        }
                        .font(.system(size: 13))
                        .foregroundStyle(RadarColors.secondary)
                        .lineLimit(1)
                    }

                    Spacer(minLength: 12)

                    Text(l10n.text("Hareket", "Activity") + " · "
                        + l10n.timeLabel(item.timelineActivityAt))
                        .font(.system(size: 12))
                        .foregroundStyle(RadarColors.muted)

                    Image(systemName: selected ? "chevron.up" : "chevron.right")
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundStyle(RadarColors.muted)
                        .frame(width: 18)
                }
                .padding(.horizontal, 12)
                .frame(minHeight: 68)
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .help(
                "\(item.cwd)\n"
                    + l10n.text("Son anlamlı hareket", "Last meaningful activity")
                    + ": \(l10n.fullDateTime(item.timelineActivityAt))"
            )
            .accessibilityElement(children: .ignore)
            .accessibilityLabel(rowAccessibilityLabel)
            .accessibilityHint(selected
                ? l10n.text("Ayrıntıları kapatır", "Collapses details")
                : l10n.text("Ayrıntıları açar", "Expands details"))
            .accessibilityValue(selected
                ? l10n.text("Seçili; ayrıntılar açık", "Selected; details expanded")
                : l10n.text("Ayrıntılar kapalı", "Details collapsed"))

            if selected {
                details
                    .transition(.opacity.combined(with: .move(edge: .top)))
            }
        }
        .background(selected ? RadarColors.blueSoft.opacity(0.65) : Color.clear)
        .overlay {
            if selected {
                RoundedRectangle(cornerRadius: 10, style: .continuous)
                    .stroke(RadarColors.blue, lineWidth: 1.5)
            } else {
                VStack {
                    Spacer()
                    Divider()
                }
            }
        }
        .clipShape(RoundedRectangle(cornerRadius: selected ? 10 : 0, style: .continuous))
        .animation(reduceMotion ? nil : .easeOut(duration: 0.15), value: selected)
    }

    private var details: some View {
        VStack(spacing: 0) {
            Divider()
                .padding(.leading, 64)

            HStack(alignment: .top, spacing: 22) {
                DetailBlock(
                    title: l10n.text("Son ajan mesajı", "Latest agent message"),
                    text: item.checkpoint,
                    footer: item.historyComplete
                        ? nil
                        : l10n.text("Geçmişin son bölümü tarandı", "Only the latest part of history was scanned")
                )

                Divider()

                DetailBlock(
                    title: l10n.text("Son anlamlı hareket", "Last meaningful activity"),
                    text: meaningfulActivityText,
                    footer: detailStatusFooter
                )
            }
            .frame(minHeight: 90)
            .padding(.leading, 77)
            .padding(.trailing, 18)
            .padding(.top, 15)

            if hasContinuitySignal {
                continuityStrip
                    .padding(.leading, 77)
                    .padding(.trailing, 18)
                    .padding(.top, 12)
            }

            HStack(spacing: 12) {
                Button(action: onPark) {
                    Label(
                        hasContinuityPlan
                            ? l10n.text("Planı düzenle", "Edit plan")
                            : l10n.text("Park et", "Park"),
                        systemImage: "bookmark"
                    )
                        .font(.system(size: 12, weight: .medium))
                }
                .buttonStyle(.borderless)
                .help(l10n.text(
                    "Sonraki adımı, önem düzeyini ve dönüş zamanını yerel olarak kaydet",
                    "Save the next action, importance, and return time locally"
                ))
                if showsLifecycleMenu {
                    lifecycleMenu
                }
                Spacer()
                Button(action: onOpen) {
                    HStack(spacing: 8) {
                        Text(l10n.text("Göreve dön", "Open task"))
                        Image(systemName: "arrow.turn.down.left")
                    }
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(.white)
                    .padding(.horizontal, 15)
                    .frame(height: 38)
                    .background(RadarColors.blue, in: RoundedRectangle(cornerRadius: 8, style: .continuous))
                    .shadow(color: RadarColors.blue.opacity(0.22), radius: 5, y: 2)
                }
                .buttonStyle(.plain)
                .keyboardShortcut(.return, modifiers: [])
            }
            .padding(.leading, 77)
            .padding(.trailing, 18)
            .padding(.bottom, 15)
        }
    }

    private var continuityStrip: some View {
        VStack(alignment: .leading, spacing: 9) {
            if let nextAction = normalized(continuityMetadata.nextAction) {
                HStack(alignment: .firstTextBaseline, spacing: 9) {
                    Image(systemName: "arrow.right.circle.fill")
                        .foregroundStyle(RadarColors.blue)
                    Text(l10n.text("Sonraki adım", "Next action"))
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundStyle(RadarColors.secondary)
                    Text(nextAction)
                        .font(.system(size: 13, weight: .medium))
                        .foregroundStyle(RadarColors.text)
                        .lineLimit(2)
                }
            }

            if !triageReasons.isEmpty {
                HStack(alignment: .firstTextBaseline, spacing: 9) {
                    Image(systemName: "scope")
                        .foregroundStyle(RadarColors.blue)
                    Text(l10n.text("Neden şimdi?", "Why now?"))
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundStyle(RadarColors.secondary)
                    Text(triageReasons.joined(separator: " · "))
                        .font(.system(size: 12, weight: .medium))
                        .foregroundStyle(RadarColors.blue)
                        .lineLimit(2)
                }
            }

            if !continuityMetadataSummary.isEmpty {
                Text(continuityMetadataSummary.joined(separator: " · "))
                    .font(.system(size: 11))
                    .foregroundStyle(RadarColors.muted)
            }

            if let lifecycleEvidenceSummary {
                Label(lifecycleEvidenceSummary, systemImage: "checkmark.shield")
                    .font(.system(size: 11))
                    .foregroundStyle(RadarColors.secondary)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(12)
        .background(RadarColors.blueSoft.opacity(0.55), in: RoundedRectangle(cornerRadius: 10))
        .accessibilityElement(children: .combine)
        .accessibilityLabel(l10n.text("İş sürekliliği ayrıntıları", "Work continuity details"))
    }

    private var hasContinuitySignal: Bool {
        hasContinuityPlan || !triageReasons.isEmpty || lifecycleEvidenceSummary != nil
    }

    private var hasContinuityPlan: Bool {
        continuityMetadata.importance != nil && continuityMetadata.importance != .normal
            || continuityMetadata.deadline != nil
            || normalized(continuityMetadata.nextAction) != nil
            || normalized(continuityMetadata.waitingOn) != nil
            || continuityMetadata.snoozeUntil != nil
    }

    private var continuityMetadataSummary: [String] {
        var parts: [String] = []
        if let importance = continuityMetadata.importance, importance != .normal {
            let title: String
            switch importance {
            case .low: title = l10n.text("Düşük önem", "Low importance")
            case .normal: title = l10n.text("Normal önem", "Normal importance")
            case .high: title = l10n.text("Yüksek önem", "High importance")
            case .critical: title = l10n.text("Kritik önem", "Critical importance")
            }
            parts.append(title)
        }
        if let deadline = continuityMetadata.deadline {
            parts.append(l10n.text(
                "Son tarih \(l10n.continuityDateTime(deadline))",
                "Deadline \(l10n.continuityDateTime(deadline))"
            ))
        }
        if let waitingOn = normalized(continuityMetadata.waitingOn) {
            parts.append(l10n.text("Beklenen", "Waiting for") + ": \(waitingOn)")
        }
        if let snoozeUntil = continuityMetadata.snoozeUntil, snoozeUntil > Date() {
            parts.append(l10n.text(
                "\(l10n.continuityDateTime(snoozeUntil)) tarihine kadar sessizde",
                "Snoozed until \(l10n.continuityDateTime(snoozeUntil))"
            ))
        }
        return parts
    }

    private func normalized(_ value: String?) -> String? {
        guard let value else { return nil }
        let result = value.trimmingCharacters(in: .whitespacesAndNewlines)
        return result.isEmpty ? nil : result
    }

    private var lifecycleMenu: some View {
        Menu {
            Button {
                onSetLifecycleOverride(.current)
            } label: {
                Label(
                    l10n.text("Güncel kabul et", "Mark as current"),
                    systemImage: lifecycleOverride == .current ? "checkmark.circle.fill" : "circle"
                )
            }
            Button {
                onSetLifecycleOverride(.waitingExternal)
            } label: {
                Label(
                    l10n.text("Dışarıdan bekliyor", "Waiting externally"),
                    systemImage: lifecycleOverride == .waitingExternal ? "checkmark.circle.fill" : "clock"
                )
            }
            Button {
                onSetLifecycleOverride(.blocked)
            } label: {
                Label(
                    l10n.text("Bloklu olarak doğrula", "Confirm as blocked"),
                    systemImage: lifecycleOverride == .blocked ? "checkmark.circle.fill" : "exclamationmark.octagon"
                )
            }
            Divider()
            Button {
                onSetLifecycleOverride(.completedElsewhere)
            } label: {
                Label(
                    l10n.text("Başka yerde tamamlandı", "Completed elsewhere"),
                    systemImage: lifecycleOverride == .completedElsewhere ? "checkmark.circle.fill" : "checkmark.circle"
                )
            }
            Button {
                onSetLifecycleOverride(.superseded)
            } label: {
                Label(
                    l10n.text("Yerine daha güncel iş geçti", "Superseded by newer work"),
                    systemImage: lifecycleOverride == .superseded ? "checkmark.circle.fill" : "arrow.triangle.branch"
                )
            }
            Button {
                onSetLifecycleOverride(.obsolete)
            } label: {
                Label(
                    l10n.text("Güncelliğini yitirmiş olarak doğrula", "Confirm as obsolete"),
                    systemImage: lifecycleOverride == .obsolete ? "checkmark.circle.fill" : "circle"
                )
            }
            Button {
                onSetLifecycleOverride(.abandoned)
            } label: {
                Label(
                    l10n.text("Terk edilmiş olarak doğrula", "Confirm as abandoned"),
                    systemImage: lifecycleOverride == .abandoned ? "checkmark.circle.fill" : "circle"
                )
            }
            Button {
                onSetLifecycleOverride(.duplicate)
            } label: {
                Label(
                    l10n.text("Yinelenen iş olarak doğrula", "Confirm as duplicate work"),
                    systemImage: lifecycleOverride == .duplicate ? "checkmark.circle.fill" : "square.on.square"
                )
            }
            if lifecycleOverride != nil {
                Divider()
                Button(l10n.text("Yerel etiketi kaldır", "Remove local label")) {
                    onSetLifecycleOverride(nil)
                }
            }
        } label: {
            Label(l10n.text("Durum etiketi", "Status label"), systemImage: "tag")
                .font(.system(size: 12, weight: .medium))
                .foregroundStyle(RadarColors.muted)
        }
        .menuStyle(.borderlessButton)
        .fixedSize()
        .help(l10n.text("Durum etiketi", "Status label"))
    }

    private var statusIcon: some View {
        Image(systemName: statusSymbol)
            .font(.system(size: 22, weight: .medium))
            .foregroundStyle(statusColor)
            .frame(width: 42, height: 42)
            .background(statusBackground, in: RoundedRectangle(cornerRadius: 11, style: .continuous))
            .accessibilityHidden(true)
    }

    private var statusSymbol: String {
        if item.attentionReason == .explicitInput {
            return "hourglass"
        }
        if item.attentionReason == .goalBlocked {
            return "exclamationmark.octagon"
        }
        if item.attentionReason == .usageLimited {
            return "exclamationmark.triangle"
        }
        if item.attentionReason == .budgetLimited {
            return "gauge.with.dots.needle.67percent"
        }
        switch item.executionState {
        case .recentlyActive:
            return "circle.dotted.circle"
        case .openSilent:
            return "circle.dashed"
        case .completed:
            return "checkmark.circle"
        case .aborted:
            return "stop.circle"
        case .idle:
            return "circle"
        case .unknown:
            return "circle.dashed"
        }
    }

    private var statusColor: Color {
        if item.attentionReason == .explicitInput
            || item.attentionReason == .goalBlocked
            || item.attentionReason == .usageLimited
            || item.attentionReason == .budgetLimited {
            return RadarColors.amber
        }
        if item.attentionReason == .newSinceView {
            return RadarColors.green
        }
        switch item.executionState {
        case .recentlyActive:
            return RadarColors.blue
        case .openSilent, .idle, .unknown:
            return RadarColors.muted
        case .completed:
            return RadarColors.green
        case .aborted:
            return RadarColors.red
        }
    }

    private var statusBackground: Color {
        if item.attentionReason == .explicitInput
            || item.attentionReason == .goalBlocked
            || item.attentionReason == .usageLimited
            || item.attentionReason == .budgetLimited {
            return RadarColors.amberSoft
        }
        if item.attentionReason == .newSinceView || item.executionState == .completed {
            return RadarColors.greenSoft
        }
        return RadarColors.blueSoft
    }

    private var statusText: String {
        if item.attentionReason == .explicitInput {
            return l10n.text("yanıtın bekleniyor", "waiting for your reply")
        }
        if item.attentionReason == .goalBlocked {
            return l10n.text("hedef bloklandı", "goal blocked")
        }
        if item.attentionReason == .usageLimited {
            return l10n.text("kullanım sınırına ulaştı", "usage limit reached")
        }
        if item.attentionReason == .budgetLimited {
            return l10n.text("görev bütçe sınırına ulaştı", "task budget limit reached")
        }
        if item.attentionReason == .newSinceView {
            return l10n.text("görmediğin yeni sonuç var", "there is a new unseen result")
        }
        switch item.executionState {
        case .recentlyActive:
            return l10n.text("açık turn · son yerel kayıt ≤2 dk", "open turn · latest local record ≤2 min")
        case .openSilent:
            return l10n.text("açık turn · yakın yerel kayıt yok", "open turn · no recent local record")
        case .completed:
            return l10n.text("son turn tamamlandı", "latest turn completed")
        case .aborted:
            return l10n.text("son turn durduruldu", "latest turn stopped")
        case .idle:
            return l10n.text("beklemede", "idle")
        case .unknown:
            return l10n.text("durum doğrulanamadı", "status could not be verified")
        }
    }

    private var meaningfulActivityText: String {
        if let date = item.lastMeaningfulAgentAt {
            return l10n.text(
                "Ajanın son anlamlı mesajı \(RadarRelativeTime.text(date, language: language)).",
                "The agent's latest meaningful message was \(RadarRelativeTime.text(date, language: language))."
            )
        }
        if let date = item.lastActivityAt {
            return l10n.text(
                "Son yerel görev kaydı \(RadarRelativeTime.text(date, language: language)).",
                "The latest local task record was \(RadarRelativeTime.text(date, language: language))."
            )
        }
        return l10n.text(
            "Henüz zaman damgalı bir yerel görev kaydı yok.",
            "There is no timestamped local task record yet."
        )
    }

    private var rowAccessibilityLabel: String {
        var parts = [
            item.title,
            item.projectName,
            statusText,
            l10n.text("Son anlamlı hareket", "Last meaningful activity")
                + " \(l10n.fullDateTime(item.timelineActivityAt))"
        ]
        if let lifecycleLabel {
            parts.insert(l10n.lifecycleTitle(lifecycleLabel), at: 3)
        }
        if recommended {
            parts.insert(l10n.text("Şimdi bak önerisi", "Look now recommendation"), at: 1)
        }
        if let nextAction = normalized(continuityMetadata.nextAction) {
            parts.append(l10n.text("Sonraki adım", "Next action") + ": \(nextAction)")
        }
        return parts.joined(separator: ", ")
    }

    private var signalPill: (text: String, color: Color, background: Color)? {
        switch item.attentionReason {
        case .explicitInput:
            return (l10n.text("Seni bekliyor", "Waiting for you"), Color(red: 0.70, green: 0.38, blue: 0.03), RadarColors.amberSoft)
        case .goalBlocked:
            return (l10n.text("Bloklandı", "Blocked"), Color(red: 0.70, green: 0.38, blue: 0.03), RadarColors.amberSoft)
        case .usageLimited:
            return (l10n.text("Sınırda", "At limit"), Color(red: 0.70, green: 0.38, blue: 0.03), RadarColors.amberSoft)
        case .budgetLimited:
            return (l10n.text("Bütçe sınırı", "Budget limit"), Color(red: 0.70, green: 0.38, blue: 0.03), RadarColors.amberSoft)
        case .newSinceView:
            return (l10n.text("Yeni sonuç", "New result"), Color(red: 0.12, green: 0.49, blue: 0.22), RadarColors.greenSoft)
        case nil:
            guard lifecycleLabel == nil else { return nil }
            switch item.goalStatus {
            case .paused:
                return (l10n.text("Park edilmiş", "Parked"), Color(red: 0.52, green: 0.39, blue: 0.16), RadarColors.amberSoft)
            case .usageLimited:
                return (l10n.text("Kullanım sınırı", "Usage limit"), Color(red: 0.70, green: 0.38, blue: 0.03), RadarColors.amberSoft)
            case .budgetLimited:
                return (l10n.text("Bütçe sınırı", "Budget limit"), Color(red: 0.70, green: 0.38, blue: 0.03), RadarColors.amberSoft)
            case .complete:
                return (l10n.text("Hedef tamam", "Goal complete"), RadarColors.greenText, RadarColors.greenSoft)
            default:
                return nil
            }
        }
    }

    private func lifecyclePill(
        for label: RadarLifecycleLabel
    ) -> (text: String, color: Color, background: Color) {
        switch label {
        case .historical, .stale:
            return (l10n.lifecycleTitle(label), RadarColors.secondary, RadarColors.graySoft)
        case .longParked, .unfinishedCandidate, .abandonedCandidate, .snoozed, .waitingExternal:
            return (l10n.lifecycleTitle(label), Color(red: 0.63, green: 0.37, blue: 0.04), RadarColors.amberSoft)
        case .blocked:
            return (l10n.lifecycleTitle(label), RadarColors.red, RadarColors.redSoft)
        case .completedElsewhere:
            return (l10n.lifecycleTitle(label), RadarColors.greenText, RadarColors.greenSoft)
        case .superseded, .obsolete, .duplicate:
            return (l10n.lifecycleTitle(label), RadarColors.secondary, RadarColors.graySoft)
        case .abandoned:
            return (l10n.lifecycleTitle(label), RadarColors.red, RadarColors.redSoft)
        }
    }

    private var goalStatusFooter: String? {
        switch item.goalStatus {
        case .active:
            return l10n.text("Hedef: aktif", "Goal: active")
        case .paused:
            return l10n.text("Hedef: duraklatıldı", "Goal: paused")
        case .blocked:
            return l10n.text("Hedef: bloklandı", "Goal: blocked")
        case .usageLimited:
            return l10n.text("Hedef: kullanım sınırında", "Goal: usage limited")
        case .budgetLimited:
            return l10n.text("Hedef: bütçe sınırında", "Goal: budget limited")
        case .complete:
            return l10n.text("Hedef: tamamlandı", "Goal: complete")
        case .unknown:
            return l10n.text("Hedef: durum doğrulanamadı", "Goal: status could not be verified")
        case nil:
            return nil
        }
    }

    private var detailStatusFooter: String? {
        var parts: [String] = []
        if let goalStatusFooter {
            parts.append(goalStatusFooter)
        }
        if lifecycleEvidenceSummary == nil, let lifecycleLabel {
            parts.append(l10n.lifecycleEvidence(lifecycleLabel))
        }
        return parts.isEmpty ? nil : parts.joined(separator: " · ")
    }
}

private struct DetailBlock: View {
    let title: String
    let text: String
    let footer: String?

    var body: some View {
        VStack(alignment: .leading, spacing: 7) {
            Text(title)
                .font(.system(size: 12, weight: .semibold))
                .foregroundStyle(RadarColors.secondary)
            Text(text)
                .font(.system(size: 13))
                .foregroundStyle(RadarColors.secondary)
                .lineLimit(3)
                .fixedSize(horizontal: false, vertical: true)
            if let footer {
                Text(footer)
                    .font(.system(size: 11))
                    .foregroundStyle(RadarColors.muted)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

private struct SummaryMetric: View {
    let color: Color
    let text: String

    var body: some View {
        HStack(spacing: 8) {
            Circle()
                .fill(color)
                .frame(width: 8, height: 8)
            Text(text)
        }
    }
}

private struct KeyCap: View {
    let text: String

    var body: some View {
        Text(text)
            .font(.system(size: 11, weight: .medium, design: .rounded))
            .foregroundStyle(RadarColors.muted)
            .padding(.horizontal, 7)
            .frame(height: 25)
            .background(
                RoundedRectangle(cornerRadius: 6, style: .continuous)
                    .fill(Color(nsColor: NSColor(calibratedWhite: 0.97, alpha: 1)))
            )
            .overlay {
                RoundedRectangle(cornerRadius: 6, style: .continuous)
                    .stroke(Color(nsColor: .separatorColor), lineWidth: 1)
            }
    }
}

private struct FooterHint: View {
    let keys: [String]
    let label: String

    var body: some View {
        HStack(spacing: 5) {
            ForEach(keys, id: \.self) { key in
                KeyCap(text: key)
            }
            Text(label)
        }
    }
}
