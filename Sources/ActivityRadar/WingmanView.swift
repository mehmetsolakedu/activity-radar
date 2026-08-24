import ActivityRadarCore
import SwiftUI

private enum WingmanColors {
    static let text = Color(nsColor: NSColor(calibratedRed: 0.14, green: 0.15, blue: 0.19, alpha: 1))
    static let secondary = Color(nsColor: NSColor(calibratedWhite: 0.40, alpha: 1))
    static let muted = Color(nsColor: NSColor(calibratedWhite: 0.38, alpha: 1))
    static let blue = Color(red: 0.125, green: 0.424, blue: 0.957)
    static let blueSoft = Color(red: 0.93, green: 0.95, blue: 1)
    static let amberSoft = Color(red: 1, green: 0.96, blue: 0.89)
    static let greenSoft = Color(red: 0.91, green: 0.98, blue: 0.93)
    static let redSoft = Color(red: 1, green: 0.92, blue: 0.92)
}

enum WingmanPresentationText {
    static func cliReady(rawVersion: String, language: RadarLanguage) -> String {
        let version = rawVersion
            .split(whereSeparator: \.isWhitespace)
            .map(String.init)
            .first { candidate in
                candidate.range(
                    of: #"^[0-9]+(?:\.[0-9A-Za-z-]+){1,5}$"#,
                    options: .regularExpression
                ) != nil
            }
        guard let version else {
            return language.text(tr: "Codex CLI hazır", en: "Codex CLI ready")
        }
        return language.text(
            tr: "Codex CLI hazır · \(version)",
            en: "Codex CLI ready · \(version)"
        )
    }
}

struct WingmanView: View {
    let language: RadarLanguage
    @StateObject private var model: WingmanFeatureModel
    @Environment(\.dismiss) private var dismiss

    private var copy: RadarL10n { RadarL10n(language: language) }

    init(language: RadarLanguage) {
        self.language = language
        _model = StateObject(wrappedValue: WingmanFeatureModel(language: language))
    }

    var body: some View {
        VStack(spacing: 0) {
            header
            Divider()
            ScrollView {
                VStack(alignment: .leading, spacing: 22) {
                    scopeBlock
                    if model.isLoading {
                        loadingBlock
                    } else if let analysis = model.analysis {
                        portfolioBlock(analysis)
                        agentBlock(analysis)
                        if let review = model.agentReview {
                            reviewBlock(review)
                        }
                    }
                    statusBlock
                }
                .padding(24)
            }
            Divider()
            footer
        }
        .frame(width: 760, height: 720)
        .background(Color.white)
        .onAppear { model.prepare() }
        .onChange(of: model.scope) { _ in model.scopeDidChange() }
        .onChange(of: model.includePromptExcerptsForAgent) { _ in
            model.promptSharingDidChange()
        }
        .onDisappear { model.cancelOutstandingWork() }
    }

    private var header: some View {
        HStack(spacing: 14) {
            Image(systemName: "person.crop.circle.badge.sparkles")
                .font(.system(size: 29, weight: .medium))
                .foregroundStyle(WingmanColors.blue)
                .frame(width: 44, height: 44)
                .background(WingmanColors.blueSoft, in: RoundedRectangle(cornerRadius: 12))
            VStack(alignment: .leading, spacing: 3) {
                Text(copy.text("Bir Wingman Çağır", "Call a Wingman"))
                    .font(.system(size: 21, weight: .bold))
                    .foregroundStyle(WingmanColors.text)
                    .lineLimit(1)
                    .fixedSize(horizontal: true, vertical: false)
                Text(copy.text(
                    "Yoğun işleri, soru ağını, harness'i ve token sinyallerini birlikte gözden geçir",
                    "Review busy work, question graphs, harnesses, and token signals together"
                ))
                    .font(.system(size: 13))
                    .foregroundStyle(WingmanColors.secondary)
                    .lineLimit(1)
                    .minimumScaleFactor(0.85)
            }
            Spacer()
            Button {
                dismiss()
            } label: {
                Image(systemName: "xmark.circle.fill")
                    .font(.system(size: 20))
                    .foregroundStyle(WingmanColors.muted)
            }
            .buttonStyle(.plain)
            .accessibilityLabel(copy.text("Wingman penceresini kapat", "Close the Wingman window"))
        }
        .padding(.horizontal, 24)
        .frame(height: 76)
    }

