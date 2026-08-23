import ActivityRadarCore
import SwiftUI

struct RadarContinuityEditor: View {
    let itemTitle: String
    let checkpoint: String
    let language: RadarLanguage
    let hasStoredPlan: Bool
    let onSave: (WorkImportance, Date?, String, String, Date?) -> Void
    let onClear: () -> Void

    @Environment(\.dismiss) private var dismiss
    @FocusState private var nextActionFocused: Bool
    @State private var importance: WorkImportance
    @State private var nextAction: String
    @State private var waitingOn: String
    @State private var hasDeadline: Bool
    @State private var deadline: Date
    @State private var hasSnooze: Bool
    @State private var snoozeUntil: Date

    init(
        itemTitle: String,
        checkpoint: String,
        language: RadarLanguage,
        initialMetadata: WorkContinuityMetadata,
        hasStoredPlan: Bool,
        onSave: @escaping (WorkImportance, Date?, String, String, Date?) -> Void,
        onClear: @escaping () -> Void
    ) {
        self.itemTitle = itemTitle
        self.checkpoint = checkpoint
        self.language = language
        self.hasStoredPlan = hasStoredPlan
        self.onSave = onSave
        self.onClear = onClear

        let now = Date()
        _importance = State(initialValue: initialMetadata.importance ?? .normal)
        _nextAction = State(initialValue: initialMetadata.nextAction ?? "")
        _waitingOn = State(initialValue: initialMetadata.waitingOn ?? "")
        _hasDeadline = State(initialValue: initialMetadata.deadline != nil)
        _deadline = State(
            initialValue: initialMetadata.deadline
                ?? Calendar.current.date(byAdding: .day, value: 7, to: now)
                ?? now
        )
        _hasSnooze = State(initialValue: initialMetadata.snoozeUntil.map { $0 > now } ?? false)
        _snoozeUntil = State(
            initialValue: initialMetadata.snoozeUntil
                ?? Calendar.current.date(byAdding: .day, value: 1, to: now)
                ?? now
        )
    }

