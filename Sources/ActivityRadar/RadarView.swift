import ActivityRadarCore
import AppKit
import SwiftUI

private enum RadarRelativeTime {
    private static let formatter: RelativeDateTimeFormatter = {
        let formatter = RelativeDateTimeFormatter()
        formatter.locale = Locale(identifier: "tr_TR")
        formatter.unitsStyle = .full
        return formatter
    }()

    static func text(_ date: Date, relativeTo now: Date = Date()) -> String {
        let elapsed = now.timeIntervalSince(date)
        guard abs(elapsed) >= 10 else {
            return "şimdi"
        }
        return formatter.localizedString(for: date, relativeTo: now)
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
        .alert(
            "Yerel araştırma olayları silinsin mi?",
            isPresented: $showsResearchClearConfirmation
        ) {
            Button("Sil", role: .destructive) {
                model.clearResearchLedger()
            }
            Button("Vazgeç", role: .cancel) {}
        } message: {
            Text("Bu işlem yalnızca Activity Radar’ın içeriksiz araştırma günlüğünü temizler; Codex görevlerine ve park planlarına dokunmaz.")
        }
        .alert(
            "İçeriksiz araştırma kaydı dışa aktarılsın mı?",
            isPresented: Binding(
                get: { model.researchExportPreview != nil },
                set: { isPresented in
                    if !isPresented {
                        model.cancelResearchExport()
                    }
                }
            )
        ) {
            Button("Dosya seç…") {
                model.confirmResearchExport()
            }
            Button("Vazgeç", role: .cancel) {
                model.cancelResearchExport()
            }
        } message: {
            Text(model.researchExportPreviewSummary ?? "Önizleme hazırlanıyor…")
        }
    }

