import ActivityRadarCore
import Foundation

enum RadarLanguage: String, CaseIterable, Codable, Identifiable, Sendable {
    case turkish = "tr"
    case english = "en"

    static let preferenceKey = "ActivityRadar.language.v1"

    var id: String { rawValue }

    var compactTitle: String {
        switch self {
        case .turkish: return "TR"
        case .english: return "EN"
        }
    }

    var localeIdentifier: String {
        self == .turkish ? "tr_TR" : "en_US"
    }

    func text(tr turkish: String, en english: String) -> String {
        self == .turkish ? turkish : english
    }

    func displayName(in interfaceLanguage: RadarLanguage) -> String {
        switch (self, interfaceLanguage) {
        case (.turkish, .turkish): return "Türkçe"
        case (.turkish, .english): return "Turkish"
        case (.english, .turkish): return "İngilizce"
        case (.english, .english): return "English"
        }
    }

    static func load(from defaults: UserDefaults = .standard) -> RadarLanguage {
        guard let stored = defaults.string(forKey: preferenceKey),
              let language = RadarLanguage(rawValue: stored) else {
            return .turkish
        }
        return language
    }

    func persist(to defaults: UserDefaults = .standard) {
        defaults.set(rawValue, forKey: Self.preferenceKey)
    }
}

struct RadarL10n: Sendable {
    let language: RadarLanguage

    var locale: Locale {
        Locale(identifier: language.localeIdentifier)
    }

    func text(_ turkish: String, _ english: String) -> String {
        language.text(tr: turkish, en: english)
    }

    func scopeTitle(_ scope: RadarScope) -> String {
        switch scope {
        case .focus: return text("Odak", "Focus")
        case .all: return text("Tümü", "All")
        }
    }

    func dateRangeTitle(_ range: RadarDateRange) -> String {
        switch range {
        case .day: return text("24 saat", "24 hours")
        case .week: return text("7 gün", "7 days")
        case .month: return text("30 gün", "30 days")
        case .quarter: return text("90 gün", "90 days")
        case .all: return text("Tüm zamanlar", "All time")
        }
    }

    func focusSectionTitle(_ section: RadarFocusSection) -> String {
        switch section {
        case .lastOpened: return text("Son açma isteği", "Last open request")
        case .attention: return text("Dikkat", "Attention")
        case .newResults: return text("Yeni sonuçlar", "New results")
        case .whyNow: return text("Şimdi bak", "Look now")
        case .active: return text("Şu an açık", "Active now")
        case .openSilent: return text("Sessiz açık", "Open, quiet")
        case .parked: return text("Park edilmiş", "Parked")
        case .other: return text("Diğer", "Other")
        }
    }

    func lifecycleTitle(_ label: RadarLifecycleLabel) -> String {
        switch label {
        case .historical: return text("Geçmiş", "Historical")
        case .stale: return text("Uzun süredir sessiz", "Quiet for a long time")
        case .longParked: return text("Uzun süredir parkta", "Parked for a long time")
        case .unfinishedCandidate: return text("Yarım kalmış olabilir", "May be unfinished")
        case .abandonedCandidate: return text("Durumunu gözden geçir", "Review its status")
        case .snoozed: return text("Ertelendi", "Snoozed")
        case .waitingExternal: return text("Dışarıdan bekliyor", "Waiting externally")
        case .blocked: return text("Bloklu", "Blocked")
        case .completedElsewhere: return text("Başka yerde tamamlandı", "Completed elsewhere")
        case .superseded: return text("Yerine yenisi geçti", "Superseded")
        case .obsolete: return text("Güncelliğini yitirmiş", "Obsolete")
        case .abandoned: return text("Terk edilmiş", "Abandoned")
        case .duplicate: return text("Yinelenen iş", "Duplicate work")
        }
    }

