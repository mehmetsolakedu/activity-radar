import ActivityRadarCore
import SwiftUI

struct RadarContinuityEditor: View {
    let itemTitle: String
    let checkpoint: String
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
        initialMetadata: WorkContinuityMetadata,
        hasStoredPlan: Bool,
        onSave: @escaping (WorkImportance, Date?, String, String, Date?) -> Void,
        onClear: @escaping () -> Void
    ) {
        self.itemTitle = itemTitle
        self.checkpoint = checkpoint
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
                Text("İşi park et")
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
            .accessibilityLabel("Park et penceresini kapat")
        }
        .padding(.horizontal, 24)
        .frame(height: 76)
        .background(Color(nsColor: .controlBackgroundColor))
        .overlay(alignment: .bottom) { Divider() }
    }

    private var checkpointBlock: some View {
        VStack(alignment: .leading, spacing: 8) {
            sectionTitle("Otomatik kaldığın yer")
            Text(checkpoint)
                .font(.system(size: 13))
                .foregroundStyle(.secondary)
                .lineLimit(4)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(12)
                .background(Color(nsColor: .controlBackgroundColor), in: RoundedRectangle(cornerRadius: 10))
            Text("Codex kaydından salt okunur alındı; düzenlenmeden yerel kapsüle eklenir.")
                .font(.system(size: 11))
                .foregroundStyle(.tertiary)
        }
    }

    private var nextActionBlock: some View {
        VStack(alignment: .leading, spacing: 8) {
            sectionTitle("Döndüğümde yapacağım ilk somut şey")
            TextField("Örn. Sonuç tablosunu kaynak verilerle karşılaştır", text: $nextAction)
                .textFieldStyle(.roundedBorder)
                .font(.system(size: 14))
                .focused($nextActionFocused)
                .accessibilityLabel("Döndüğünde yapacağın ilk somut şey")
            Text("Tek cümle yeterli. Amaç yeni bir görev tanımı yazmak değil, yeniden başlama eşiğini düşürmek.")
                .font(.system(size: 11))
                .foregroundStyle(.tertiary)
        }
    }

    private var importanceBlock: some View {
        VStack(alignment: .leading, spacing: 8) {
            sectionTitle("Önem")
            Picker("Önem", selection: $importance) {
                ForEach(WorkImportance.allCases, id: \.self) { value in
                    Text(importanceTitle(value)).tag(value)
                }
            }
            .pickerStyle(.segmented)
            .labelsHidden()
        }
    }

    private var deadlineBlock: some View {
        VStack(alignment: .leading, spacing: 9) {
            Toggle("Son tarih var", isOn: $hasDeadline)
                .font(.system(size: 13, weight: .medium))
            if hasDeadline {
                DatePicker(
                    "Son tarih",
                    selection: $deadline,
                    displayedComponents: [.date, .hourAndMinute]
                )
                .datePickerStyle(.compact)
            }
        }
    }

    private var waitingBlock: some View {
        VStack(alignment: .leading, spacing: 8) {
            sectionTitle("Beklediğim kişi veya olay · isteğe bağlı")
            TextField("Örn. ortak yazar geri bildirimi", text: $waitingOn)
                .textFieldStyle(.roundedBorder)
                .accessibilityLabel("Beklenen kişi veya olay")
        }
    }

    private var snoozeBlock: some View {
        VStack(alignment: .leading, spacing: 9) {
            Toggle("Bu zamana kadar sessize al", isOn: $hasSnooze)
                .font(.system(size: 13, weight: .medium))
            if hasSnooze {
                DatePicker(
                    "Yeniden göster",
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
            "Bu plan yalnızca Mac’indeki Activity Radar verilerinde saklanır; Codex dosyalarına yazılmaz ve ağ üzerinden gönderilmez.",
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
                Button("Planı temizle", role: .destructive) {
                    onClear()
                    dismiss()
                }
            }
            Spacer()
            Button("Vazgeç") {
                dismiss()
            }
            .keyboardShortcut(.cancelAction)
            Button("Park et") {
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

    private func importanceTitle(_ value: WorkImportance) -> String {
        switch value {
        case .low: return "Düşük"
        case .normal: return "Normal"
        case .high: return "Yüksek"
        case .critical: return "Kritik"
        }
    }
}