    private var searchHeader: some View {
        HStack(spacing: 12) {
            Image(systemName: "magnifyingglass")
                .font(.system(size: 20, weight: .regular))
                .foregroundStyle(RadarColors.muted)

            TextField("Görev ara veya geç…", text: $model.query)
                .textFieldStyle(.plain)
                .font(.system(size: 16))
                .foregroundStyle(RadarColors.text)
                .focused($searchFocused)
                .accessibilityLabel("Görev ara veya geç")

            if !model.query.isEmpty {
                Button {
                    model.query = ""
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundStyle(RadarColors.muted)
                }
                .buttonStyle(.plain)
                .accessibilityLabel("Aramayı temizle")
            }

            Button {
                model.refresh()
            } label: {
                Label("Şimdi yenile", systemImage: "arrow.clockwise")
                    .labelStyle(.iconOnly)
                    .font(.system(size: 13, weight: .semibold))
                    .opacity(model.isRefreshing ? 0.45 : 1)
            }
            .buttonStyle(.plain)
            .foregroundStyle(RadarColors.muted)
            .help("Şimdi yenile")

            Menu {
                Toggle(
                    "İçeriksiz yerel araştırma kaydı",
                    isOn: Binding(
                        get: { model.researchLoggingEnabled },
                        set: { model.setResearchLoggingEnabled($0) }
                    )
                )
                Divider()
                Text("\(model.researchEventCount) olay · son 90 gün · ağ aktarımı yok")
                Button("Önizle ve dışa aktar…") {
                    model.prepareResearchExport()
                }
                .disabled(model.researchEventCount == 0)
                Button("Yerel olayları temizle…", role: .destructive) {
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
            .help("Gizlilik korumalı araştırma modu")
            .accessibilityLabel("Gizlilik korumalı araştırma modu")

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
            SummaryMetric(color: RadarColors.blue, text: "\(model.recentlyActiveCount) açık turn · ≤2 dk")
            SummaryMetric(color: RadarColors.amber, text: "\(model.attentionCount) dikkat istiyor")
            SummaryMetric(color: RadarColors.green, text: "\(model.newResultCount) yeni sonuç")

            Spacer(minLength: 8)

            if model.scope == .all || !model.query.isEmpty {
                Picker("Tarih aralığı", selection: $model.dateRange) {
                    ForEach(RadarDateRange.allCases) { range in
                        Text(range.title).tag(range)
                    }
                }
                .labelsHidden()
                .pickerStyle(.menu)
                .controlSize(.small)
                .frame(width: 128)
            }

            Picker("Görünüm", selection: $model.scope) {
                ForEach(RadarScope.allCases) { scope in
                    Text(scope.rawValue).tag(scope)
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
                                Text("Tek öneri yok · \(abstention)")
                                    .font(.system(size: 12, weight: .medium))
                                    .foregroundStyle(RadarColors.secondary)
                                Spacer()
                            }
                            .padding(.horizontal, 12)
                            .frame(minHeight: 36)
                            .background(RadarColors.graySoft)
                            .accessibilityElement(children: .combine)
                            .accessibilityLabel("Tek öneri yok. \(abstention)")
                        }
                        ForEach(Array(visibleItems.enumerated()), id: \.element.id) { index, item in
                            if let section = model.focusSection(for: item),
                               index == 0 || model.focusSection(for: visibleItems[index - 1]) != section {
                                FocusSectionHeader(title: model.focusSectionTitle(section))
                            }
                            RadarTaskRow(
                                item: item,
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
                Button("Yeniden dene") {
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
            FooterHint(keys: ["↑", "↓"], label: "Gezin")
            FooterHint(keys: ["Enter"], label: "Göreve dön")
            FooterHint(keys: ["Esc"], label: "Kapat")

            Spacer()

            if model.scope == .focus, model.query.isEmpty, !model.items.isEmpty {
                Text(
                    "\(model.filteredItems.count)/\(model.items.count) odakta"
                    + (model.triageAbstentionText == nil ? "" : " · tek öneri yok")
                )
                    .foregroundStyle(RadarColors.muted)
                    .help(model.triageAbstentionText ?? "Açıklanabilir portföy triyajı")
            } else if model.query.isEmpty, model.scope == .all {
                Text(
                    "\(model.filteredItems.count) görev · \(model.dateRange.title)"
                    + (model.isHistoryCapped ? " · daha eski işler var" : "")
                )
                .foregroundStyle(RadarColors.muted)
            } else if !model.query.isEmpty {
                Text(
                    "\(model.filteredItems.count) sonuç · \(model.dateRange.title)"
                    + (model.isHistoryCapped ? " · daha fazlası var" : "")
                )
                    .foregroundStyle(RadarColors.muted)
            }
            if let updated = model.lastRefreshAt {
                Text("Yerel veri · \(RadarRelativeTime.text(updated))")
                    .foregroundStyle(RadarColors.greenText)
            }
            Text("Activity Radar · Work Continuity")
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
                Button("Tüm görevleri göster") {
                    model.scope = .all
                }
                .buttonStyle(.bordered)
            } else if model.query.isEmpty, model.dateRange != .all {
                Button("Tüm zamanları göster") {
                    model.dateRange = .all
                }
                .buttonStyle(.bordered)
            } else if model.query.isEmpty {
                Button("Yenile") {
                    model.refresh()
                }
                .buttonStyle(.bordered)
            } else {
                HStack(spacing: 10) {
                    Button("Aramayı temizle") {
                        model.query = ""
                    }
                    if model.dateRange != .all {
                        Button("Tüm zamanlarda ara") {
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
            return "Eşleşen görev yok"
        }
        if model.scope == .focus {
            return "Şu anda odak gerektiren görev yok"
        }
        return "Bu tarih aralığında görev yok"
    }

    private var emptyStateDescription: String {
        if model.isSearching {
            return "\(model.dateRange.title) içindeki yerel görevlerde aranıyor…"
        }
        if !model.query.isEmpty {
            return "Başlığı, projeyi veya son hareketi ara."
        }
        if model.scope == .focus {
            return "Tümü görünümüne geçebilir veya yenileyebilirsin."
        }
        return "Tarih aralığını genişleterek daha eski işleri geri getirebilirsin."
    }

    private var loadingState: some View {
        VStack(spacing: 11) {
            ProgressView()
                .controlSize(.small)
            Text("Codex görevleri salt-okunur yükleniyor…")
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
            Text("\(model.dateRange.title) içindeki yerel görevlerde aranıyor…")
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

    var body: some View {
        Text(title.uppercased(with: Locale(identifier: "tr_TR")))
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
                                Text("Son döndüğün")
                                    .font(.system(size: 11, weight: .semibold))
                                    .foregroundStyle(RadarColors.blue)
                                    .padding(.horizontal, 8)
                                    .padding(.vertical, 3)
                                    .background(RadarColors.blueSoft, in: Capsule())
                            }

                            if recommended {
                                Text("Şimdi bak")
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

                    Text("Hareket · \(Self.timeLabel(for: item.timelineActivityAt))")
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
                "\(item.cwd)\nSon anlamlı hareket: \(Self.fullDateFormatter.string(from: item.timelineActivityAt))"
            )
            .accessibilityElement(children: .ignore)
            .accessibilityLabel(rowAccessibilityLabel)
            .accessibilityHint(selected ? "Ayrıntıları kapatır" : "Ayrıntıları açar")
            .accessibilityValue(selected ? "Seçili; ayrıntılar açık" : "Ayrıntılar kapalı")

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
                    title: "Son ajan mesajı",
                    text: item.checkpoint,
                    footer: item.historyComplete ? nil : "Geçmişin son bölümü tarandı"
                )

                Divider()

                DetailBlock(
                    title: "Son anlamlı hareket",
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
                    Label(hasContinuityPlan ? "Planı düzenle" : "Park et", systemImage: "bookmark")
                        .font(.system(size: 12, weight: .medium))
                }
                .buttonStyle(.borderless)
                .help("Sonraki adımı, önem düzeyini ve dönüş zamanını yerel olarak kaydet")
                if showsLifecycleMenu {
                    lifecycleMenu
                }
                Spacer()
                Button(action: onOpen) {
                    HStack(spacing: 8) {
                        Text("Göreve dön")
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
                    Text("Sonraki adım")
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
                    Text("Neden şimdi?")
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
        .accessibilityLabel("İş sürekliliği ayrıntıları")
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
            case .low: title = "Düşük önem"
            case .normal: title = "Normal önem"
            case .high: title = "Yüksek önem"
            case .critical: title = "Kritik önem"
            }
            parts.append(title)
        }
        if let deadline = continuityMetadata.deadline {
            parts.append("Son tarih \(Self.continuityDateFormatter.string(from: deadline))")
        }
        if let waitingOn = normalized(continuityMetadata.waitingOn) {
            parts.append("Beklenen: \(waitingOn)")
        }
        if let snoozeUntil = continuityMetadata.snoozeUntil, snoozeUntil > Date() {
            parts.append("\(Self.continuityDateFormatter.string(from: snoozeUntil)) tarihine kadar sessizde")
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
                    "Güncel kabul et",
                    systemImage: lifecycleOverride == .current ? "checkmark.circle.fill" : "circle"
                )
            }
            Button {
                onSetLifecycleOverride(.waitingExternal)
            } label: {
                Label(
                    "Dışarıdan bekliyor",
                    systemImage: lifecycleOverride == .waitingExternal ? "checkmark.circle.fill" : "clock"
                )
            }
            Button {
                onSetLifecycleOverride(.blocked)
            } label: {
                Label(
                    "Bloklu olarak doğrula",
                    systemImage: lifecycleOverride == .blocked ? "checkmark.circle.fill" : "exclamationmark.octagon"
                )
            }
            Divider()
            Button {
                onSetLifecycleOverride(.completedElsewhere)
            } label: {
                Label(
                    "Başka yerde tamamlandı",
                    systemImage: lifecycleOverride == .completedElsewhere ? "checkmark.circle.fill" : "checkmark.circle"
                )
            }
            Button {
                onSetLifecycleOverride(.superseded)
            } label: {
                Label(
                    "Yerine daha güncel iş geçti",
                    systemImage: lifecycleOverride == .superseded ? "checkmark.circle.fill" : "arrow.triangle.branch"
                )
            }
            Button {
                onSetLifecycleOverride(.obsolete)
            } label: {
                Label(
                    "Güncelliğini yitirmiş olarak doğrula",
                    systemImage: lifecycleOverride == .obsolete ? "checkmark.circle.fill" : "circle"
                )
            }
            Button {
                onSetLifecycleOverride(.abandoned)
            } label: {
                Label(
                    "Terk edilmiş olarak doğrula",
                    systemImage: lifecycleOverride == .abandoned ? "checkmark.circle.fill" : "circle"
                )
            }
            Button {
                onSetLifecycleOverride(.duplicate)
            } label: {
                Label(
                    "Yinelenen iş olarak doğrula",
                    systemImage: lifecycleOverride == .duplicate ? "checkmark.circle.fill" : "square.on.square"
                )
            }
            if lifecycleOverride != nil {
                Divider()
                Button("Yerel etiketi kaldır") {
                    onSetLifecycleOverride(nil)
                }
            }
        } label: {
            Label("Durum etiketi", systemImage: "tag")
                .font(.system(size: 12, weight: .medium))
                .foregroundStyle(RadarColors.muted)
        }
        .menuStyle(.borderlessButton)
        .fixedSize()
        .help("Durum etiketi")
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
            return "yanıtın bekleniyor"
        }
        if item.attentionReason == .goalBlocked {
            return "hedef bloklandı"
        }
        if item.attentionReason == .usageLimited {
            return "kullanım sınırına ulaştı"
        }
        if item.attentionReason == .budgetLimited {
            return "görev bütçe sınırına ulaştı"
        }
        if item.attentionReason == .newSinceView {
            return "görmediğin yeni sonuç var"
        }
        switch item.executionState {
        case .recentlyActive:
            return "açık turn · son yerel kayıt ≤2 dk"
        case .openSilent:
            return "açık turn · yakın yerel kayıt yok"
        case .completed:
            return "son turn tamamlandı"
        case .aborted:
            return "son turn durduruldu"
        case .idle:
            return "beklemede"
        case .unknown:
            return "durum doğrulanamadı"
        }
    }

    private var meaningfulActivityText: String {
        if let date = item.lastMeaningfulAgentAt {
            return "Ajanın son anlamlı mesajı \(RadarRelativeTime.text(date))."
        }
        if let date = item.lastActivityAt {
            return "Son yerel görev kaydı \(RadarRelativeTime.text(date))."
        }
        return "Henüz zaman damgalı bir yerel görev kaydı yok."
    }

    private var rowAccessibilityLabel: String {
        var parts = [
            item.title,
            item.projectName,
            statusText,
            "Son anlamlı hareket \(Self.fullDateFormatter.string(from: item.timelineActivityAt))"
        ]
        if let lifecycleLabel {
            parts.insert(lifecycleLabel.title, at: 3)
        }
        if recommended {
            parts.insert("Şimdi bak önerisi", at: 1)
        }
        if let nextAction = normalized(continuityMetadata.nextAction) {
            parts.append("Sonraki adım: \(nextAction)")
        }
        return parts.joined(separator: ", ")
    }

    private var signalPill: (text: String, color: Color, background: Color)? {
        switch item.attentionReason {
        case .explicitInput:
            return ("Seni bekliyor", Color(red: 0.70, green: 0.38, blue: 0.03), RadarColors.amberSoft)
        case .goalBlocked:
            return ("Bloklandı", Color(red: 0.70, green: 0.38, blue: 0.03), RadarColors.amberSoft)
        case .usageLimited:
            return ("Sınırda", Color(red: 0.70, green: 0.38, blue: 0.03), RadarColors.amberSoft)
        case .budgetLimited:
            return ("Bütçe sınırı", Color(red: 0.70, green: 0.38, blue: 0.03), RadarColors.amberSoft)
        case .newSinceView:
            return ("Yeni sonuç", Color(red: 0.12, green: 0.49, blue: 0.22), RadarColors.greenSoft)
        case nil:
            guard lifecycleLabel == nil else { return nil }
            switch item.goalStatus {
            case .paused:
                return ("Park edilmiş", Color(red: 0.52, green: 0.39, blue: 0.16), RadarColors.amberSoft)
            case .usageLimited:
                return ("Kullanım sınırı", Color(red: 0.70, green: 0.38, blue: 0.03), RadarColors.amberSoft)
            case .budgetLimited:
                return ("Bütçe sınırı", Color(red: 0.70, green: 0.38, blue: 0.03), RadarColors.amberSoft)
            case .complete:
                return ("Hedef tamam", RadarColors.greenText, RadarColors.greenSoft)
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
            return (label.title, RadarColors.secondary, RadarColors.graySoft)
        case .longParked, .unfinishedCandidate, .abandonedCandidate, .snoozed, .waitingExternal:
            return (label.title, Color(red: 0.63, green: 0.37, blue: 0.04), RadarColors.amberSoft)
        case .blocked:
            return (label.title, RadarColors.red, RadarColors.redSoft)
        case .completedElsewhere:
            return (label.title, RadarColors.greenText, RadarColors.greenSoft)
        case .superseded, .obsolete, .duplicate:
            return (label.title, RadarColors.secondary, RadarColors.graySoft)
        case .abandoned:
            return (label.title, RadarColors.red, RadarColors.redSoft)
        }
    }

    private static let clockFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "tr_TR")
        formatter.dateFormat = "HH:mm"
        return formatter
    }()

    private static let dayMonthFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "tr_TR")
        formatter.dateFormat = "d MMM"
        return formatter
    }()

    private static let dayMonthYearFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "tr_TR")
        formatter.dateFormat = "d MMM yyyy"
        return formatter
    }()

