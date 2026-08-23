import Foundation

public enum WingmanPortfolioAnalyzer {
    private struct TaskProfile {
        let task: WingmanTaskEvidence
        let curiosityCounts: [String: Double]
        let workCounts: [String: Double]
        let combinedCounts: [String: Double]
    }

    private struct WeightedPair: Hashable {
        let left: String
        let right: String

        init(_ first: String, _ second: String) {
            if first <= second {
                left = first
                right = second
            } else {
                left = second
                right = first
            }
        }
    }

    public static func analyze(
        _ snapshot: WingmanEvidenceSnapshot,
        maximumThemes: Int = 36
    ) -> WingmanPortfolioAnalysis {
        let tasks = snapshot.tasks
        let profiles = tasks.map(makeProfile)
        let documentCount = max(1, profiles.count)
        var documentFrequency: [String: Int] = [:]
        for profile in profiles {
            for term in profile.combinedCounts.keys {
                documentFrequency[term, default: 0] += 1
            }
        }

        var taskTermWeights: [String: [String: Double]] = [:]
        var fullTaskTermWeights: [String: [String: Double]] = [:]
        var aggregateThemeWeight: [String: Double] = [:]

        for profile in profiles {
            var exactWeights: [String: Double] = [:]
            for term in profile.combinedCounts.keys.sorted() {
                let count = profile.combinedCounts[term] ?? 0
                let df = documentFrequency[term] ?? 1
                let phraseBoost = term.contains(" ") ? 1.25 : 1.0
                exactWeights[term] = (1 + log(max(1, count)))
                    * (1 + log(Double(documentCount + 1) / Double(df + 1)))
                    * phraseBoost
            }
            let selected = exactWeights
                .sorted { left, right in
                    if left.value != right.value { return left.value > right.value }
                    return left.key < right.key
                }
                .prefix(8)
            let selectedWeights = Dictionary(uniqueKeysWithValues: selected.map { ($0.key, $0.value) })
            taskTermWeights[profile.task.id] = selectedWeights
            fullTaskTermWeights[profile.task.id] = exactWeights
            for (term, weight) in selected {
                aggregateThemeWeight[term, default: 0] += weight
            }
        }

        let themeLimit = max(1, min(maximumThemes, 48))
        let selectedThemeLabels = aggregateThemeWeight
            .sorted { left, right in
                if left.value != right.value { return left.value > right.value }
                return left.key < right.key
            }
            .prefix(themeLimit)
            .map(\.key)
        var curiosityWeight: [String: Double] = [:]
        var workWeight: [String: Double] = [:]
        var themeTasks: [String: Set<String>] = [:]
        for profile in profiles {
            for label in selectedThemeLabels where profile.combinedCounts[label] != nil {
                curiosityWeight[label, default: 0] += profile.curiosityCounts[label] ?? 0
                workWeight[label, default: 0] += profile.workCounts[label] ?? 0
                themeTasks[label, default: []].insert(profile.task.id)
            }
        }
        let themeIDByLabel = Dictionary(
            uniqueKeysWithValues: selectedThemeLabels.enumerated().map { index, label in
                (label, String(format: "T%03d", index + 1))
            }
        )
        let labelByThemeID = Dictionary(uniqueKeysWithValues: themeIDByLabel.map { ($0.value, $0.key) })

        var selectedTaskWeights: [String: [String: Double]] = [:]
        var similarityTaskWeights: [String: [String: Double]] = [:]
        for task in tasks {
            selectedTaskWeights[task.id] = (taskTermWeights[task.id] ?? [:]).filter {
                themeIDByLabel[$0.key] != nil
            }
            similarityTaskWeights[task.id] = (fullTaskTermWeights[task.id] ?? [:]).filter {
                themeIDByLabel[$0.key] != nil
            }
        }

        let themeEdges = makeThemeEdges(
            taskWeights: selectedTaskWeights,
            themeIDByLabel: themeIDByLabel
        )
        let themeIDs = selectedThemeLabels.compactMap { themeIDByLabel[$0] }
        let ranks = pageRank(nodeIDs: themeIDs, edges: themeEdges)
        let components = componentNumbers(nodeIDs: themeIDs, edges: themeEdges, ranks: ranks)
        var degrees: [String: Double] = [:]
        for edge in themeEdges {
            degrees[edge.sourceID, default: 0] += edge.weight
            degrees[edge.targetID, default: 0] += edge.weight
        }

        let themes = themeIDs.compactMap { id -> WingmanThemeAnalysis? in
            guard let label = labelByThemeID[id] else { return nil }
            return WingmanThemeAnalysis(
                id: id,
                label: label,
                taskCount: themeTasks[label]?.count ?? 0,
                curiosityWeight: curiosityWeight[label] ?? 0,
                workWeight: workWeight[label] ?? 0,
                weightedDegree: degrees[id] ?? 0,
                pageRank: ranks[id] ?? 0,
                component: components[id] ?? 0
            )
        }
        .sorted { left, right in
            if left.pageRank != right.pageRank { return left.pageRank > right.pageRank }
            if left.weightedDegree != right.weightedDegree {
                return left.weightedDegree > right.weightedDegree
            }
            return left.label < right.label
        }

        let relativeObservedActivityIndices = relativeObservedActivityIndexByTask(tasks)
        let analyzedTasks = tasks.map { task in
            let labels = (selectedTaskWeights[task.id] ?? [:])
                .sorted { left, right in
                    if left.value != right.value { return left.value > right.value }
                    return left.key < right.key
                }
                .map(\.key)
            return WingmanTaskAnalysis(
                id: task.id,
                evidence: task,
                relativeObservedActivityIndex: relativeObservedActivityIndices[task.id] ?? 0,
                selectedThemes: labels
            )
        }
        .sorted { left, right in
            if left.evidence.observedCumulativeTokenProxy != right.evidence.observedCumulativeTokenProxy {
                return left.evidence.observedCumulativeTokenProxy > right.evidence.observedCumulativeTokenProxy
            }
            if left.relativeObservedActivityIndex != right.relativeObservedActivityIndex {
                return left.relativeObservedActivityIndex > right.relativeObservedActivityIndex
            }
            return left.id < right.id
        }

        let taskEdges = makeTaskSimilarityEdges(taskWeights: similarityTaskWeights)
        let questions = makeQuestionBranches(tasks: analyzedTasks)
        let abortedTokens = tasks.reduce(Int64(0)) {
            clampedAdd($0, $1.measuredAbortedTurnTokensLowerBound)
        }
        let reviewSignals = makeReviewSignals(
            tasks: analyzedTasks,
            taskEdges: taskEdges,
            questions: questions,
            abortedTokens: abortedTokens
        )
        let nextMoves = makeNextMoves(
            tasks: analyzedTasks,
            themes: themes,
            questions: questions,
            abortedTokens: abortedTokens
        )
        let selectedTokens = tasks.reduce(Int64(0)) {
            clampedAdd($0, $1.observedCumulativeTokenProxy)
        }

        return WingmanPortfolioAnalysis(
            generatedAt: snapshot.generatedAt,
            taskActivityCutoff: snapshot.taskActivityCutoff,
            candidateTaskCount: snapshot.candidateTaskCount,
            omittedTaskCount: snapshot.omittedTaskCount,
            lifetimeTokenTotalForScopedTasks: snapshot.lifetimeTokenTotalForScopedTasks,
            selectedTaskLifetimeTokenTotal: selectedTokens,
            measuredAbortedTurnTokensLowerBound: abortedTokens,
            completeCoverageTaskCount: tasks.filter { $0.rolloutCoverage == .complete }.count,
            partialCoverageTaskCount: tasks.filter { $0.rolloutCoverage != .complete }.count,
            tasks: analyzedTasks,
            themes: themes,
            themeEdges: themeEdges,
            taskSimilarityEdges: taskEdges,
            questionBranches: questions,
            reviewSignals: reviewSignals,
            recommendedNextMoves: nextMoves
        )
    }