    private var scopeBlock: some View {
        HStack(spacing: 14) {
            VStack(alignment: .leading, spacing: 3) {
                Text(copy.text("İnceleme kapsamı", "Review scope"))
                    .font(.system(size: 13, weight: .semibold))
                Text(copy.text(
                    "Son etkinliğe göre seçilen en fazla 20 görev ağacı ve gözlenen alt ajan dalları",
                    "Up to 20 selected task trees and observed sub-agent branches by recent activity"
                ))
                    .font(.system(size: 12))
                    .foregroundStyle(WingmanColors.muted)
            }
            .layoutPriority(1)
            Spacer()
            Picker(copy.text("İnceleme kapsamı", "Review scope"), selection: $model.scope) {
                ForEach(WingmanHistoryScope.allCases) { scope in
                    Text(scopeTitle(scope)).tag(scope)
                }
            }
            .pickerStyle(.segmented)
            .labelsHidden()
            .accessibilityLabel(copy.text("İnceleme kapsamı", "Review scope"))
            .frame(width: 280)
            .disabled(model.isLoading || model.isCallingAgent)
        }
    }

    private var loadingBlock: some View {
        HStack(spacing: 12) {
            ProgressView()
                .controlSize(.small)
            VStack(alignment: .leading, spacing: 3) {
                Text(copy.text("Yerel görev ağacı çıkarılıyor…", "Building the local task tree…"))
                    .font(.system(size: 13, weight: .semibold))
                Text(copy.text(
                    "Codex kayıtları salt-okunur taranıyor; rollout okumaları görev başına sınırlı.",
                    "Codex records are scanned read-only; rollout reads are bounded per task."
                ))
                    .font(.system(size: 12))
                    .foregroundStyle(WingmanColors.muted)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(18)
        .background(WingmanColors.blueSoft, in: RoundedRectangle(cornerRadius: 14))
    }

    private func portfolioBlock(_ analysis: WingmanPortfolioAnalysis) -> some View {
        VStack(alignment: .leading, spacing: 13) {
            Label(copy.text("Yerel portföy haritası hazır", "Local portfolio map ready"), systemImage: "point.3.connected.trianglepath.dotted")
                .font(.system(size: 15, weight: .semibold))
                .foregroundStyle(WingmanColors.text)
            HStack(spacing: 10) {
                WingmanMetric(
                    value: "\(analysis.tasks.count)",
                    label: copy.text("seçili pencere", "selected windows"),
                    accessibilityText: copy.text(
                        "\(analysis.tasks.count) seçili pencere",
                        "\(analysis.tasks.count) selected windows"
                    )
                )
                WingmanMetric(
                    value: formatCompactInteger(analysis.selectedObservedCumulativeTokenProxyTotal),
                    label: copy.text("sayaç vekili", "counter proxy"),
                    accessibilityText: copy.text(
                        "\(formatInteger(analysis.selectedObservedCumulativeTokenProxyTotal)) seçili görev ağaçlarında gözlenen kümülatif sayaç vekili",
                        "\(formatInteger(analysis.selectedObservedCumulativeTokenProxyTotal)) observed cumulative counter proxy across selected task trees"
                    )
                )
                WingmanMetric(value: "\(analysis.themes.count)", label: copy.text("tema", "themes"))
                WingmanMetric(value: "\(analysis.partialCoverageTaskCount)", label: copy.text("sınırlı kanıt", "limited evidence"))
            }
            if let top = analysis.tasks.first {
                Text(copy.text(
                    "En yoğun pencere: \(top.evidence.title) · \(formatCompactInteger(top.evidence.observedCumulativeTokenProxy)) gözlenen sayaç · \(top.evidence.childCount) alt dal",
                    "Busiest window: \(top.evidence.title) · \(formatCompactInteger(top.evidence.observedCumulativeTokenProxy)) observed counter · \(top.evidence.childCount) sub-branches"
                ))
                    .font(.system(size: 12, weight: .medium))
                    .foregroundStyle(WingmanColors.secondary)
                    .lineLimit(2)
            }
            Text(copy.text(
                "\(analysis.candidateTaskCount) kapsamda → \(analysis.tasks.count) yerel analizde. Alt ajan rolloutları kümülatif sayaç geçmişini paylaşabilir; bu nedenle düğümler toplamsal varsayılmaz ve her ağaçta yalnız en büyük gözlenen sayaç kullanılır. Bu yalnız karşılaştırma vekilidir; kesin maliyet, israf, dönem, süre veya emek ölçümü değildir.",
                "\(analysis.candidateTaskCount) in scope → \(analysis.tasks.count) in local analysis. Sub-agent rollouts may share cumulative counter history, so nodes are not assumed additive; only the largest observed counter per tree is used. This is only a comparison proxy, not an exact cost, waste, period, time, or effort measure."
            ))
                .font(.system(size: 11))
                .foregroundStyle(WingmanColors.muted)
        }
        .padding(18)
        .background(WingmanColors.greenSoft, in: RoundedRectangle(cornerRadius: 14))
    }

    private func agentBlock(_ analysis: WingmanPortfolioAnalysis) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Label(copy.text("Codex Wingman incelemesi", "Codex Wingman review"), systemImage: "sparkles")
                    .font(.system(size: 15, weight: .semibold))
                Spacer()
                cliBadge
            }
            Text(copy.text(
                "Bu düğme açık masaüstü görevinin içine bağlanmaz; aynı Codex CLI oturumunu kullanan yeni, ayrı ve geçici bir ajan turu açar.",
                "This button does not attach to the open desktop task; it starts a new, separate, ephemeral agent turn using the same Codex CLI login."
            ))
                .font(.system(size: 12, weight: .medium))
                .foregroundStyle(WingmanColors.secondary)
            Text(copy.text(
                "Onaydan sonra aşağıdaki açılır bölümde incelemeye sunulan kullanıcı-türevi JSON paketi, uygulamayla gelen sabit inceleme talimatı ve çıktı şemasıyla birlikte Codex/OpenAI üzerinden işlenir. Sabit metinler görev verisi içermez. Prompt içeriği kapalıyken görevden türetilen serbest metin yalnız temizlenmiş başlıklarla sınırlıdır; prompt örnekleri, prompt-türevi temalar, yerel inceleme sinyalleri ve sonraki adım metinleri pakete alınmaz. Paket yine zaman damgalarını ve etkinlik kesimini, durum/enum alanlarını, boolean değerleri, sayımları, sayısal ölçümleri, şema/dil meta verisini ve sabit yöntem-sınırı metnini taşır. `--ephemeral`, yerel rollout kaydı bırakmaması amaçlanan bir tur ister; hiçbir yerel artifact oluşmadığını kanıtlamaz ve hizmet tarafı saklama davranışını tanımlamaz. AiWingman, agent araçlarının workspace’e yazmasını engellemesi amaçlanan Codex CLI salt-okunur sandbox modunu ister. Bu, OS düzeyinde izolasyon veya sıfır dosya yazma garantisi değildir ve ajanın başka yerel dosyaları okumadığını kanıtlamaz; araç olayı görülürse sonuç atılır.",
                "After consent, the user-derived JSON packet made available for inspection in the expandable section below is processed through Codex/OpenAI together with the fixed review instruction and output schema shipped with the app. Those fixed texts contain no task data. With prompt content off, task-derived free text is limited to sanitized titles; prompt excerpts, prompt-derived themes, local review signals, and next-move text are omitted. The packet still contains timestamps and the activity cutoff, status/enumeration fields, booleans, counts, numeric measurements, schema/language metadata, and a fixed method-boundary string. `--ephemeral` requests a turn intended not to save a local rollout; it does not prove that no local artifact exists or define service-side retention. AiWingman requests Codex CLI read-only sandbox mode, intended to deny agent-tool writes to the workspace. This is neither OS-level isolation nor a zero-filesystem-write guarantee, and it does not prove that the agent reads no other local files; the result is discarded if a tool event is observed."
            ))
                .font(.system(size: 11))
                .foregroundStyle(WingmanColors.muted)
            Text(copy.text(
                "Uzak inceleme, giriş yapılmış Codex CLI hesabını kullanır ve o hesabın planından veya kotasından tüketebilir. AiWingman ayrıca ücret almaz.",
                "The remote review uses the signed-in Codex CLI account and can consume that account's plan or quota. AiWingman charges no separate fee."
            ))
                .font(.system(size: 11, weight: .semibold))
                .foregroundStyle(WingmanColors.secondary)
            cliCheckBlock
            Toggle(
                copy.text("Prompt içeriği, türetilmiş temalar ve yerel sinyalleri paylaş", "Share prompt content, derived themes, and local signals"),
                isOn: $model.includePromptExcerptsForAgent
            )
            .font(.system(size: 12))
            .disabled(model.isLoading || model.isCallingAgent)
            Text(model.includePromptExcerptsForAgent
                ? copy.text(
                    "Prompt eleştirisi; önizlemede görünen sınırlı ham örnekleri, bunlardan türetilen temaları ve yerel sinyalleri kullanır.",
                    "Prompt critique uses the bounded raw excerpts shown in the preview, their derived themes, and local signals."
                )
                : copy.text(
                    "Ham örnekler kapalıyken Wingman prompt cümlelerini ve prompt-türevi metni almaz; temizlenmiş başlıklar ile sınırlı meta veri, sayım ve sayısal sinyalleri inceler.",
                    "With raw excerpts off, Wingman omits prompt sentences and prompt-derived text; it reviews sanitized titles with bounded metadata, counts, and numeric signals."
                ))
                .font(.system(size: 11))
                .foregroundStyle(WingmanColors.muted)
            if let preview = model.packetPreview {
                Text(copy.text(
                    "Uzak paket: \(preview.detailedTaskCount)/\(preview.selectedTaskCount) pencere ayrıntısı · \(preview.omittedDetailedTaskCount) ayrıntısı kesildi · \(preview.themeCount) tema · \(preview.promptExcerptCount) prompt örneği · \(preview.utf8Bytes / 1_024) KiB",
                    "Remote packet: details for \(preview.detailedTaskCount)/\(preview.selectedTaskCount) windows · \(preview.omittedDetailedTaskCount) omitted details · \(preview.themeCount) themes · \(preview.promptExcerptCount) prompt excerpts · \(preview.utf8Bytes / 1_024) KiB"
                ))
                    .font(.system(size: 11, weight: .medium))
                    .foregroundStyle(WingmanColors.secondary)
                DisclosureGroup(copy.text("Gönderilecek paketin tamamını görüntüle", "View the complete packet to be sent")) {
                    ScrollView(.vertical) {
                        Text(preview.packetJSON)
                            .font(.system(size: 10, design: .monospaced))
                            .textSelection(.enabled)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .padding(9)
                    }
                    .frame(height: 180)
                    .background(Color.white, in: RoundedRectangle(cornerRadius: 9))
                    .accessibilityLabel(copy.text(
                        "Codex OpenAI aktarım paketinin tam JSON önizlemesi",
                        "Complete JSON preview of the Codex OpenAI transfer packet"
                    ))
                }
                .font(.system(size: 11, weight: .semibold))
            }
            Toggle(
                copy.text(
                    "Bu önizleme paketinin Codex/OpenAI'a gönderilmesini onaylıyorum",
                    "I consent to sending this previewed packet to Codex/OpenAI"
                ),
                isOn: $model.transmissionConsent
            )
            .font(.system(size: 12, weight: .semibold))
            .disabled(model.isLoading || model.isCallingAgent || model.packetPreview == nil)
            HStack(spacing: 10) {
                if model.isCallingAgent {
                    Button(
                        model.isCancellingAgent
                            ? copy.text("İptal ediliyor…", "Cancelling…")
                            : copy.text("Çağrıyı iptal et", "Cancel call"),
                        role: .destructive
                    ) {
                        model.cancelAgentCall()
                    }
                    .buttonStyle(.bordered)
                    .disabled(model.isCancellingAgent)
                    ProgressView()
                        .controlSize(.small)
                    Text(model.isCancellingAgent
                        ? copy.text("İptal ediliyor…", "Cancelling…")
                        : copy.text("Wingman düşünüyor…", "Wingman is thinking…"))
                        .font(.system(size: 12))
                        .foregroundStyle(WingmanColors.muted)
                } else {
                    Button {
                        model.callWingman()
                    } label: {
                        Label(copy.text("Onayla ve Wingman'ı çağır", "Consent and call Wingman"), systemImage: "person.crop.circle.badge.checkmark")
                            .font(.system(size: 13, weight: .semibold))
                    }
                    .buttonStyle(.borderedProminent)
                    .tint(WingmanColors.blue)
                    .disabled(!model.transmissionConsent || !cliReady || analysis.tasks.isEmpty)
                }
            }
        }
        .padding(18)
        .background(WingmanColors.blueSoft.opacity(0.65), in: RoundedRectangle(cornerRadius: 14))
    }

    private func reviewBlock(_ review: WingmanAgentReview) -> some View {
        VStack(alignment: .leading, spacing: 14) {
            Label(copy.text("Wingman değerlendirmesi", "Wingman review"), systemImage: "checkmark.seal.fill")
                .font(.system(size: 16, weight: .semibold))
                .foregroundStyle(.green)
            Text(review.portfolioSummary)
                .font(.system(size: 13, weight: .medium))
            WingmanReviewSection(title: "Prompt", values: review.promptFindings)
            WingmanReviewSection(title: "Harness", values: review.harnessFindings)
            WingmanReviewSection(title: copy.text("Yarım kalan işler", "Unfinished work"), values: review.unfinishedWork)
            WingmanReviewSection(title: "Token", values: review.tokenFindings)
            WingmanReviewSection(title: copy.text("Tavsiyeler", "Recommendations"), values: review.recommendations)
            WingmanReviewSection(title: copy.text("Sınırlılıklar", "Limitations"), values: review.limitations)
            if let usage = model.agentUsage {
                Text(copy.text(
                    "Bu Wingman çağrısı: \(formatInteger(usage.inputTokens)) girdi · \(formatInteger(usage.cachedInputTokens)) cached · \(formatInteger(usage.outputTokens)) çıktı · \(formatInteger(usage.reasoningOutputTokens)) reasoning tokenı",
                    "This Wingman call: \(formatInteger(usage.inputTokens)) input · \(formatInteger(usage.cachedInputTokens)) cached · \(formatInteger(usage.outputTokens)) output · \(formatInteger(usage.reasoningOutputTokens)) reasoning tokens"
                ))
                    .font(.system(size: 11))
                    .foregroundStyle(WingmanColors.muted)
            }
        }
        .padding(18)
        .background(WingmanColors.greenSoft, in: RoundedRectangle(cornerRadius: 14))
    }

    @ViewBuilder
    private var statusBlock: some View {
        if let error = model.errorMessage {
            Label(error, systemImage: "exclamationmark.triangle.fill")
                .font(.system(size: 12))
                .foregroundStyle(.red)
                .padding(13)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(WingmanColors.redSoft, in: RoundedRectangle(cornerRadius: 12))
        } else if let message = model.actionMessage {
            Label(message, systemImage: "info.circle.fill")
                .font(.system(size: 12))
                .foregroundStyle(WingmanColors.secondary)
                .padding(13)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(WingmanColors.blueSoft, in: RoundedRectangle(cornerRadius: 12))
        }
    }

    private var footer: some View {
        HStack {
            Text(copy.text(
                "Yerel analiz yalnızca salt-okunur Codex kayıtlarını kullanır.",
                "Local analysis uses read-only Codex records only."
            ))
                .font(.system(size: 11))
                .foregroundStyle(WingmanColors.muted)
            Spacer()
            Button(copy.text("Kapat", "Close")) { dismiss() }
                .keyboardShortcut(.cancelAction)
        }
        .padding(.horizontal, 24)
        .frame(height: 54)
        .background(Color(nsColor: NSColor(calibratedWhite: 0.985, alpha: 1)))
    }

    @ViewBuilder
    private var cliCheckBlock: some View {
        switch model.cliState {
        case .unchecked:
            VStack(alignment: .leading, spacing: 8) {
                Label(
                    copy.text(
                        "Bu pencereyi açmak Codex CLI'yi çalıştırmaz. Uzak Wingman özelliği için denetimi siz başlatın.",
                        "Opening this window does not run Codex CLI. Start the check yourself to use the remote Wingman feature."
                    ),
                    systemImage: "terminal"
                )
                .font(.system(size: 11, weight: .medium))
                .foregroundStyle(WingmanColors.secondary)
                Button(copy.text("Codex CLI'yi denetle", "Check Codex CLI")) {
                    model.retryCLIProbe()
                }
                .buttonStyle(.bordered)
                .disabled(model.isLoading || model.isCallingAgent)
                .accessibilityHint(copy.text(
                    "Ajan turu veya görev paketi göndermeden sürüm, komut uyumu ve oturum durumunu denetler; bunun için kayıtlı CLI kimlik doğrulamasının geçici özel bir kopyasını kullanır",
                    "Checks version, command compatibility, and login status without starting an agent turn or sending a task packet; it uses a private temporary copy of the saved CLI authentication"
                ))
            }
            .padding(11)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(WingmanColors.amberSoft, in: RoundedRectangle(cornerRadius: 10))
        case .unavailable(let message):
            VStack(alignment: .leading, spacing: 8) {
                Label(message, systemImage: "terminal.fill")
                    .font(.system(size: 11, weight: .medium))
                    .foregroundStyle(WingmanColors.secondary)
                    .textSelection(.enabled)
                Button(copy.text("Codex CLI'yi yeniden denetle", "Check Codex CLI again")) {
                    model.retryCLIProbe()
                }
                .buttonStyle(.bordered)
                .disabled(model.isLoading || model.isCallingAgent)
                .accessibilityHint(copy.text(
                    "Codex CLI kurulumu ve oturum durumunu yeniden kontrol eder",
                    "Checks the Codex CLI installation and login status again"
                ))
            }
            .padding(11)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(WingmanColors.amberSoft, in: RoundedRectangle(cornerRadius: 10))
        case .checking, .ready:
            EmptyView()
        }
    }

    @ViewBuilder
    private var cliBadge: some View {
        switch model.cliState {
        case .unchecked:
            Text(copy.text("CLI denetlenmedi", "CLI not checked"))
                .foregroundStyle(WingmanColors.muted)
                .lineLimit(1)
        case .checking:
            HStack(spacing: 6) {
                ProgressView().controlSize(.mini)
                Text(copy.text("CLI kontrol ediliyor", "Checking CLI"))
                    .lineLimit(1)
            }
            .foregroundStyle(WingmanColors.muted)
        case .ready(let version):
            Text(WingmanPresentationText.cliReady(rawVersion: version, language: language))
                .foregroundStyle(.green)
                .lineLimit(1)
                .help(copy.text("İmzalı ve doğrulanmış Codex CLI hazır", "Signed and verified Codex CLI is ready"))
        case .unavailable(let message):
            Text(copy.text("Ajan kullanılamıyor", "Agent unavailable"))
                .foregroundStyle(.orange)
                .help(message)
        }
    }

    private var cliReady: Bool {
        if case .ready = model.cliState { return true }
        return false
    }

    private func scopeTitle(_ scope: WingmanHistoryScope) -> String {
        switch scope {
        case .month: return copy.text("30 gün", "30 days")
        case .quarter: return copy.text("90 gün", "90 days")
        case .all: return copy.text("Tüm zamanlar", "All time")
        }
    }

    private func formatInteger(_ value: Int64) -> String {
        let formatter = NumberFormatter()
        formatter.locale = copy.locale
        formatter.numberStyle = .decimal
        formatter.maximumFractionDigits = 0
        return formatter.string(from: NSNumber(value: value)) ?? String(value)
    }

    private func formatCompactInteger(_ value: Int64) -> String {
        let amount = Double(max(0, value))
        let divisor: Double
        let suffix: String
        if amount >= 1_000_000_000 {
            divisor = 1_000_000_000
            suffix = copy.text("milyar", "B")
        } else if amount >= 1_000_000 {
            divisor = 1_000_000
            suffix = copy.text("milyon", "M")
        } else if amount >= 1_000 {
            divisor = 1_000
            suffix = copy.text("bin", "K")
        } else {
            return formatInteger(value)
        }
        let formatter = NumberFormatter()
        formatter.locale = copy.locale
        formatter.numberStyle = .decimal
        formatter.minimumFractionDigits = 0
        formatter.maximumFractionDigits = 1
        let scaled = formatter.string(from: NSNumber(value: amount / divisor))
            ?? String(format: "%.1f", amount / divisor)
        return "\(scaled) \(suffix)"
    }
}

private struct WingmanMetric: View {
    let value: String
    let label: String
    var accessibilityText: String? = nil

    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(value)
                .font(.system(size: 17, weight: .bold))
                .foregroundStyle(WingmanColors.text)
                .lineLimit(1)
                .minimumScaleFactor(0.7)
            Text(label)
                .font(.system(size: 10))
                .foregroundStyle(WingmanColors.muted)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(10)
        .background(Color.white.opacity(0.72), in: RoundedRectangle(cornerRadius: 10))
        .accessibilityElement(children: .combine)
        .accessibilityLabel(accessibilityText ?? "\(value) \(label)")
    }
}

private struct WingmanReviewSection: View {
    let title: String
    let values: [String]

    var body: some View {
        if !values.isEmpty {
            VStack(alignment: .leading, spacing: 5) {
                Text(title)
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(WingmanColors.secondary)
                ForEach(Array(values.prefix(8).enumerated()), id: \.offset) { _, value in
                    HStack(alignment: .top, spacing: 7) {
                        Circle()
                            .fill(WingmanColors.blue)
                            .frame(width: 5, height: 5)
                            .padding(.top, 6)
                        Text(value)
                            .font(.system(size: 12))
                    }
                }
            }
        }
    }
}
