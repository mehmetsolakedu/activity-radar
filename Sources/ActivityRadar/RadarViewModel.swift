import ActivityRadarCore
import AppKit
import Combine
import Foundation
import UniformTypeIdentifiers

enum RadarScope: String, CaseIterable, Identifiable {
    case focus
    case all

    var id: String { rawValue }
}

enum RadarDateRange: String, CaseIterable, Identifiable {
    case day
    case week
    case month
    case quarter
    case all

    var id: String { rawValue }

    var loadLimit: Int {
        switch self {
        case .day: return 72
        case .week: return 96
        case .month: return 140
        case .quarter: return 180
        case .all: return 200
        }
    }

    func cutoff(relativeTo now: Date = Date()) -> Date? {
        switch self {
        case .day: return now.addingTimeInterval(-24 * 60 * 60)
        case .week: return now.addingTimeInterval(-7 * 24 * 60 * 60)
        case .month: return now.addingTimeInterval(-30 * 24 * 60 * 60)
        case .quarter: return now.addingTimeInterval(-90 * 24 * 60 * 60)
        case .all: return nil
        }
    }

    func contains(_ date: Date, relativeTo now: Date = Date()) -> Bool {
        guard let cutoff = cutoff(relativeTo: now) else { return true }
        return date >= cutoff
    }
}

enum RadarLifecycleOverride: String, Codable, CaseIterable {
    case current
    case waitingExternal
    case blocked
    case completedElsewhere
    case superseded
    case obsolete
    case abandoned
    case duplicate
}

struct RadarLifecycleOverrideRecord: Codable, Equatable {
    let value: RadarLifecycleOverride
    let setAt: Date
}

enum RadarLifecycleLabel: CaseIterable, Equatable {
    case historical
    case stale
    case longParked
    case unfinishedCandidate
    case abandonedCandidate
    case snoozed
    case waitingExternal
    case blocked
    case completedElsewhere
    case superseded
    case obsolete
    case abandoned
    case duplicate

}

enum RadarFocusSection: CaseIterable {
    case lastOpened
    case attention
    case newResults
    case whyNow
    case active
    case openSilent
    case parked
    case other
}

@MainActor
final class RadarViewModel: ObservableObject {
    @Published private(set) var items: [ActivityItem] = []
    @Published var query = ""
    @Published var scope: RadarScope = .focus
    @Published var dateRange: RadarDateRange = .month
    @Published var language: RadarLanguage = .turkish {
        didSet {
            guard oldValue != language else { return }
            language.persist(to: defaults)
            actionMessage = nil
            languageDidChange?(language)
        }
    }
    @Published var selectedID: String?
    @Published private(set) var isRefreshing = false
    @Published private(set) var isSearching = false
    @Published private(set) var lastRefreshAt: Date?
    @Published private(set) var errorMessage: String?
    @Published private(set) var actionMessage: String?
    @Published private(set) var lastOpenedID: String?
    @Published private(set) var lastOpenedAt: Date?
    @Published private(set) var lifecycleOverrides: [String: RadarLifecycleOverrideRecord] = [:]
    @Published private(set) var hasMoreItems = false
    @Published private(set) var continuityRecords: [String: RadarStoredContinuityRecord] = [:]
    @Published private(set) var triageResult: WorkTriageResult?
    @Published private(set) var researchLoggingEnabled = false
    @Published private(set) var researchEventCount = 0
    @Published private(set) var researchExportPreview: RadarResearchExportPreview?

    var didOpenThread: (() -> Void)?
    var languageDidChange: ((RadarLanguage) -> Void)?

    var l10n: RadarL10n {
        RadarL10n(language: language)
    }

    private let defaults: UserDefaults
    private let reader = CodexActivityReader()
    private let continuityStore = RadarContinuityStore()
    private let loadQueue = DispatchQueue(
        label: "io.github.mehmetsolakedu.ActivityRadar.reader",
        qos: .userInitiated
    )
    private var timer: Timer?
    private let viewedDefaultsKey = "ActivityRadar.lastViewedAt.v1"
    private let lastOpenedIDKey = "ActivityRadar.lastOpenedThreadID.v1"
    private let lastOpenedAtKey = "ActivityRadar.lastOpenedAt.v1"
    private let newResultsBaselineKey = "ActivityRadar.newResultsBaseline.v1"
    private let dateRangeKey = "ActivityRadar.dateRange.v1"
    private let lifecycleOverridesKey = "ActivityRadar.lifecycleOverrides.v1"
    private let newResultsBaseline: Date
    private var refreshPending = false
    private var searchItems: [ActivityItem] = []
    private var searchItemsQuery = ""
    private var searchHasMore = false
    private var searchWorkItem: DispatchWorkItem?
    private var lastLoggedTriageSignature: String?
    private var triageLogInFlightSignature: String?
    private var triagePresentationPending = false
    private var pendingResearchExportData: Data?

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        language = RadarLanguage.load(from: defaults)
        if let storedRange = defaults.string(forKey: dateRangeKey),
           let range = RadarDateRange(rawValue: storedRange) {
            dateRange = range
        }
        if let data = defaults.data(forKey: lifecycleOverridesKey),
           let records = try? JSONDecoder().decode(
               [String: RadarLifecycleOverrideRecord].self,
               from: data
           ) {
            lifecycleOverrides = records
        }

        let storedBaseline = defaults.double(forKey: newResultsBaselineKey)
        if storedBaseline > 0 {
            newResultsBaseline = Date(timeIntervalSince1970: storedBaseline)
        } else {
            let baseline = Date()
            newResultsBaseline = baseline
            defaults.set(baseline.timeIntervalSince1970, forKey: newResultsBaselineKey)
        }