    private static func makeProfile(_ task: WingmanTaskEvidence) -> TaskProfile {
        var curiosity: [String: Double] = [:]
        var work: [String: Double] = [:]
        if let initial = task.initialPrompt {
            merge(termCounts(initial), into: &curiosity, multiplier: 2.0)
        }
        var seenPrompts = Set<String>()
        if let initial = task.initialPrompt {
            seenPrompts.insert(CodexWingmanEvidenceReader.promptFingerprint(initial))
        }
        for prompt in task.promptSamples {
            let fingerprint = CodexWingmanEvidenceReader.promptFingerprint(prompt.text)
            guard seenPrompts.insert(fingerprint).inserted else { continue }
            merge(termCounts(prompt.text), into: &curiosity, multiplier: 1.0)
        }
        merge(termCounts(task.title), into: &work, multiplier: 0.75)
        for branch in task.branchEvidence {
            merge(termCounts(branch), into: &work, multiplier: 1.0)
        }
        var combined = curiosity
        merge(work, into: &combined, multiplier: 1.0)
        return TaskProfile(
            task: task,
            curiosityCounts: curiosity,
            workCounts: work,
            combinedCounts: combined
        )
    }

    private static func termCounts(_ text: String) -> [String: Double] {
        let tokens = tokenize(text)
        var counts: [String: Double] = [:]
        for token in tokens {
            counts[token, default: 0] += 1
        }
        if tokens.count >= 2 {
            for index in 0..<(tokens.count - 1) {
                let phrase = tokens[index] + " " + tokens[index + 1]
                counts[phrase, default: 0] += 1
            }
        }
        return counts
    }

