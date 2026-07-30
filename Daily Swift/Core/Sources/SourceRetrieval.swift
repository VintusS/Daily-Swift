import Foundation

struct SourceRetrievalRequest: Equatable, Sendable {
    static let maximumQueryCharacterCount = 200
    static let maximumResultCount = 8

    let query: String
    let sourceIDs: Set<UUID>
    let resultLimit: Int

    init(
        query: String,
        sourceIDs: Set<UUID> = [],
        resultLimit: Int = 4
    ) {
        self.query = query
        self.sourceIDs = sourceIDs
        self.resultLimit = resultLimit
    }

    func validated()
        throws(SourceRetrievalFailure) -> ValidatedSourceRetrievalRequest {
        let cleanQuery = query.trimmingCharacters(
            in: .whitespacesAndNewlines
        )
        guard !cleanQuery.isEmpty else {
            throw .emptyQuery
        }
        guard cleanQuery.count <= Self.maximumQueryCharacterCount else {
            throw .queryTooLong
        }
        guard (1...Self.maximumResultCount).contains(resultLimit) else {
            throw .invalidResultLimit
        }
        let terms = SourceRetrievalTokenizer.tokens(in: cleanQuery)
        guard !terms.isEmpty else {
            throw .emptyQuery
        }
        return ValidatedSourceRetrievalRequest(
            query: cleanQuery,
            terms: terms,
            sourceIDs: sourceIDs,
            resultLimit: resultLimit
        )
    }
}

struct SourceRetrievalMatch: Equatable, Sendable {
    let document: SourceDocument
    let citation: SourceCitation
    let excerpt: String
    let score: Double
    let matchedTerms: [String]
}

enum SourceRetrievalFailure: Error, Equatable, Sendable {
    case emptyQuery
    case queryTooLong
    case invalidResultLimit
    case cancelled
    case sourceUnavailable
    case indexUnavailable
}

protocol SourceRetrieving: Sendable {
    func search(
        _ request: SourceRetrievalRequest
    ) async throws(SourceRetrievalFailure) -> [SourceRetrievalMatch]
}