        lastOpenedID = defaults.string(forKey: lastOpenedIDKey)
        let storedDate = defaults.double(forKey: lastOpenedAtKey)
        if storedDate > 0 {
            lastOpenedAt = Date(timeIntervalSince1970: storedDate)
        } else if let viewed = defaults.dictionary(forKey: viewedDefaultsKey) as? [String: Double],
                  let latest = viewed.max(by: { $0.value < $1.value }) {
            lastOpenedID = latest.key
            lastOpenedAt = Date(timeIntervalSince1970: latest.value)
        }

        Task { [weak self] in
            await self?.loadResearchState()
        }
    }

    var filteredItems: [ActivityItem] {
        let normalized = query
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .folding(options: [.caseInsensitive, .diacriticInsensitive], locale: Locale(identifier: "tr_TR"))

        if !normalized.isEmpty {
            let localMatches = items.filter { item in
                [item.title, item.projectName, item.cwd, item.checkpoint]
                    .joined(separator: " ")
                    .folding(options: [.caseInsensitive, .diacriticInsensitive], locale: Locale(identifier: "tr_TR"))
                    .contains(normalized)
            }
            let remoteMatches = searchItemsQuery == normalized ? searchItems : []
            var seen = Set<String>()
            let merged = (remoteMatches + localMatches).filter { seen.insert($0.id).inserted }
            let ranged = merged.filter { dateRange.contains(activityDate(for: $0)) }
            return Array(prioritizingLastOpened(ranged).prefix(dateRange.loadLimit))
        }

        if scope == .focus {
            return focusedItems()
        }
        return historyItems()
    }

    var recentlyActiveCount: Int {
        metricItems.filter { $0.executionState == .recentlyActive }.count
    }

    var attentionCount: Int {
        metricItems.filter { item in
            switch item.attentionReason {
            case .explicitInput, .goalBlocked, .usageLimited, .budgetLimited:
                return true
            case .newSinceView, nil:
                return false
            }
        }.count
    }

    var newResultCount: Int {
        metricItems.filter { $0.attentionReason == .newSinceView }.count
    }

    var lifecycleLabelCount: Int {
        items.filter { lifecycleLabel(for: $0) != nil }.count
    }

    var isHistoryCapped: Bool {
        query.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            ? hasMoreItems
            : searchHasMore
    }

    func start() {
        refresh()
        timer?.invalidate()
        timer = Timer.scheduledTimer(withTimeInterval: 5, repeats: true) { [weak self] _ in
            Task { @MainActor in
                self?.refresh()
            }
        }
        if let timer {
            RunLoop.main.add(timer, forMode: .common)
        }
    }

    func stop() {
        timer?.invalidate()
        timer = nil
    }

    func refresh() {
        guard !isRefreshing else {
            refreshPending = true
            return
        }
        isRefreshing = true
        let viewed = loadViewedDates()
        let reader = self.reader
        let priorityIDs = Set([lastOpenedID].compactMap { $0 })
        let baseline = newResultsBaseline
        let range = effectiveLoadRange
        let cutoff = range.cutoff()

        loadQueue.async { [weak self] in
            let result = Result {
                try reader.load(
                    limit: range.loadLimit,
                    lastViewedAt: viewed,
                    priorityThreadIDs: priorityIDs,
                    unviewedResultsAfter: baseline,
                    updatedAfter: cutoff
                )
            }
            DispatchQueue.main.async {
                guard let self else { return }
                self.isRefreshing = false
                switch result {
                case .success(let snapshot) where self.effectiveLoadRange == range:
                    self.items = snapshot.items
                    self.hasMoreItems = snapshot.hasMore
                    self.lastRefreshAt = snapshot.generatedAt
                    self.errorMessage = nil
                    self.recomputeTriage(now: snapshot.generatedAt)
                    self.loadContinuityRecords(for: snapshot.items)
                    self.reconcileSelection()
                case .success:
                    break
                case .failure(let error) where self.effectiveLoadRange == range:
                    self.errorMessage = self.localizedFailure(
                        error,
                        turkish: "Codex görevleri okunamadı",
                        english: "Codex tasks could not be read"
                    )
                    self.actionMessage = nil
                case .failure:
                    break
                }
                if self.refreshPending {
                    self.refreshPending = false
                    self.refresh()
                }
            }
        }
    }

    func select(_ item: ActivityItem) {
        selectedID = item.id
    }

    func dateRangeDidChange() {
        defaults.set(dateRange.rawValue, forKey: dateRangeKey)
        if query.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            refresh()
        } else {
            queryDidChange()
        }
        ensureSelection()
    }

    func scopeDidChange() {
        if query.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            refresh()
        }
        ensureSelection()
    }

    func continuityRecord(for item: ActivityItem) -> RadarStoredContinuityRecord? {
        continuityRecords[item.id]
    }

    func continuityMetadata(for item: ActivityItem) -> WorkContinuityMetadata {
        guard let record = continuityRecord(for: item) else {
            return WorkContinuityMetadata()
        }
        return WorkContinuityMetadata(
            importance: workImportance(from: record.metadata.importance),
            deadline: record.metadata.deadline,
            nextAction: record.capsule.nextAction,
            waitingOn: record.capsule.waitingOn,
            snoozeUntil: record.metadata.snoozeUntil ?? record.metadata.reviewAt
        )
    }

    func hasContinuityPlan(for item: ActivityItem) -> Bool {
        let metadata = continuityMetadata(for: item)
        return metadata.importance != nil && metadata.importance != .normal
            || metadata.deadline != nil
            || metadata.hasNextAction
            || metadata.isWaiting
            || metadata.snoozeUntil != nil
    }

    func triageCandidate(for item: ActivityItem) -> WorkTriageCandidate? {
        guard triageResult?.recommendedActivityID != nil else { return nil }
        return triageResult?.rankedCandidates.first { $0.activityID == item.id }
    }

    func isRecommended(_ item: ActivityItem) -> Bool {
        triageResult?.recommendedActivityID == item.id
    }

    func triageReasonLabels(for item: ActivityItem) -> [String] {
        guard let candidate = triageCandidate(for: item) else { return [] }
        return candidate.reasons
            .filter { $0.weight > 0 }
            .prefix(3)
            .map { triageReasonLabel($0.code) }
    }

    var triageAbstentionText: String? {
        guard let reason = triageResult?.abstentionReason else { return nil }
        switch reason {
        case .noEligibleWork:
            return l10n.text(
                "Uygun iş yok; erteleme ve bekleme kararların korunuyor",
                "No eligible work; your snooze and waiting decisions are preserved"
            )
        case .insufficientEvidence:
            return l10n.text(
                "Tek bir iş önermek için kanıt yetersiz",
                "There is not enough evidence to recommend one task"
            )
        case .incompleteHistory:
            return l10n.text(
                "Geçmiş eksik; sistem tek bir iş seçmiyor",
                "History is incomplete; the system will not choose one task"
            )
        case .competingSignals:
            return l10n.text(
                "Birden fazla iş aynı ölçüde kritik; seçim sende",
                "Several tasks are equally critical; the choice is yours"
            )
        }
    }

    func lifecycleAssessment(
        for item: ActivityItem,
        now: Date = Date()
    ) -> WorkLifecycleAssessment {
        let override = effectiveLifecycleOverride(for: item)
        return WorkContinuityLifecycle.assess(
            item: item,
            metadata: continuityMetadata(for: item),
            lastOpenedAt: continuityLastViewedAt(for: item),
            confirmation: override.flatMap(workLifecycleConfirmation),
            now: now
        )
    }

    func lifecycleLabel(
        for item: ActivityItem,
        now: Date = Date()
    ) -> RadarLifecycleLabel? {
        let assessment = lifecycleAssessment(for: item, now: now)
        switch assessment.state {
        case .waitingExternal:
            return .waitingExternal
        case .blocked:
            return effectiveLifecycleOverride(for: item)?.value == .blocked ? .blocked : nil
        case .completedElsewhere:
            return .completedElsewhere
        case .superseded:
            return .superseded
        case .abandonedConfirmed:
            return .abandoned
        case .obsoleteConfirmed:
            return .obsolete
        case .duplicate:
            return .duplicate
        case .likelyAbandoned:
            return .stale
        case .dormant:
            if let snoozeUntil = continuityMetadata(for: item).snoozeUntil,
               snoozeUntil > now {
                return .snoozed
            }
            guard let suggestion = ActivityLifecyclePolicy.suggestion(
                for: item,
                lastOpenedAt: continuityLastViewedAt(for: item),
                now: now
            ) else {
                return nil
            }
            switch suggestion {
            case .historical: return .historical
            case .stale: return .stale
            case .longParked: return .longParked
            case .unfinishedCandidate: return .unfinishedCandidate
            case .abandonedCandidate: return .abandonedCandidate
            }
        case .completed:
            guard let suggestion = ActivityLifecyclePolicy.suggestion(
                for: item,
                lastOpenedAt: continuityLastViewedAt(for: item),
                now: now
            ) else {
                return nil
            }
            switch suggestion {
            case .historical: return .historical
            case .stale: return .stale
            case .longParked: return .longParked
            case .unfinishedCandidate: return .unfinishedCandidate
            case .abandonedCandidate: return .abandonedCandidate
            }
        case .current, .waitingHuman, .uncertain:
            return nil
        }
    }

    func lifecycleOverride(for item: ActivityItem) -> RadarLifecycleOverride? {
        effectiveLifecycleOverride(for: item)?.value
    }

    func setLifecycleOverride(
        _ value: RadarLifecycleOverride?,
        for item: ActivityItem
    ) {
        let previous = lifecycleOverrides[item.id]
        let now = Date()
        if let value {
            lifecycleOverrides[item.id] = RadarLifecycleOverrideRecord(
                value: value,
                setAt: now
            )
        } else {
            lifecycleOverrides.removeValue(forKey: item.id)
        }
        persistLifecycleOverrides()
        recomputeTriage(now: now)

        Task { [weak self] in
            guard let self else { return }
            do {
                if let value {
                    let stored = try await continuityStore.appendLifecycleDecision(
                        radarLifecycleDecision(for: value, at: now),
                        forTaskID: item.id
                    )
                    continuityRecords[item.id] = stored
                    actionMessage = l10n.text(
                        "Durum kararı yerel olarak kaydedildi.",
                        "The status decision was saved locally."
                    )
                }
                await appendResearchEvent(
                    previous == nil ? .lifecycleConfirmed : .lifecycleCorrected,
                    for: item.id,
                    at: now
                )
            } catch {
                actionMessage = localizedFailure(
                    error,
                    turkish: "Durum kararı tercihlerde kaldı; süreklilik kaydı yazılamadı",
                    english: "The status decision remains in preferences, but the continuity record could not be written"
                )
            }
        }
    }

    func saveContinuity(
        for item: ActivityItem,
        importance: WorkImportance,
        deadline: Date?,
        nextAction: String,
        waitingOn: String,
        snoozeUntil: Date?
    ) {
        let now = Date()
        let capsule = RadarContinuityCapsule(
            checkpoint: item.checkpoint,
            nextAction: nextAction,
            waitingOn: waitingOn
        )
        let metadata = RadarContinuityMetadata(
            importance: radarImportance(from: importance),
            deadline: deadline,
            snoozeUntil: snoozeUntil,
            reviewAt: snoozeUntil
        )

        Task { [weak self] in
            guard let self else { return }
            do {
                let stored = try await continuityStore.save(
                    capsule: capsule,
                    metadata: metadata,
                    forTaskID: item.id,
                    at: now
                )
                continuityRecords[item.id] = stored
                recomputeTriage(now: now)
                actionMessage = l10n.text(
                    "İş sürekliliği planı yerel olarak kaydedildi.",
                    "The work continuity plan was saved locally."
                )
                await appendResearchEvent(.capsuleSaved, for: item.id, at: now)
                if let snoozeUntil, snoozeUntil > now {
                    await appendResearchEvent(.snoozeSet, for: item.id, at: now)
                }
            } catch {
                actionMessage = localizedFailure(
                    error,
                    turkish: "İş sürekliliği planı kaydedilemedi",
                    english: "The work continuity plan could not be saved"
                )
            }
        }
    }

    func clearContinuity(for item: ActivityItem) {
        Task { [weak self] in
            guard let self else { return }
            do {
                if let existing = continuityRecords[item.id], !existing.lifecycleHistory.isEmpty {
                    continuityRecords[item.id] = try await continuityStore.save(
                        capsule: RadarContinuityCapsule(),
                        metadata: RadarContinuityMetadata(),
                        forTaskID: item.id
                    )
                } else {
                    try await continuityStore.removeRecord(forTaskID: item.id)
                    continuityRecords.removeValue(forKey: item.id)
                }
                recomputeTriage()
                actionMessage = l10n.text(
                    "Yerel iş sürekliliği planı kaldırıldı.",
                    "The local work continuity plan was removed."
                )
            } catch {
                actionMessage = localizedFailure(
                    error,
                    turkish: "Yerel plan kaldırılamadı",
                    english: "The local plan could not be removed"
                )
            }
        }
    }

    func setResearchLoggingEnabled(_ enabled: Bool) {
        researchLoggingEnabled = enabled
        Task { [weak self] in
            guard let self else { return }
            do {
                try await continuityStore.setResearchLoggingEnabled(enabled)
                await refreshResearchPreview()
                actionMessage = enabled
                    ? l10n.text(
                        "İçeriksiz yerel araştırma kaydı açıldı. Hiçbir veri ağ üzerinden gönderilmez.",
                        "Content-free local research logging is on. No data is sent over the network."
                    )
                    : l10n.text(
                        "Yerel araştırma kaydı kapatıldı. Mevcut kayıt cihazda kaldı.",
                        "Local research logging is off. Existing records remain on this device."
                    )
            } catch {
                researchLoggingEnabled.toggle()
                actionMessage = localizedFailure(
                    error,
                    turkish: "Araştırma kaydı ayarı değiştirilemedi",
                    english: "The research logging setting could not be changed"
                )
            }
        }
    }

    var researchExportPreviewSummary: String? {
        guard let preview = researchExportPreview else { return nil }
        let range: String
        if let oldest = preview.oldestEventAt, let newest = preview.newestEventAt {
            range = "\(l10n.dateTime(oldest)) – \(l10n.dateTime(newest))"
        } else {
            range = l10n.text("Olay yok", "No events")
        }
        let kinds = preview.eventKindCounts
            .sorted { $0.key < $1.key }
            .map { "\($0.key): \($0.value)" }
            .joined(separator: ", ")
        let conditions = preview.conditionCounts
            .sorted { $0.key < $1.key }
            .map { "\($0.key): \($0.value)" }
            .joined(separator: ", ")
        let size = "\(preview.estimatedJSONBytes) " + l10n.text("bayt", "bytes")
        let none = l10n.text("yok", "none")
        return [
            l10n.text("Toplam", "Total") + ": \(preview.eventCount) " + l10n.text("olay", "events"),
            l10n.text("Tarih aralığı", "Date range") + ": \(range)",
            l10n.text("Olay türleri", "Event types") + ": \(kinds.isEmpty ? none : kinds)",
            l10n.text("Koşullar", "Conditions") + ": \(conditions.isEmpty ? none : conditions)",
            l10n.text("Tahmini JSON boyutu", "Estimated JSON size") + ": \(size)",
            l10n.text(
                "Başlık, prompt, dosya yolu, checkpoint ve sonraki adım içermez.",
                "Contains no titles, prompts, file paths, checkpoints, or next actions."
            )
        ].joined(separator: "\n")
    }

    func prepareResearchExport() {
        Task { [weak self] in
            guard let self else { return }
            do {
                let snapshot = try await continuityStore.researchExportSnapshot()
                guard snapshot.preview.eventCount > 0 else {
                    actionMessage = l10n.text(
                        "Dışa aktarılacak araştırma olayı yok.",
                        "There are no research events to export."
                    )
                    return
                }
                guard !snapshot.preview.containsHumanAuthoredText else {
                    actionMessage = l10n.text(
                        "Gizlilik kontrolü dışa aktarımı durdurdu.",
                        "The privacy check stopped the export."
                    )
                    return
                }
                pendingResearchExportData = snapshot.data
                researchExportPreview = snapshot.preview
            } catch {
                pendingResearchExportData = nil
                researchExportPreview = nil
                actionMessage = localizedFailure(
                    error,
                    turkish: "Araştırma kaydı önizlenemedi",
                    english: "The research log could not be previewed"
                )
            }
        }
    }

    func cancelResearchExport() {
        pendingResearchExportData = nil
        researchExportPreview = nil
    }

    func confirmResearchExport() {
        guard let data = pendingResearchExportData,
              let preview = researchExportPreview else {
            return
        }
        cancelResearchExport()

        let panel = NSSavePanel()
        panel.title = l10n.text(
            "İçeriksiz araştırma kaydını dışa aktar",
            "Export content-free research log"
        )
        panel.nameFieldStringValue = "activity-radar-research-\(Self.exportDateFormatter.string(from: Date())).json"
        panel.allowedContentTypes = [.json]
        guard panel.runModal() == .OK, let url = panel.url else { return }
        do {
            try data.write(to: url, options: .atomic)
            actionMessage = l10n.text(
                "\(preview.eventCount) içeriksiz olay dışa aktarıldı.",
                "\(preview.eventCount) content-free events were exported."
            )
        } catch {
            actionMessage = localizedFailure(
                error,
                turkish: "Araştırma kaydı dışa aktarılamadı",
                english: "The research log could not be exported"
            )
        }
    }

    func clearResearchLedger() {
        Task { [weak self] in
            guard let self else { return }
            do {
                try await continuityStore.clearResearchLedger()
                researchEventCount = 0
                cancelResearchExport()
                actionMessage = l10n.text(
                    "Yerel araştırma olayları silindi; kayıt ayarı değişmedi.",
                    "Local research events were deleted; the logging setting did not change."
                )
            } catch {
                actionMessage = localizedFailure(
                    error,
                    turkish: "Araştırma kaydı temizlenemedi",
                    english: "The research log could not be cleared"
                )
            }
        }
    }

    func queryDidChange() {
        searchWorkItem?.cancel()
        let rawQuery = query.trimmingCharacters(in: .whitespacesAndNewlines)
        let normalized = rawQuery.folding(
            options: [.caseInsensitive, .diacriticInsensitive],
            locale: Locale(identifier: "tr_TR")
        )
        guard !normalized.isEmpty else {
            isSearching = false
            searchItems = []
            searchItemsQuery = ""
            searchHasMore = false
            ensureSelection()
            return
        }

        isSearching = true
        let reader = self.reader
        let viewed = loadViewedDates()
        let baseline = newResultsBaseline
        let range = dateRange
        let cutoff = range.cutoff()
        let work = DispatchWorkItem { [weak self] in
            let result = Result {
                try reader.search(
                    query: rawQuery,
                    limit: range.loadLimit,
                    lastViewedAt: viewed,
                    unviewedResultsAfter: baseline,
                    updatedAfter: cutoff
                )
            }
            DispatchQueue.main.async {
                guard let self else { return }
                let currentQuery = self.query
                    .trimmingCharacters(in: .whitespacesAndNewlines)
                    .folding(
                        options: [.caseInsensitive, .diacriticInsensitive],
                        locale: Locale(identifier: "tr_TR")
                    )
                guard currentQuery == normalized else { return }
                guard self.dateRange == range else { return }
                self.isSearching = false
                switch result {
                case .success(let snapshot):
                    self.searchItems = snapshot.items
                    self.searchItemsQuery = normalized
                    self.searchHasMore = snapshot.hasMore
                    self.errorMessage = nil
                    self.loadContinuityRecords(for: snapshot.items)
                    self.ensureSelection()
                case .failure(let error):
                    self.searchItems = []
                    self.searchItemsQuery = normalized
                    self.searchHasMore = false
                    self.errorMessage = self.localizedFailure(
                        error,
                        turkish: "Codex görevlerinde arama yapılamadı",
                        english: "Codex tasks could not be searched"
                    )
                }
            }
        }
        searchWorkItem = work
        loadQueue.asyncAfter(deadline: .now() + 0.18, execute: work)
    }

    func ensureSelection() {
        reconcileSelection()
    }

    func moveSelection(by delta: Int) {
        let visible = filteredItems
        guard !visible.isEmpty else { return }
        guard let selectedID,
              let index = visible.firstIndex(where: { $0.id == selectedID }) else {
            self.selectedID = visible.first?.id
            return
        }
        let next = (index + delta + visible.count) % visible.count
        self.selectedID = visible[next].id
    }

    func openSelected() {
        guard let item = filteredItems.first(where: { $0.id == selectedID })
            ?? filteredItems.first else {
            return
        }
        open(item)
    }

    func open(_ item: ActivityItem) {
        guard let url = item.codexDeepLink else {
            actionMessage = l10n.text(
                "Bu görev için geçerli Codex bağlantısı üretilemedi.",
                "A valid Codex link could not be created for this task."
            )
            return
        }

        if NSWorkspace.shared.open(url) {
            let openedAt = Date()
            markViewed(item.id, at: openedAt)
            acknowledgeDueSnooze(for: item, at: openedAt)
            actionMessage = l10n.text("Codex’te açıldı", "Opened in Codex") + ": \(item.title)"
            Task { [weak self] in
                await self?.appendResearchEvent(.taskOpened, for: item.id, at: openedAt)
            }
            didOpenThread?()
            refresh()
        } else {
            actionMessage = l10n.text(
                "Codex açılamadı. /Applications/ChatGPT.app kurulumunu kontrol et.",
                "Codex could not be opened. Check the /Applications/ChatGPT.app installation."
            )
        }
    }

    func clearActionMessage() {
        actionMessage = nil
    }

    func prepareForPresentation() {
        query = ""
        queryDidChange()
        scope = .focus
        actionMessage = nil
        selectedID = focusedItems().first?.id
        triagePresentationPending = true
        lastLoggedTriageSignature = nil
        refresh()
    }

    func isLastOpened(_ item: ActivityItem) -> Bool {
        item.id == lastOpenedID && lastOpenedAt != nil
    }

    private func continuityLastViewedAt(for item: ActivityItem) -> Date? {
        let global = isLastOpened(item) ? lastOpenedAt : nil
        return [item.lastViewedAt, global]
            .compactMap { $0 }
            .max()
    }

    func focusSection(for item: ActivityItem) -> RadarFocusSection? {
        guard scope == .focus,
              query.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            return nil
        }
        if isLastOpened(item) {
            return .lastOpened
        }
        if triageCandidate(for: item) != nil {
            return .whyNow
        }
        switch item.attentionReason {
        case .explicitInput, .goalBlocked, .usageLimited, .budgetLimited:
            return .attention
        case .newSinceView:
            return .newResults
        case nil:
            break
        }
        switch item.executionState {
        case .recentlyActive:
            return .active
        case .openSilent:
            return .openSilent
        default:
            return item.goalStatus == .paused ? .parked : .other
        }
    }

    func focusSectionTitle(_ section: RadarFocusSection) -> String {
        guard section == .whyNow, let triageAbstentionText else {
            return l10n.focusSectionTitle(section)
        }
        return "\(l10n.focusSectionTitle(section)) · \(triageAbstentionText)"
    }

    func lifecycleEvidenceSummary(for item: ActivityItem) -> String? {
        let assessment = lifecycleAssessment(for: item)
        switch assessment.state {
        case .current:
            return effectiveLifecycleOverride(for: item) == nil
                ? nil
                : l10n.text("Kullanıcı tarafından güncel kabul edildi", "You marked this as current")
        case .waitingHuman:
            return nil
        case .waitingExternal:
            return l10n.text(
                "Dışarıdan bir kişi veya olay bekleniyor",
                "Waiting for an external person or event"
            )
        case .blocked:
            return effectiveLifecycleOverride(for: item)?.value == .blocked
                ? l10n.text("Kullanıcı işi bloklu olarak doğruladı", "You confirmed this work is blocked")
                : nil
        case .dormant:
            if let snoozeUntil = continuityMetadata(for: item).snoozeUntil,
               snoozeUntil > Date() {
                return l10n.text(
                    "\(l10n.dateTime(snoozeUntil)) tarihine kadar ertelendi",
                    "Snoozed until \(l10n.dateTime(snoozeUntil))"
                )
            }
            return nil
        case .likelyAbandoned:
            return l10n.text(
                "Uzun süredir sessiz; durum kararı kullanıcıya ait",
                "Quiet for a long time; the status decision belongs to you"
            )
        case .completed:
            return nil
        case .completedElsewhere:
            return l10n.text(
                "Kullanıcı işin başka bir yerde tamamlandığını doğruladı",
                "You confirmed this work was completed elsewhere"
            )
        case .superseded:
            return l10n.text(
                "Kullanıcı bu işin yerine daha güncel bir iş geçtiğini doğruladı",
                "You confirmed that newer work superseded this work"
            )
        case .abandonedConfirmed:
            return l10n.text("Kullanıcı işi terk ettiğini doğruladı", "You confirmed this work was abandoned")
        case .obsoleteConfirmed:
            return l10n.text("Kullanıcı işin güncelliğini yitirdiğini doğruladı", "You confirmed this work is obsolete")
        case .duplicate:
            return l10n.text(
                "Kullanıcı bunun yinelenen bir iş olduğunu doğruladı",
                "You confirmed this is duplicate work"
            )
        case .uncertain:
            return l10n.text(
                "Durum için kanıt yetersiz; sistem kesin lifecycle etiketi vermiyor",
                "Evidence is insufficient; the system is not assigning a definite lifecycle label"
            )
        }
    }

    private func reconcileSelection() {
        let visible = filteredItems
        if let selectedID, visible.contains(where: { $0.id == selectedID }) {
            return
        }
        selectedID = visible.first?.id
    }

    private func loadViewedDates() -> [String: Date] {
        guard let raw = defaults.dictionary(forKey: viewedDefaultsKey) as? [String: Double] else {
            return [:]
        }
        return raw.mapValues(Date.init(timeIntervalSince1970:))
    }

    private func markViewed(_ threadID: String, at date: Date) {
        var raw = defaults.dictionary(forKey: viewedDefaultsKey) as? [String: Double] ?? [:]
        raw[threadID] = date.timeIntervalSince1970
        defaults.set(raw, forKey: viewedDefaultsKey)
        defaults.set(threadID, forKey: lastOpenedIDKey)
        defaults.set(date.timeIntervalSince1970, forKey: lastOpenedAtKey)
        lastOpenedID = threadID
        lastOpenedAt = date
    }

    private func focusedItems(now: Date = Date()) -> [ActivityItem] {
        var result: [ActivityItem] = []
        var seen = Set<String>()
        let deferredIDs = Set(triageResult?.deferred.map(\.activityID) ?? [])

        func append(_ candidates: [ActivityItem], limit: Int? = nil) {
            var appended = 0
            for item in candidates where !seen.contains(item.id) {
                if let limit, appended >= limit {
                    break
                }
                result.append(item)
                seen.insert(item.id)
                appended += 1
            }
        }

        if let lastOpenedID,
           lastOpenedAt != nil,
           let lastOpened = items.first(where: { $0.id == lastOpenedID }),
           !isFocusSuppressed(lastOpened, deferredIDs: deferredIDs) {
            append([lastOpened])
        }

        if let triageResult, triageResult.recommendedActivityID != nil {
            append(
                triageResult.rankedCandidates.compactMap { candidate in
                    items.first { $0.id == candidate.activityID }
                },
                limit: 3
            )
        }

        append(items.filter { item in
            guard !isFocusSuppressed(item, deferredIDs: deferredIDs) else {
                return false
            }
            switch item.attentionReason {
            case .explicitInput, .goalBlocked, .usageLimited, .budgetLimited:
                return true
            case .newSinceView, nil:
                return false
            }
        })
        append(
            items.filter {
                $0.attentionReason == .newSinceView
                    && !isFocusSuppressed($0, deferredIDs: deferredIDs)
            },
            limit: 5
        )
        append(
            items.filter {
                $0.executionState == .recentlyActive
                    && !deferredIDs.contains($0.id)
                    && !routineLifecycleSuppressed($0)
            },
            limit: 5
        )

        let openCutoff = now.addingTimeInterval(-12 * 60 * 60)
        append(
            items.filter {
                $0.executionState == .openSilent
                    && $0.updatedAt >= openCutoff
                    && !deferredIDs.contains($0.id)
                    && !routineLifecycleSuppressed($0)
            },
            limit: 2
        )

        if result.isEmpty {
            append(
                Array(
                    items.filter {
                        !isFocusSuppressed($0, deferredIDs: deferredIDs)
                    }.prefix(12)
                )
            )
        }
        return Array(result.prefix(12))
    }

    private func prioritizingLastOpened(_ candidates: [ActivityItem]) -> [ActivityItem] {
        guard let lastOpenedID,
              let anchor = candidates.first(where: { $0.id == lastOpenedID }) else {
            return candidates
        }
        return [anchor] + candidates.filter { $0.id != lastOpenedID }
    }

    private func activityDate(for item: ActivityItem) -> Date {
        item.timelineActivityAt
    }

    private func loadContinuityRecords(for loadedItems: [ActivityItem]) {
        let ids = loadedItems.map(\.id)
        guard !ids.isEmpty else {
            recomputeTriage()
            return
        }
        Task { [weak self] in
            guard let self else { return }
            do {
                let loaded = try await continuityStore.records(forTaskIDs: ids)
                for id in ids {
                    continuityRecords.removeValue(forKey: id)
                }
                continuityRecords.merge(loaded) { _, new in new }
                recomputeTriage()
                if triagePresentationPending {
                    triagePresentationPending = false
                    logTriagePresentation()
                }
            } catch {
                actionMessage = localizedFailure(
                    error,
                    turkish: "Yerel iş sürekliliği kayıtları okunamadı",
                    english: "Local work continuity records could not be read"
                )
            }
        }
    }

    private func recomputeTriage(now: Date = Date()) {
        let inputs = items.compactMap { item -> WorkTriageInput? in
            if routineLifecycleSuppressed(item) {
                return nil
            }
            return WorkTriageInput(
                item: item,
                metadata: continuityMetadata(for: item),
                lastOpenedAt: continuityLastViewedAt(for: item)
            )
        }
        triageResult = WorkContinuityRanker.rank(inputs, now: now, limit: 3)
    }

    private func isFocusSuppressed(
        _ item: ActivityItem,
        deferredIDs: Set<String>
    ) -> Bool {
        deferredIDs.contains(item.id) || routineLifecycleSuppressed(item)
    }

    private func routineLifecycleSuppressed(_ item: ActivityItem) -> Bool {
        guard let value = effectiveLifecycleOverride(for: item)?.value else {
            return false
        }
        switch value {
        case .waitingExternal, .completedElsewhere, .superseded, .obsolete, .abandoned, .duplicate:
            return true
        case .current, .blocked:
            return false
        }
    }

    private func workImportance(
        from value: RadarContinuityImportance
    ) -> WorkImportance {
        switch value {
        case .low: return .low
        case .normal: return .normal
        case .high: return .high
        case .critical: return .critical
        }
    }

    private func radarImportance(
        from value: WorkImportance
    ) -> RadarContinuityImportance {
        switch value {
        case .low: return .low
        case .normal: return .normal
        case .high: return .high
        case .critical: return .critical
        }
    }

    private func workLifecycleConfirmation(
        _ record: RadarLifecycleOverrideRecord
    ) -> WorkLifecycleConfirmation {
        let state: WorkLifecycleConfirmedState
        switch record.value {
        case .current: state = .current
        case .waitingExternal: state = .waitingExternal
        case .blocked: state = .blocked
        case .completedElsewhere: state = .completedElsewhere
        case .superseded: state = .superseded
        case .obsolete: state = .obsolete
        case .abandoned: state = .abandoned
        case .duplicate: state = .duplicate
        }
        return WorkLifecycleConfirmation(state: state, confirmedAt: record.setAt)
    }

    private func radarLifecycleDecision(
        for value: RadarLifecycleOverride,
        at date: Date
    ) -> RadarLifecycleDecision {
        switch value {
        case .current:
            return RadarLifecycleDecision(state: .current, reason: .userConfirmed, recordedAt: date)
        case .waitingExternal:
            return RadarLifecycleDecision(state: .waitingExternal, reason: .waitingForExternalEvent, recordedAt: date)
        case .blocked:
            return RadarLifecycleDecision(state: .blocked, reason: .blockedByDependency, recordedAt: date)
        case .completedElsewhere:
            return RadarLifecycleDecision(state: .completedElsewhere, reason: .completedElsewhere, recordedAt: date)
        case .superseded:
            return RadarLifecycleDecision(state: .superseded, reason: .supersededByOtherWork, recordedAt: date)
        case .obsolete:
            return RadarLifecycleDecision(state: .obsoleteConfirmed, reason: .noLongerRelevant, recordedAt: date)
        case .abandoned:
            return RadarLifecycleDecision(state: .abandoned, reason: .userConfirmed, recordedAt: date)
        case .duplicate:
            return RadarLifecycleDecision(state: .duplicate, reason: .duplicateWork, recordedAt: date)
        }
    }

    private func triageReasonLabel(_ code: WorkTriageReasonCode) -> String {
        switch code {
        case .explicitInput: return l10n.text("Yanıtın bekleniyor", "Waiting for your reply")
        case .goalBlocked: return l10n.text("Bloklu hedef", "Blocked goal")
        case .usageLimited: return l10n.text("Kullanım sınırına ulaştı", "Usage limit reached")
        case .budgetLimited: return l10n.text("Görev bütçesine ulaştı", "Task budget reached")
        case .unseenResult: return l10n.text("Görülmemiş sonuç", "Unseen result")
        case .deadlineOverdue: return l10n.text("Son tarih geçti", "Deadline overdue")
        case .deadlineWithinDay: return l10n.text("Son tarih 24 saat içinde", "Deadline within 24 hours")
        case .deadlineWithinThreeDays: return l10n.text("Son tarih 3 gün içinde", "Deadline within 3 days")
        case .deadlineWithinWeek: return l10n.text("Son tarih 7 gün içinde", "Deadline within 7 days")
        case .plannedReturnDue: return l10n.text("Planlanan dönüş zamanı geldi", "Planned return time is due")
        case .criticalImportance: return l10n.text("Kritik olarak işaretlendi", "Marked critical")
        case .highImportance: return l10n.text("Yüksek önem", "High importance")
        case .lowImportance: return l10n.text("Düşük önem", "Low importance")
        case .nextActionRecorded: return l10n.text("Sonraki adım hazır", "Next action is ready")
        case .agingWithoutPlan: return l10n.text("Plan olmadan yaşlanıyor", "Aging without a plan")
        case .recentlyActive: return l10n.text("Şu an açık", "Active now")
        case .recentlyOpened: return l10n.text("Az önce açıldı", "Opened recently")
        case .waitingOnRecorded: return l10n.text("Dışarıdan bekliyor", "Waiting externally")
        case .historyIncomplete: return l10n.text("Geçmiş eksik", "History incomplete")
        }
    }

    private func loadResearchState() async {
        do {
            researchLoggingEnabled = try await continuityStore.isResearchLoggingEnabled()
            await refreshResearchPreview()
        } catch {
            researchLoggingEnabled = false
            researchEventCount = 0
        }
    }

    private func refreshResearchPreview() async {
        do {
            researchEventCount = try await continuityStore.researchExportPreview().eventCount
        } catch {
            researchEventCount = 0
        }
    }

    private func appendResearchEvent(
        _ kind: RadarResearchEventKind,
        for taskID: String,
        at date: Date = Date()
    ) async {
        guard researchLoggingEnabled else { return }
        do {
            _ = try await continuityStore.appendResearchEvent(
                kind: kind,
                forTaskID: taskID,
                condition: .continuityAndTriage,
                at: date
            )
            await refreshResearchPreview()
        } catch {
            actionMessage = localizedFailure(
                error,
                turkish: "Yerel araştırma olayı kaydedilemedi",
                english: "The local research event could not be recorded"
            )
        }
    }

    private func logTriagePresentation() {
        guard researchLoggingEnabled, let triageResult else { return }
        let ids = triageResult.rankedCandidates.map(\.activityID)
        let signature = ids.joined(separator: ":")
            + "|"
            + (triageResult.abstentionReason?.rawValue ?? "recommended")
        guard signature != lastLoggedTriageSignature,
              signature != triageLogInFlightSignature else {
            return
        }
        triageLogInFlightSignature = signature
        let kind: RadarResearchEventKind = triageResult.didAbstain
            ? .insufficientEvidenceShown
            : .triageShown
        let subjectIDs = ids.isEmpty ? [Self.portfolioResearchSubjectID] : ids

        Task { [weak self] in
            guard let self else { return }
            defer {
                if triageLogInFlightSignature == signature {
                    triageLogInFlightSignature = nil
                }
            }
            do {
                let result = try await continuityStore.appendResearchEvents(
                    kind: kind,
                    forTaskIDs: subjectIDs,
                    condition: .continuityAndTriage,
                    at: triageResult.evaluatedAt
                )
                guard result == .stored else { return }
                lastLoggedTriageSignature = signature
                await refreshResearchPreview()
            } catch {
                actionMessage = localizedFailure(
                    error,
                    turkish: "Triyaj gösterimi araştırma günlüğüne yazılamadı; sonraki gösterimde yeniden denenecek",
                    english: "The triage presentation could not be written to the research log; it will be retried next time"
                )
            }
        }
    }

    private var effectiveLoadRange: RadarDateRange {
        scope == .focus
            && query.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            ? .quarter
            : dateRange
    }

    private var metricItems: [ActivityItem] {
        if scope == .all
            || !query.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            return filteredItems
        }
        let deferredIDs = Set(triageResult?.deferred.map(\.activityID) ?? [])
        return items.filter { !isFocusSuppressed($0, deferredIDs: deferredIDs) }
    }

    private func historyItems(now: Date = Date()) -> [ActivityItem] {
        let ranged = items.filter {
            dateRange.contains(activityDate(for: $0), relativeTo: now)
        }
        let sorted = ranged.sorted { left, right in
            let leftDate = activityDate(for: left)
            let rightDate = activityDate(for: right)
            if leftDate != rightDate {
                return leftDate > rightDate
            }
            return left.id < right.id
        }
        return Array(sorted.prefix(dateRange.loadLimit))
    }

    private func effectiveLifecycleOverride(
        for item: ActivityItem
    ) -> RadarLifecycleOverrideRecord? {
        lifecycleOverrides[item.id]
    }

    private func persistLifecycleOverrides() {
        guard let data = try? JSONEncoder().encode(lifecycleOverrides) else { return }
        defaults.set(data, forKey: lifecycleOverridesKey)
    }

    private func acknowledgeDueSnooze(for item: ActivityItem, at date: Date) {
        if var cached = continuityRecords[item.id],
           let snoozeUntil = cached.metadata.snoozeUntil ?? cached.metadata.reviewAt,
           snoozeUntil <= date {
            cached.metadata.snoozeUntil = nil
            cached.metadata.reviewAt = nil
            cached.updatedAt = date
            continuityRecords[item.id] = cached
            recomputeTriage(now: date)
        }

        Task { [weak self] in
            guard let self else { return }
            do {
                guard let persisted = try await continuityStore.record(forTaskID: item.id),
                      let snoozeUntil = persisted.metadata.snoozeUntil ?? persisted.metadata.reviewAt,
                      snoozeUntil <= date else {
                    return
                }
                var metadata = persisted.metadata
                metadata.snoozeUntil = nil
                metadata.reviewAt = nil
                let stored = try await continuityStore.save(
                    capsule: persisted.capsule,
                    metadata: metadata,
                    forTaskID: item.id,
                    at: date
                )
                continuityRecords[item.id] = stored
                recomputeTriage(now: date)
            } catch {
                actionMessage = localizedFailure(
                    error,
                    turkish: "Görev açıldı; geçmiş erteleme işareti temizlenemedi",
                    english: "The task opened, but its expired snooze marker could not be cleared"
                )
            }
        }
    }

    private func localizedFailure(
        _ error: Error,
        turkish: String,
        english: String
    ) -> String {
        if language == .turkish {
            return "\(turkish): \(error.localizedDescription)"
        }
        return english + "."
    }

    private static let exportDateFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.dateFormat = "yyyyMMdd-HHmm"
        return formatter
    }()

    private static let portfolioResearchSubjectID = "activity-radar-portfolio"

}