    private static func tokenize(_ raw: String) -> [String] {
        let lowered = raw.lowercased(with: Locale(identifier: "tr_TR"))
        var current = ""
        var tokens: [String] = []
        func flush() {
            guard !current.isEmpty else { return }
            let token = current.trimmingCharacters(in: CharacterSet(charactersIn: "_-"))
            current = ""
            guard token.count >= 3,
                  token.count <= 32,
                  !stopWords.contains(token),
                  token.rangeOfCharacter(from: .letters) != nil else { return }
            tokens.append(token)
        }
        for scalar in lowered.unicodeScalars {
            if CharacterSet.alphanumerics.contains(scalar)
                || scalar.value == 0x5F
                || scalar.value == 0x2D {
                current.unicodeScalars.append(scalar)
            } else {
                flush()
            }
        }
        flush()
        return Array(tokens.prefix(1_500))
    }

    private static func merge(
        _ source: [String: Double],
        into target: inout [String: Double],
        multiplier: Double
    ) {
        for key in source.keys.sorted() {
            target[key, default: 0] += (source[key] ?? 0) * multiplier
        }
    }

    private static func makeThemeEdges(
        taskWeights: [String: [String: Double]],
        themeIDByLabel: [String: String]
    ) -> [WingmanGraphEdge] {
        var pairWeights: [WeightedPair: Double] = [:]
        for taskID in taskWeights.keys.sorted() {
            let weights = taskWeights[taskID] ?? [:]
            guard let maximum = weights.values.max(), maximum > 0 else { continue }
            let entries = weights.keys.sorted().compactMap { label -> (String, Double)? in
                guard let id = themeIDByLabel[label], let weight = weights[label] else { return nil }
                return (id, weight / maximum)
            }
            guard entries.count >= 2 else { continue }
            for leftIndex in 0..<(entries.count - 1) {
                for rightIndex in (leftIndex + 1)..<entries.count {
                    let left = entries[leftIndex]
                    let right = entries[rightIndex]
                    pairWeights[WeightedPair(left.0, right.0), default: 0] += min(left.1, right.1)
                }
            }
        }
        return pruneEdges(pairWeights: pairWeights, neighborsPerNode: 4)
    }