actor DirectScanSourceRetriever: SourceRetrieving {
    private let corpusLoader: SourceRetrievalCorpusLoader

    init(sourceLibrary: any SourceLibraryServing) {
        corpusLoader = SourceRetrievalCorpusLoader(
            sourceLibrary: sourceLibrary
        )
    }

    func search(
        _ request: SourceRetrievalRequest
    ) async throws(SourceRetrievalFailure) -> [SourceRetrievalMatch] {
        let request = try request.validated()
        let corpus = try await corpusLoader.load(
            sourceIDs: request.sourceIDs
        )
        return Self.rank(
            corpus,
            for: request
        )
    }

    static func rank(
        _ corpus: [SourceRetrievalCorpusEntry],
        for request: ValidatedSourceRetrievalRequest
    ) -> [SourceRetrievalMatch] {
        corpus.compactMap { entry in
            let bodyTerms = SourceRetrievalTokenizer.tokens(
                in: entry.resolvedCitation.excerpt,
                keepingDuplicates: true
            )
            let headingTerms = SourceRetrievalTokenizer.tokens(
                in: entry.resolvedCitation.citation.headingPath
                    .joined(separator: " "),
                keepingDuplicates: true
            )
            let bodyFrequencies = termFrequencies(bodyTerms)
            let headingFrequencies = termFrequencies(headingTerms)
            let matchedTerms = request.terms.filter {
                bodyFrequencies[$0] != nil
                    || headingFrequencies[$0] != nil
            }
            guard !matchedTerms.isEmpty else {
                return nil
            }

            let coverage = Double(matchedTerms.count)
                / Double(request.terms.count)
            let bodyFrequency = matchedTerms.reduce(0) {
                $0 + min(bodyFrequencies[$1, default: 0], 8)
            }
            let headingFrequency = matchedTerms.reduce(0) {
                $0 + min(headingFrequencies[$1, default: 0], 4)
            }
            let hasExactTermSequence = containsSequence(
                request.terms,
                in: bodyTerms
            ) || containsSequence(
                request.terms,
                in: headingTerms
            )
            let score = coverage * 100
                + Double(headingFrequency * 12)
                + Double(bodyFrequency * 2)
                + (hasExactTermSequence ? 25 : 0)

            return RankedMatch(
                match: SourceRetrievalMatch(
                    document: entry.resolvedCitation.document,
                    citation: entry.resolvedCitation.citation,
                    excerpt: entry.resolvedCitation.excerpt,
                    score: score,
                    matchedTerms: matchedTerms
                ),
                matchedTermCount: matchedTerms.count,
                hasExactTermSequence: hasExactTermSequence,
                headingFrequency: headingFrequency,
                bodyFrequency: bodyFrequency
            )
        }
        .sorted(by: isOrderedBefore)
        .prefix(request.resultLimit)
        .map(\.match)
    }

    private static func termFrequencies(
        _ terms: [String]
    ) -> [String: Int] {
        terms.reduce(into: [:]) {
            $0[$1, default: 0] += 1
        }
    }

    private static func containsSequence(
        _ query: [String],
        in candidate: [String]
    ) -> Bool {
        guard !query.isEmpty,
              query.count <= candidate.count else {
            return false
        }
        if query.count == 1 {
            return candidate.contains(query[0])
        }
        for start in 0...(candidate.count - query.count)
            where Array(candidate[start..<(start + query.count)]) == query {
            return true
        }
        return false
    }

    private static func isOrderedBefore(
        _ lhs: RankedMatch,
        _ rhs: RankedMatch
    ) -> Bool {
        if lhs.matchedTermCount != rhs.matchedTermCount {
            return lhs.matchedTermCount > rhs.matchedTermCount
        }
        if lhs.hasExactTermSequence != rhs.hasExactTermSequence {
            return lhs.hasExactTermSequence
        }
        if lhs.headingFrequency != rhs.headingFrequency {
            return lhs.headingFrequency > rhs.headingFrequency
        }
        if lhs.bodyFrequency != rhs.bodyFrequency {
            return lhs.bodyFrequency > rhs.bodyFrequency
        }
        let lhsSource = lhs.match.document.id.uuidString.lowercased()
        let rhsSource = rhs.match.document.id.uuidString.lowercased()
        if lhsSource != rhsSource {
            return lhsSource < rhsSource
        }
        return lhs.match.citation.chunkID
            < rhs.match.citation.chunkID
    }

    private struct RankedMatch {
        let match: SourceRetrievalMatch
        let matchedTermCount: Int
        let hasExactTermSequence: Bool
        let headingFrequency: Int
        let bodyFrequency: Int
    }
}

actor InMemorySourceRetriever: SourceRetrieving {
    private var outcomes: [
        Result<[SourceRetrievalMatch], SourceRetrievalFailure>
    ]

    init(
        outcomes: [
            Result<[SourceRetrievalMatch], SourceRetrievalFailure>
        ] = [.success([])]
    ) {
        self.outcomes = outcomes
    }

    func search(
        _ request: SourceRetrievalRequest
    ) async throws(SourceRetrievalFailure) -> [SourceRetrievalMatch] {
        _ = try request.validated()
        guard !outcomes.isEmpty else {
            return []
        }
        return try outcomes.removeFirst().get()
    }
}

struct SourceRetrievalCorpusEntry: Equatable, Sendable {
    let key: String
    let resolvedCitation: ResolvedSourceCitation

    init(resolvedCitation: ResolvedSourceCitation) {
        self.resolvedCitation = resolvedCitation
        key = [
            resolvedCitation.document.id.uuidString.lowercased(),
            resolvedCitation.citation.chunkID,
        ].joined(separator: "|")
    }
}