    var body: some View {
        VStack(spacing: 0) {
            header

            ScrollView {
                VStack(alignment: .leading, spacing: 18) {
                    checkpointBlock
                    nextActionBlock
                    importanceBlock
                    deadlineBlock
                    waitingBlock
                    snoozeBlock
                    privacyNote
                }
                .padding(24)
            }

            Divider()
            actions
        }
        .frame(width: 560, height: 650)
        .background(Color(nsColor: .windowBackgroundColor))
        .environment(\.locale, l10n.locale)
        .onAppear {
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.12) {
                nextActionFocused = true
            }
        }
    }

    private var header: some View {
        HStack(spacing: 14) {
            Image(systemName: "bookmark.square.fill")
                .font(.system(size: 25, weight: .semibold))
                .foregroundStyle(Color.accentColor)
                .frame(width: 46, height: 46)
                .background(Color.accentColor.opacity(0.10), in: RoundedRectangle(cornerRadius: 12))

            VStack(alignment: .leading, spacing: 4) {
                Text(l10n.text("İşi park et", "Park this work"))
                    .font(.system(size: 20, weight: .bold))
                Text(itemTitle)
                    .font(.system(size: 13))
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }
            Spacer()
            Button {
                dismiss()
            } label: {
                Image(systemName: "xmark.circle.fill")
                    .font(.system(size: 18))
                    .foregroundStyle(.tertiary)
            }
            .buttonStyle(.plain)
            .accessibilityLabel(l10n.text("Park et penceresini kapat", "Close the park-work window"))
        }
        .padding(.horizontal, 24)
        .frame(height: 76)
        .background(Color(nsColor: .controlBackgroundColor))
        .overlay(alignment: .bottom) { Divider() }
    }

    private var checkpointBlock: some View {
        VStack(alignment: .leading, spacing: 8) {
            sectionTitle(l10n.text("Otomatik kaldığın yer", "Automatic checkpoint"))
            Text(checkpoint)
                .font(.system(size: 13))
                .foregroundStyle(.secondary)
                .lineLimit(4)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(12)
                .background(Color(nsColor: .controlBackgroundColor), in: RoundedRectangle(cornerRadius: 10))
            Text(l10n.text(
                "Codex kaydından salt okunur alındı; düzenlenmeden yerel kapsüle eklenir.",
                "Read from the Codex record without modification and added to the local capsule."
            ))
                .font(.system(size: 11))
                .foregroundStyle(.tertiary)
        }
    }

    private var nextActionBlock: some View {
        VStack(alignment: .leading, spacing: 8) {
            sectionTitle(l10n.text(
                "Döndüğümde yapacağım ilk somut şey",
                "The first concrete thing I will do when I return"
            ))
            TextField(
                l10n.text(
                    "Örn. Sonuç tablosunu kaynak verilerle karşılaştır",
                    "E.g. Compare the results table with the source data"
                ),
                text: $nextAction
            )
                .textFieldStyle(.roundedBorder)
                .font(.system(size: 14))
                .focused($nextActionFocused)
                .accessibilityLabel(l10n.text(
                    "Döndüğünde yapacağın ilk somut şey",
                    "The first concrete thing you will do when you return"
                ))
            Text(l10n.text(
                "Tek cümle yeterli. Amaç yeni bir görev tanımı yazmak değil, yeniden başlama eşiğini düşürmek.",
                "One sentence is enough. The goal is to lower the restart threshold, not define a new task."
            ))
                .font(.system(size: 11))
                .foregroundStyle(.tertiary)
        }
    }

    private var importanceBlock: some View {
        VStack(alignment: .leading, spacing: 8) {
            sectionTitle(l10n.text("Önem", "Importance"))
            Picker(l10n.text("Önem", "Importance"), selection: $importance) {
                ForEach(WorkImportance.allCases, id: \.self) { value in
                    Text(l10n.importanceTitle(value)).tag(value)
                }
            }
            .pickerStyle(.segmented)
            .labelsHidden()
        }
    }

    private var deadlineBlock: some View {
        VStack(alignment: .leading, spacing: 9) {
            Toggle(l10n.text("Son tarih var", "Has a deadline"), isOn: $hasDeadline)
                .font(.system(size: 13, weight: .medium))
            if hasDeadline {
                DatePicker(
                    l10n.text("Son tarih", "Deadline"),
                    selection: $deadline,
                    displayedComponents: [.date, .hourAndMinute]
                )
                .datePickerStyle(.compact)
            }
        }
    }

    private var waitingBlock: some View {
        VStack(alignment: .leading, spacing: 8) {
            sectionTitle(l10n.text(
                "Beklediğim kişi veya olay · isteğe bağlı",
                "Person or event I am waiting for · optional"
            ))
            TextField(
                l10n.text("Örn. ortak yazar geri bildirimi", "E.g. co-author feedback"),
                text: $waitingOn
            )
                .textFieldStyle(.roundedBorder)
                .accessibilityLabel(l10n.text("Beklenen kişi veya olay", "Person or event being awaited"))
        }
    }

    private var snoozeBlock: some View {
        VStack(alignment: .leading, spacing: 9) {
            Toggle(l10n.text("Bu zamana kadar sessize al", "Snooze until this time"), isOn: $hasSnooze)
                .font(.system(size: 13, weight: .medium))
            if hasSnooze {
                DatePicker(
                    l10n.text("Yeniden göster", "Show again"),
                    selection: $snoozeUntil,
                    in: Date()...,
                    displayedComponents: [.date, .hourAndMinute]
                )
                .datePickerStyle(.compact)
            }
        }
    }

    private var privacyNote: some View {
        Label(
            l10n.text(
                "Bu plan yalnızca Mac’indeki AiWingman verilerinde saklanır; Codex dosyalarına yazılmaz ve ağ üzerinden gönderilmez.",
                "This plan is stored only in AiWingman data on your Mac; it is not written to Codex files or sent over the network."
            ),
            systemImage: "lock.shield"
        )
        .font(.system(size: 11))
        .foregroundStyle(.secondary)
        .padding(12)
        .background(Color.green.opacity(0.08), in: RoundedRectangle(cornerRadius: 10))
    }

    private var actions: some View {
        HStack(spacing: 10) {
            if hasStoredPlan {
                Button(l10n.text("Planı temizle", "Clear plan"), role: .destructive) {
                    onClear()
                    dismiss()
                }
            }
            Spacer()
            Button(l10n.text("Vazgeç", "Cancel")) {
                dismiss()
            }
            .keyboardShortcut(.cancelAction)
            Button(l10n.text("Park et", "Park")) {
                onSave(
                    importance,
                    hasDeadline ? deadline : nil,
                    nextAction,
                    waitingOn,
                    hasSnooze ? snoozeUntil : nil
                )
                dismiss()
            }
            .keyboardShortcut(.defaultAction)
            .disabled(!canSave)
        }
        .padding(.horizontal, 24)
        .frame(height: 66)
    }

    private var canSave: Bool {
        !nextAction.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            || !waitingOn.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            || hasDeadline
            || hasSnooze
            || importance != .normal
    }

    private func sectionTitle(_ title: String) -> some View {
        Text(title)
            .font(.system(size: 12, weight: .semibold))
            .foregroundStyle(.secondary)
    }

    private var l10n: RadarL10n {
        RadarL10n(language: language)
    }
}