    private static func makeTaskSimilarityEdges(
        taskWeights: [String: [String: Double]]
    ) -> [WingmanGraphEdge] {
        let taskIDs = taskWeights.keys.sorted()
        guard taskIDs.count >= 2 else { return [] }
        var pairs: [WeightedPair: Double] = [:]
        for leftIndex in 0..<(taskIDs.count - 1) {
            for rightIndex in (leftIndex + 1)..<taskIDs.count {
                let leftID = taskIDs[leftIndex]
                let rightID = taskIDs[rightIndex]
                let similarity = cosine(taskWeights[leftID] ?? [:], taskWeights[rightID] ?? [:])
                if similarity >= 0.25 {
                    pairs[WeightedPair(leftID, rightID)] = similarity
                }
            }
        }
        return pruneEdges(pairWeights: pairs, neighborsPerNode: 3)
    }

    private static func pruneEdges(
        pairWeights: [WeightedPair: Double],
        neighborsPerNode: Int
    ) -> [WingmanGraphEdge] {
        var perNode: [String: [(WeightedPair, Double)]] = [:]
        for pair in pairWeights.keys.sorted(by: { ($0.left, $0.right) < ($1.left, $1.right) }) {
            let weight = pairWeights[pair] ?? 0
            perNode[pair.left, default: []].append((pair, weight))
            perNode[pair.right, default: []].append((pair, weight))
        }
        var selected = Set<WeightedPair>()
        for node in perNode.keys.sorted() {
            let strongest = (perNode[node] ?? []).sorted { left, right in
                if left.1 != right.1 { return left.1 > right.1 }
                if left.0.left != right.0.left { return left.0.left < right.0.left }
                return left.0.right < right.0.right
            }
            for entry in strongest.prefix(neighborsPerNode) {
                selected.insert(entry.0)
            }
        }
        return selected.sorted { ($0.left, $0.right) < ($1.left, $1.right) }.map { pair in
            WingmanGraphEdge(
                sourceID: pair.left,
                targetID: pair.right,
                weight: pairWeights[pair] ?? 0
            )
        }
    }

    private static func cosine(_ left: [String: Double], _ right: [String: Double]) -> Double {
        let shared = left.keys.filter { right[$0] != nil }.sorted()
        let dot = shared.reduce(0.0) { $0 + (left[$1] ?? 0) * (right[$1] ?? 0) }
        let leftNorm = sqrt(left.keys.sorted().reduce(0.0) {
            let value = left[$1] ?? 0
            return $0 + value * value
        })
        let rightNorm = sqrt(right.keys.sorted().reduce(0.0) {
            let value = right[$1] ?? 0
            return $0 + value * value
        })
        guard leftNorm > 0, rightNorm > 0 else { return 0 }
        let value = dot / (leftNorm * rightNorm)
        return value.isFinite ? min(1, max(0, value)) : 0
    }

    private static func relativeObservedActivityIndexByTask(
        _ tasks: [WingmanTaskEvidence]
    ) -> [String: Double] {
        func scale(_ value: Int, maximum: Double) -> Double {
            guard maximum > 0 else { return 0 }
            return log(1 + Double(max(0, value))) / maximum
        }
        let bucketMax = tasks.map { log(1 + Double($0.activeBucketCountLowerBound)) }.max() ?? 0
        let turnMax = tasks.map { log(1 + Double($0.userMessageCountLowerBound)) }.max() ?? 0
        let toolMax = tasks.map { log(1 + Double($0.toolCallCountLowerBound)) }.max() ?? 0
        let dayMax = tasks.map { log(1 + Double($0.activeDayCountLowerBound)) }.max() ?? 0
        return Dictionary(uniqueKeysWithValues: tasks.map { task in
            let value = 100 * (
                0.40 * scale(task.activeBucketCountLowerBound, maximum: bucketMax)
                + 0.30 * scale(task.userMessageCountLowerBound, maximum: turnMax)
                + 0.20 * scale(task.toolCallCountLowerBound, maximum: toolMax)
                + 0.10 * scale(task.activeDayCountLowerBound, maximum: dayMax)
            )
            return (task.id, value.isFinite ? value : 0)
        })
    }