    func lifecycleEvidence(_ label: RadarLifecycleLabel) -> String {
        switch label {
        case .historical:
            return text("Tamamlanan eski görev", "Older completed task")
        case .stale:
            return text(
                "30+ gündür doğrulanmış anlamlı hareket yok",
                "No verified meaningful activity for 30+ days"
            )
        case .longParked:
            return text("90+ gündür park edilmiş", "Parked for 90+ days")
        case .unfinishedCandidate:
            return text("Durdurulmuş ve 30+ gündür sessiz", "Stopped and quiet for 30+ days")
        case .abandonedCandidate:
            return text(
                "Uzun süredir sessiz; durum kararı kullanıcıya ait",
                "Quiet for a long time; the status decision belongs to you"
            )
        case .snoozed:
            return text(
                "Kullanıcının belirlediği dönüş zamanına kadar sessizde",
                "Hidden until the return time you set"
            )
        case .waitingExternal:
            return text(
                "Kullanıcı dışarıdan bir kişi veya olay beklediğini belirtti",
                "You marked this as waiting for an external person or event"
            )
        case .blocked:
            return text("Kullanıcı işi bloklu olarak doğruladı", "You confirmed this work is blocked")
        case .completedElsewhere:
            return text(
                "Kullanıcı işin başka bir yerde tamamlandığını doğruladı",
                "You confirmed this work was completed elsewhere"
            )
        case .superseded:
            return text(
                "Kullanıcı bu işin yerine daha güncel bir iş geçtiğini doğruladı",
                "You confirmed that newer work superseded this work"
            )
        case .obsolete:
            return text(
                "Kullanıcı işin güncelliğini yitirdiğini doğruladı",
                "You confirmed this work is obsolete"
            )
        case .abandoned:
            return text("Kullanıcı işi terk ettiğini doğruladı", "You confirmed this work was abandoned")
        case .duplicate:
            return text(
                "Kullanıcı bunun yinelenen bir iş olduğunu doğruladı",
                "You confirmed this is duplicate work"
            )
        }
    }

    func importanceTitle(_ importance: WorkImportance) -> String {
        switch importance {
        case .low: return text("Düşük", "Low")
        case .normal: return text("Normal", "Normal")
        case .high: return text("Yüksek", "High")
        case .critical: return text("Kritik", "Critical")
        }
    }

    func relativeTime(_ date: Date, relativeTo now: Date = Date()) -> String {
        guard abs(now.timeIntervalSince(date)) >= 10 else {
            return text("şimdi", "now")
        }
        let formatter = RelativeDateTimeFormatter()
        formatter.locale = locale
        formatter.unitsStyle = .full
        return formatter.localizedString(for: date, relativeTo: now)
    }

    func dateTime(_ date: Date) -> String {
        formatted(date, format: "d MMM yyyy HH:mm")
    }

    func fullDateTime(_ date: Date) -> String {
        formatted(date, format: "d MMM yyyy HH:mm:ss")
    }

    func continuityDateTime(_ date: Date) -> String {
        formatted(date, format: "d MMM HH:mm")
    }

    func timeLabel(_ date: Date, relativeTo now: Date = Date()) -> String {
        let calendar = Calendar.current
        if calendar.isDateInToday(date) {
            return formatted(date, format: "HH:mm")
        }
        if calendar.isDateInYesterday(date) {
            return text("Dün", "Yesterday") + " " + formatted(date, format: "HH:mm")
        }
        if calendar.component(.year, from: date) != calendar.component(.year, from: now) {
            return formatted(date, format: "d MMM yyyy")
        }
        return formatted(date, format: "d MMM")
    }

    func supportText(_ information: ActivityRadarSupportInformation) -> String {
        let unassigned = text("atanmamış (yerel derleme)", "unassigned (local build)")
        return [
            text("AiWingman destek bilgisi", "AiWingman support information"),
            text("Uygulama sürümü", "Application version")
                + ": \(localizedMetadata(information.applicationVersion)) (\(localizedMetadata(information.buildNumber)))",
            text("Yayın etiketi", "Release tag") + ": \(information.releaseTag ?? unassigned)",
            text("Kaynak revizyonu", "Source revision")
                + ": \(information.shortSourceRevision ?? unassigned)",
            text("Çalışan mimari", "Running architecture")
                + ": \(localizedMetadata(information.architecture))",
            "macOS: \(localizedMetadata(information.operatingSystemVersion))"
        ].joined(separator: "\n")
    }

    func aboutText(_ information: ActivityRadarSupportInformation) -> String {
        let buildMetadata = supportText(information)
            .split(separator: "\n", omittingEmptySubsequences: false)
            .dropFirst()
            .joined(separator: "\n")
        return [
            buildMetadata,
            "",
            text("Bağımsız bir topluluk projesidir.", "This is an independent community project."),
            text("Resmi bir OpenAI ürünü değildir.", "It is not an official OpenAI product."),
            text("Gizlilik: projenin PRIVACY.md belgesi", "Privacy: the project's PRIVACY.md document"),
            text("Destek: projenin SUPPORT.md belgesi", "Support: the project's SUPPORT.md document")
        ].joined(separator: "\n")
    }

    private func localizedMetadata(_ value: String) -> String {
        value == "bilinmiyor" ? text("bilinmiyor", "unknown") : value
    }

    private func formatted(_ date: Date, format: String) -> String {
        let formatter = DateFormatter()
        formatter.locale = locale
        formatter.dateFormat = format
        return formatter.string(from: date)
    }
}