struct SourceRetrievalCorpusLoader: Sendable {
    let sourceLibrary: any SourceLibraryServing

    func load(
        sourceIDs: Set<UUID> = []
    ) async throws(SourceRetrievalFailure)
        -> [SourceRetrievalCorpusEntry] {
        guard !Task.isCancelled else {
            throw .cancelled
        }
        let snapshot: SourceLibrarySnapshot
        do {
            snapshot = try await sourceLibrary.restore()
        } catch {
            if Task.isCancelled {
                throw .cancelled
            }
            throw .sourceUnavailable
        }

        let selectedChunks = snapshot.chunks
            .filter {
                sourceIDs.isEmpty || sourceIDs.contains($0.sourceID)
            }
            .sorted {
                if $0.sourceID != $1.sourceID {
                    return $0.sourceID.uuidString.lowercased()
                        < $1.sourceID.uuidString.lowercased()
                }
                return $0.ordinal < $1.ordinal
            }
        var entries: [SourceRetrievalCorpusEntry] = []
        entries.reserveCapacity(selectedChunks.count)

        for chunk in selectedChunks {
            guard !Task.isCancelled else {
                throw .cancelled
            }
            do {
                entries.append(
                    SourceRetrievalCorpusEntry(
                        resolvedCitation: try await sourceLibrary.resolve(
                            chunk.citation
                        )
                    )
                )
            } catch {
                if Task.isCancelled {
                    throw .cancelled
                }
                throw .sourceUnavailable
            }
        }
        return entries
    }
}

struct ValidatedSourceRetrievalRequest: Equatable, Sendable {
    let query: String
    let terms: [String]
    let sourceIDs: Set<UUID>
    let resultLimit: Int
}

enum SourceRetrievalTokenizer {
    private static let locale = Locale(identifier: "en_US_POSIX")
    private static let ignoredTerms: Set<String> = [
        "a", "an", "and", "are", "as", "at", "by", "for", "from", "in",
        "is", "of", "on", "or", "the", "through", "to", "with",
    ]

    static func tokens(
        in text: String,
        keepingDuplicates: Bool = false
    ) -> [String] {
        let folded = text
            .folding(
                options: [.diacriticInsensitive, .widthInsensitive],
                locale: locale
            )
            .lowercased(with: locale)
        let scalars = folded.unicodeScalars.map {
            CharacterSet.alphanumerics.contains($0)
                ? Character(String($0))
                : " "
        }
        let tokens = String(scalars)
            .split(whereSeparator: \.isWhitespace)
            .map { stem(String($0)) }
            .filter {
                !$0.isEmpty && !ignoredTerms.contains($0)
            }
        if keepingDuplicates {
            return tokens
        }
        var seen: Set<String> = []
        return tokens.filter { seen.insert($0).inserted }
    }

    private static func stem(_ term: String) -> String {
        if term.count > 4, term.hasSuffix("ies") {
            return String(term.dropLast(3)) + "y"
        }
        if term.count > 5, term.hasSuffix("sses") {
            return String(term.dropLast(2))
        }
        if term.count > 5, term.hasSuffix("ing") {
            return removingDoubledEnding(
                from: String(term.dropLast(3))
            )
        }
        if term.count > 4, term.hasSuffix("ed") {
            return removingDoubledEnding(
                from: String(term.dropLast(2))
            )
        }
        let endingsThatDropES = [
            "ches", "oes", "shes", "xes", "zes",
        ]
        if term.count > 4,
           endingsThatDropES.contains(where: term.hasSuffix) {
            return String(term.dropLast(2))
        }
        if term.count > 3,
           term.hasSuffix("s"),
           !term.hasSuffix("ss") {
            return String(term.dropLast())
        }
        return term
    }

    private static func removingDoubledEnding(
        from term: String
    ) -> String {
        guard term.count > 2,
              term.last == term.dropLast().last else {
            return term
        }
        return String(term.dropLast())
    }
}