    private static func pageRank(
        nodeIDs: [String],
        edges: [WingmanGraphEdge]
    ) -> [String: Double] {
        guard !nodeIDs.isEmpty else { return [:] }
        let sortedNodes = nodeIDs.sorted()
        let count = Double(sortedNodes.count)
        var adjacency: [String: [(String, Double)]] = [:]
        for edge in edges {
            adjacency[edge.sourceID, default: []].append((edge.targetID, edge.weight))
            adjacency[edge.targetID, default: []].append((edge.sourceID, edge.weight))
        }
        var ranks = Dictionary(uniqueKeysWithValues: sortedNodes.map { ($0, 1 / count) })
        let damping = 0.85
        for _ in 0..<100 {
            var next = Dictionary(uniqueKeysWithValues: sortedNodes.map { ($0, (1 - damping) / count) })
            var dangling = 0.0
            for node in sortedNodes {
                let neighbors = adjacency[node] ?? []
                let totalWeight = neighbors.reduce(0.0) { $0 + $1.1 }
                let rank = ranks[node] ?? 0
                if totalWeight <= 0 {
                    dangling += rank
                } else {
                    for neighbor in neighbors.sorted(by: { $0.0 < $1.0 }) {
                        next[neighbor.0, default: 0] += damping * rank * neighbor.1 / totalWeight
                    }
                }
            }
            if dangling > 0 {
                for node in sortedNodes {
                    next[node, default: 0] += damping * dangling / count
                }
            }
            let delta = sortedNodes.reduce(0.0) { $0 + abs((next[$1] ?? 0) - (ranks[$1] ?? 0)) }
            ranks = next
            if delta < 1e-12 { break }
        }
        return ranks.mapValues { $0.isFinite ? max(0, $0) : 0 }
    }

    private static func componentNumbers(
        nodeIDs: [String],
        edges: [WingmanGraphEdge],
        ranks: [String: Double]
    ) -> [String: Int] {
        var adjacency: [String: Set<String>] = [:]
        for edge in edges {
            adjacency[edge.sourceID, default: []].insert(edge.targetID)
            adjacency[edge.targetID, default: []].insert(edge.sourceID)
        }
        var unseen = Set(nodeIDs)
        var groups: [[String]] = []
        while let start = unseen.sorted().first {
            var queue = [start]
            unseen.remove(start)
            var group: [String] = []
            var cursor = 0
            while cursor < queue.count {
                let node = queue[cursor]
                cursor += 1
                group.append(node)
                for neighbor in (adjacency[node] ?? []).sorted() where unseen.remove(neighbor) != nil {
                    queue.append(neighbor)
                }
            }
            groups.append(group.sorted())
        }
        groups.sort { left, right in
            let leftRank = left.reduce(0.0) { $0 + (ranks[$1] ?? 0) }
            let rightRank = right.reduce(0.0) { $0 + (ranks[$1] ?? 0) }
            if leftRank != rightRank { return leftRank > rightRank }
            return (left.first ?? "") < (right.first ?? "")
        }
        var result: [String: Int] = [:]
        for (index, group) in groups.enumerated() {
            for node in group {
                result[node] = index + 1
            }
        }
        return result
    }

    private static func makeQuestionBranches(tasks: [WingmanTaskAnalysis]) -> [WingmanQuestionBranch] {
        var result: [WingmanQuestionBranch] = []
        for task in tasks {
            for prompt in task.evidence.promptSamples where prompt.isExplicitQuestion || prompt.isInvestigationRequest {
                result.append(
                    WingmanQuestionBranch(
                        id: "Q\(String(format: "%03d", result.count + 1))",
                        taskID: task.id,
                        taskTitle: task.evidence.title,
                        excerpt: String(prompt.text.prefix(280)),
                        state: prompt.responseState,
                        isInvestigationRequest: prompt.isInvestigationRequest
                    )
                )
            }
        }
        return Array(result.prefix(50))
    }