    private static let fullDateFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "tr_TR")
        formatter.dateFormat = "d MMM yyyy HH:mm:ss"
        return formatter
    }()

    private static let continuityDateFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "tr_TR")
        formatter.dateFormat = "d MMM HH:mm"
        return formatter
    }()

    private static func timeLabel(for date: Date, now: Date = Date()) -> String {
        let calendar = Calendar.current
        if calendar.isDateInToday(date) {
            return clockFormatter.string(from: date)
        }
        if calendar.isDateInYesterday(date) {
            return "Dün \(clockFormatter.string(from: date))"
        }
        if calendar.component(.year, from: date) != calendar.component(.year, from: now) {
            return dayMonthYearFormatter.string(from: date)
        }
        return dayMonthFormatter.string(from: date)
    }

    private var goalStatusFooter: String? {
        switch item.goalStatus {
        case .active:
            return "Hedef: aktif"
        case .paused:
            return "Hedef: duraklatıldı"
        case .blocked:
            return "Hedef: bloklandı"
        case .usageLimited:
            return "Hedef: kullanım sınırında"
        case .budgetLimited:
            return "Hedef: bütçe sınırında"
        case .complete:
            return "Hedef: tamamlandı"
        case .unknown:
            return "Hedef: durum doğrulanamadı"
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
            parts.append(lifecycleLabel.evidence)
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
