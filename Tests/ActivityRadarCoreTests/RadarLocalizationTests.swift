#if canImport(Testing)
import ActivityRadarCore
import Foundation
import Testing
@testable import ActivityRadar

@Test
func radarLanguageDefaultsToTurkishAndPersistsOnlyItsOwnKey() {
    let suiteName = "ActivityRadar.LocalizationTests.\(UUID().uuidString)"
    let defaults = UserDefaults(suiteName: suiteName)!
    defer { defaults.removePersistentDomain(forName: suiteName) }

    #expect(RadarLanguage.load(from: defaults) == .turkish)

    defaults.set("preserve-me", forKey: "ActivityRadar.lastOpenedThreadID.v1")
    RadarLanguage.english.persist(to: defaults)

    #expect(RadarLanguage.load(from: defaults) == .english)
    #expect(defaults.string(forKey: RadarLanguage.preferenceKey) == "en")
    #expect(defaults.string(forKey: "ActivityRadar.lastOpenedThreadID.v1") == "preserve-me")

    defaults.set("unsupported", forKey: RadarLanguage.preferenceKey)
    #expect(RadarLanguage.load(from: defaults) == .turkish)
}

@Test
@MainActor
func radarViewModelChangesLanguageSynchronouslyWithoutTouchingExistingDataKeys() {
    let suiteName = "ActivityRadar.ViewModelLocalizationTests.\(UUID().uuidString)"
    let defaults = UserDefaults(suiteName: suiteName)!
    defer { defaults.removePersistentDomain(forName: suiteName) }

    defaults.set(RadarDateRange.quarter.rawValue, forKey: "ActivityRadar.dateRange.v1")
    defaults.set("thread-42", forKey: "ActivityRadar.lastOpenedThreadID.v1")
    let model = RadarViewModel(defaults: defaults)
    var observedLanguage: RadarLanguage?
    model.languageDidChange = { observedLanguage = $0 }

    model.language = .english

    #expect(model.language == .english)
    #expect(model.l10n.scopeTitle(.focus) == "Focus")
    #expect(observedLanguage == .english)
    #expect(defaults.string(forKey: RadarLanguage.preferenceKey) == "en")
    #expect(defaults.string(forKey: "ActivityRadar.dateRange.v1") == RadarDateRange.quarter.rawValue)
    #expect(defaults.string(forKey: "ActivityRadar.lastOpenedThreadID.v1") == "thread-42")

    model.language = .turkish
    #expect(model.l10n.scopeTitle(.focus) == "Odak")
    #expect(observedLanguage == .turkish)
    #expect(defaults.string(forKey: RadarLanguage.preferenceKey) == "tr")
}

@Test
func radarLocalizationCoversDashboardEnumsInBothLanguages() {
    let turkish = RadarL10n(language: .turkish)
    let english = RadarL10n(language: .english)

    for scope in RadarScope.allCases {
        #expect(!turkish.scopeTitle(scope).isEmpty)
        #expect(!english.scopeTitle(scope).isEmpty)
        #expect(turkish.scopeTitle(scope) != english.scopeTitle(scope))
    }
    for range in RadarDateRange.allCases {
        #expect(!turkish.dateRangeTitle(range).isEmpty)
        #expect(!english.dateRangeTitle(range).isEmpty)
        #expect(turkish.dateRangeTitle(range) != english.dateRangeTitle(range))
    }
    for section in RadarFocusSection.allCases {
        #expect(!turkish.focusSectionTitle(section).isEmpty)
        #expect(!english.focusSectionTitle(section).isEmpty)
        #expect(turkish.focusSectionTitle(section) != english.focusSectionTitle(section))
    }
    for label in RadarLifecycleLabel.allCases {
        #expect(!turkish.lifecycleTitle(label).isEmpty)
        #expect(!english.lifecycleTitle(label).isEmpty)
        #expect(!turkish.lifecycleEvidence(label).isEmpty)
        #expect(!english.lifecycleEvidence(label).isEmpty)
        #expect(turkish.lifecycleTitle(label) != english.lifecycleTitle(label))
        #expect(turkish.lifecycleEvidence(label) != english.lifecycleEvidence(label))
    }
}

@Test
func radarLocalizationSwitchesRelativeDatesAndSupportTextWithoutCachedLocaleLeakage() {
    let turkish = RadarL10n(language: .turkish)
    let english = RadarL10n(language: .english)
    let now = Date(timeIntervalSince1970: 1_768_564_800)

    #expect(turkish.relativeTime(now, relativeTo: now) == "şimdi")
    #expect(english.relativeTime(now, relativeTo: now) == "now")
    #expect(turkish.locale.identifier == "tr_TR")
    #expect(english.locale.identifier == "en_US")

    let information = ActivityRadarSupportInformation(
        applicationVersion: "1.2.0",
        buildNumber: "4",
        releaseTag: nil,
        sourceRevision: String(repeating: "a", count: 40),
        architecture: "arm64",
        operatingSystemVersion: "Version 15.7.1 (Build 24G231)"
    )
    let turkishSupport = turkish.supportText(information)
    let englishSupport = english.supportText(information)

    #expect(turkishSupport.contains("AiWingman destek bilgisi"))
    #expect(turkishSupport.contains("atanmamış (yerel derleme)"))
    #expect(englishSupport.contains("AiWingman support information"))
    #expect(englishSupport.contains("unassigned (local build)"))
    #expect(english.aboutText(information).contains("not an official OpenAI product"))
    #expect(!englishSupport.contains("destek bilgisi"))
}
#endif