    private static func makeReviewSignals(
        tasks: [WingmanTaskAnalysis],
        taskEdges: [WingmanGraphEdge],
        questions: [WingmanQuestionBranch],
        abortedTokens: Int64
    ) -> [WingmanReviewSignal] {
        var signals: [WingmanReviewSignal] = []
        let abortedTurns = tasks.reduce(0) { $0 + $1.evidence.abortedTurnCountLowerBound }
        if abortedTurns > 0 {
            let tokenText = abortedTokens > 0
                ? " Bu turlarda rollout telemetrisinde en az \(formatInteger(abortedTokens)) token raporlandı."
                : " Bu turlara güvenle token atanamadı."
            signals.append(
                WingmanReviewSignal(
                    id: "R001",
                    kind: .abortedTurns,
                    title: "İptal edilen turlar",
                    detail: "Taranan kayıtta en az \(abortedTurns) iptal edilmiş tur var.\(tokenText) Bu, tokenların kesin olarak boşa gittiği anlamına gelmez.",
                    relatedTaskIDs: tasks.filter { $0.evidence.abortedTurnCountLowerBound > 0 }.map(\.id)
                )
            )
        }
        let open = tasks.filter { $0.evidence.hasObservedOpenTurn }
        if !open.isEmpty {
            signals.append(
                WingmanReviewSignal(
                    id: "R\(String(format: "%03d", signals.count + 1))",
                    kind: .openTurns,
                    title: "Açık tur sinyalleri",
                    detail: "\(open.count) yoğun pencerede kapanış olayı görülmeyen bir tur var; önce gerçekten sürüp sürmediğini doğrula.",
                    relatedTaskIDs: open.map(\.id)
                )
            )
        }
        let branching = tasks.filter { $0.evidence.childCount >= 12 }.prefix(5)
        if !branching.isEmpty {
            signals.append(
                WingmanReviewSignal(
                    id: "R\(String(format: "%03d", signals.count + 1))",
                    kind: .highBranching,
                    title: "Yüksek ajan dallanması",
                    detail: "\(branching.count) pencere 12 veya daha fazla alt göreve dallanmış. Harness kapsamını ve kapanış ölçütünü sadeleştirmek için incelemeye değer.",
                    relatedTaskIDs: branching.map(\.id)
                )
            )
        }
        let noContinuation = questions.filter { $0.state == .responseRecorded }
        if !noContinuation.isEmpty {
            signals.append(
                WingmanReviewSignal(
                    id: "R\(String(format: "%03d", signals.count + 1))",
                    kind: .noContinuation,
                    title: "Devam sinyali görülmeyen sorular",
                    detail: "\(noContinuation.count) soru/araştırma isteminde bir ajan yanıtı kaydı var, ardından kullanıcı devamı görülmedi. Bu bir israf kanıtı değil; olası unutulmuş dallar listesidir.",
                    relatedTaskIDs: Array(Set(noContinuation.map(\.taskID))).sorted()
                )
            )
        }
        let noResponse = questions.filter { $0.state == .noRecordedResponse }
        if !noResponse.isEmpty {
            signals.append(
                WingmanReviewSignal(
                    id: "R\(String(format: "%03d", signals.count + 1))",
                    kind: .noRecordedResponse,
                    title: "Yanıt kaydı görülmeyen sorular",
                    detail: "\(noResponse.count) soru/araştırma isteminin ardından anlamlı ajan yanıtı kaydı görülmedi.",
                    relatedTaskIDs: Array(Set(noResponse.map(\.taskID))).sorted()
                )
            )
        }
        let similar = taskEdges.filter { $0.weight >= 0.70 }.prefix(5)
        if !similar.isEmpty {
            signals.append(
                WingmanReviewSignal(
                    id: "R\(String(format: "%03d", signals.count + 1))",
                    kind: .similarWork,
                    title: "Benzer çalışma kümeleri",
                    detail: "\(similar.count) görev çifti seçili temalarda yüksek benzerlik gösteriyor. Bunlar yinelenen iş olabilir; bağlam farkı incelenmeden birleştirilmemeli.",
                    relatedTaskIDs: Array(Set(similar.flatMap { [$0.sourceID, $0.targetID] })).sorted()
                )
            )
        }
        let partial = tasks.filter { $0.evidence.rolloutCoverage != .complete }
        if !partial.isEmpty {
            signals.append(
                WingmanReviewSignal(
                    id: "R\(String(format: "%03d", signals.count + 1))",
                    kind: .partialCoverage,
                    title: "Kısmi rollout kapsamı",
                    detail: "\(partial.count) yoğun pencerenin rollout'u yalnız sınırlandırılmış kuyruktan tarandı. Turn, araç ve soru sayıları bu pencerelerde alt sınırdır.",
                    relatedTaskIDs: partial.map(\.id)
                )
            )
        }
        return signals
    }

    private static func makeNextMoves(
        tasks: [WingmanTaskAnalysis],
        themes: [WingmanThemeAnalysis],
        questions: [WingmanQuestionBranch],
        abortedTokens: Int64
    ) -> [String] {
        var moves: [String] = []
        if let unfinished = questions.first(where: {
            $0.state == .responseRecorded || $0.state == .noRecordedResponse
        }) {
            moves.append("“\(unfinished.taskTitle)” penceresindeki devam sinyali görülmeyen dal için tek bir sonraki adım yaz.")
        }
        if abortedTokens > 0 {
            moves.append("İptal edilen turları sonuç kalitesiyle birlikte gözden geçir; raporlanan tokenı otomatik olarak israf sayma.")
        }
        if let branching = tasks.max(by: { $0.evidence.childCount < $1.evidence.childCount }),
           branching.evidence.childCount >= 8 {
            moves.append("“\(branching.evidence.title)” için alt ajan sayısını, görev bütçesini ve durma kuralını tek harness sözleşmesinde sınırla.")
        }
        if moves.count < 3, let theme = themes.first {
            moves.append("“\(theme.label)” temasındaki işleri tek bir kanıt, karar ve sonraki-adım özeti altında birleştir.")
        }
        if moves.count < 3, let task = tasks.first {
            moves.append("En yoğun pencere “\(task.evidence.title)” için tamamlandı, bekliyor ve bırakıldı ayrımını kullanıcı kararıyla netleştir.")
        }
        while moves.count < 3 {
            moves.append("Yeni bir ajan turu açmadan önce hedefi, kabul ölçütünü ve durma kuralını birer cümleyle yaz.")
        }
        return Array(moves.prefix(3))
    }

    private static func clampedAdd(_ left: Int64, _ right: Int64) -> Int64 {
        let safeLeft = max(0, left)
        let safeRight = max(0, right)
        if safeLeft > Int64.max - safeRight { return Int64.max }
        return safeLeft + safeRight
    }

    private static func formatInteger(_ value: Int64) -> String {
        let formatter = NumberFormatter()
        formatter.locale = Locale(identifier: "tr_TR")
        formatter.numberStyle = .decimal
        formatter.maximumFractionDigits = 0
        return formatter.string(from: NSNumber(value: value)) ?? String(value)
    }

    private static let stopWords: Set<String> = [
        "acaba", "ama", "ancak", "artık", "bana", "belki", "ben", "beni", "benim", "bir", "biraz",
        "biri", "biz", "bize", "bizim", "bu", "buna", "bunu", "burada", "böyle", "çok", "daha",
        "değil", "diye", "dostum", "edecek", "edelim", "eder", "et", "gibi", "göre", "hadi", "hangi",
        "hem", "her", "hiç", "için", "ile", "ise", "kadar", "kendi", "mi", "mı", "mu", "mü", "nasıl",
        "neden", "ne", "olarak", "olan", "oldu", "olsun", "onu", "sonra", "şey", "şimdi", "tamam",
        "var", "ve", "veya", "yani", "yap", "yapalım", "yok", "zaten", "the", "and", "for", "from",
        "that", "this", "with", "you", "your", "are", "was", "were", "have", "has", "had", "can", "could",
        "would", "should", "into", "about", "what", "when", "where", "which", "while", "will", "just", "than",
        "then", "them", "they", "our", "out", "all", "not", "but", "how", "why", "who", "use", "using",
        "please", "continue", "devam", "evet", "hayır", "maybe", "make", "need", "want"
    ]
}
