#if DEBUG
import Foundation
import SQLite3

actor SQLiteFTS5SourceRetrievalIndex {
    static let currentIndexVersion = 1

    private let databaseURL: URL

    init(databaseURL: URL) {
        self.databaseURL = databaseURL
    }

    func rebuild(
        from entries: [SourceRetrievalCorpusEntry]
    ) throws {
        try withDatabase { database in
            try execute(
                "BEGIN IMMEDIATE TRANSACTION",
                in: database
            )
            do {
                try execute(
                    "DROP TABLE IF EXISTS source_chunks",
                    in: database
                )
                try execute(
                    "DROP TABLE IF EXISTS retrieval_index_metadata",
                    in: database
                )
                try execute(
                    """
                    CREATE TABLE retrieval_index_metadata(
                        version INTEGER NOT NULL
                    )
                    """,
                    in: database
                )
                try execute(
                    """
                    INSERT INTO retrieval_index_metadata(version)
                    VALUES (\(Self.currentIndexVersion))
                    """,
                    in: database
                )
                try execute(
                    """
                    CREATE VIRTUAL TABLE source_chunks USING fts5(
                        entry_key UNINDEXED,
                        source_id UNINDEXED,
                        heading,
                        body,
                        tokenize = 'porter unicode61 remove_diacritics 2'
                    )
                    """,
                    in: database
                )
                try insert(entries, into: database)
                try execute("COMMIT", in: database)
            } catch {
                try? execute("ROLLBACK", in: database)
                throw SourceRetrievalFailure.indexUnavailable
            }
        }
    }

    func search(
        _ request: SourceRetrievalRequest,
        in entries: [SourceRetrievalCorpusEntry]
    ) throws -> [SourceRetrievalMatch] {
        let request = try request.validated()
        let entriesByKey = Dictionary(
            uniqueKeysWithValues: entries.map { ($0.key, $0) }
        )
        return try withDatabase { database in
            guard try indexVersion(in: database)
                == Self.currentIndexVersion else {
                throw SourceRetrievalFailure.indexUnavailable
            }
            var statement: OpaquePointer?
            var query = """
                SELECT entry_key, bm25(source_chunks, 0.0, 0.0, 4.0, 1.0)
                FROM source_chunks
                WHERE source_chunks MATCH ?
                """
            let sortedSourceIDs = request.sourceIDs
                .map { $0.uuidString.lowercased() }
                .sorted()
            if !sortedSourceIDs.isEmpty {
                query += " AND source_id IN ("
                    + Array(
                        repeating: "?",
                        count: sortedSourceIDs.count
                    )
                    .joined(separator: ",")
                    + ")"
            }
            query += " ORDER BY 2 ASC, entry_key ASC LIMIT ?"

            guard sqlite3_prepare_v2(
                database,
                query,
                -1,
                &statement,
                nil
            ) == SQLITE_OK,
            let statement else {
                throw SourceRetrievalFailure.indexUnavailable
            }
            defer {
                sqlite3_finalize(statement)
            }

            var parameter: Int32 = 1
            try bind(
                request.terms
                    .map { "\"\(escapedFTSTerm($0))\"*" }
                    .joined(separator: " OR "),
                at: parameter,
                in: statement
            )
            parameter += 1
            for sourceID in sortedSourceIDs {
                try bind(
                    sourceID,
                    at: parameter,
                    in: statement
                )
                parameter += 1
            }
            guard sqlite3_bind_int(
                statement,
                parameter,
                Int32(request.resultLimit)
            ) == SQLITE_OK else {
                throw SourceRetrievalFailure.indexUnavailable
            }

            var results: [SourceRetrievalMatch] = []
            while true {
                let step = sqlite3_step(statement)
                if step == SQLITE_DONE {
                    break
                }
                guard step == SQLITE_ROW,
                      let keyText = sqlite3_column_text(statement, 0) else {
                    throw SourceRetrievalFailure.indexUnavailable
                }
                let key = String(cString: keyText)
                guard let entry = entriesByKey[key] else {
                    throw SourceRetrievalFailure.indexUnavailable
                }
                let bodyTerms = Set(
                    SourceRetrievalTokenizer.tokens(
                        in: entry.resolvedCitation.excerpt
                    )
                )
                let headingTerms = Set(
                    SourceRetrievalTokenizer.tokens(
                        in: entry.resolvedCitation.citation.headingPath
                            .joined(separator: " ")
                    )
                )
                results.append(
                    SourceRetrievalMatch(
                        document: entry.resolvedCitation.document,
                        citation: entry.resolvedCitation.citation,
                        excerpt: entry.resolvedCitation.excerpt,
                        score: -sqlite3_column_double(statement, 1),
                        matchedTerms: request.terms.filter {
                            bodyTerms.contains($0)
                                || headingTerms.contains($0)
                        }
                    )
                )
            }
            return results
        }
    }

    func removeIndex() throws {
        guard FileManager.default.fileExists(
            atPath: databaseURL.path
        ) else {
            return
        }
        do {
            try FileManager.default.removeItem(at: databaseURL)
        } catch {
            throw SourceRetrievalFailure.indexUnavailable
        }
    }

    private func withDatabase<Result>(
        _ operation: (OpaquePointer) throws -> Result
    ) throws -> Result {
        var database: OpaquePointer?
        guard sqlite3_open_v2(
            databaseURL.path,
            &database,
            SQLITE_OPEN_CREATE | SQLITE_OPEN_READWRITE | SQLITE_OPEN_FULLMUTEX,
            nil
        ) == SQLITE_OK,
        let database else {
            if let database {
                sqlite3_close(database)
            }
            throw SourceRetrievalFailure.indexUnavailable
        }
        defer {
            sqlite3_close(database)
        }
        return try operation(database)
    }

    private func insert(
        _ entries: [SourceRetrievalCorpusEntry],
        into database: OpaquePointer
    ) throws {
        let query = """
            INSERT INTO source_chunks(
                entry_key,
                source_id,
                heading,
                body
            ) VALUES (?, ?, ?, ?)
            """
        var statement: OpaquePointer?
        guard sqlite3_prepare_v2(
            database,
            query,
            -1,
            &statement,
            nil
        ) == SQLITE_OK,
        let statement else {
            throw SourceRetrievalFailure.indexUnavailable
        }
        defer {
            sqlite3_finalize(statement)
        }

        for entry in entries {
            guard sqlite3_reset(statement) == SQLITE_OK,
                  sqlite3_clear_bindings(statement) == SQLITE_OK else {
                throw SourceRetrievalFailure.indexUnavailable
            }
            try bind(entry.key, at: 1, in: statement)
            try bind(
                entry.resolvedCitation.document.id.uuidString.lowercased(),
                at: 2,
                in: statement
            )
            try bind(
                entry.resolvedCitation.citation.headingPath
                    .joined(separator: " "),
                at: 3,
                in: statement
            )
            try bind(
                entry.resolvedCitation.excerpt,
                at: 4,
                in: statement
            )
            guard sqlite3_step(statement) == SQLITE_DONE else {
                throw SourceRetrievalFailure.indexUnavailable
            }
        }
    }

    private func indexVersion(
        in database: OpaquePointer
    ) throws -> Int {
        var statement: OpaquePointer?
        guard sqlite3_prepare_v2(
            database,
            "SELECT version FROM retrieval_index_metadata LIMIT 1",
            -1,
            &statement,
            nil
        ) == SQLITE_OK,
        let statement else {
            throw SourceRetrievalFailure.indexUnavailable
        }
        defer {
            sqlite3_finalize(statement)
        }
        guard sqlite3_step(statement) == SQLITE_ROW else {
            throw SourceRetrievalFailure.indexUnavailable
        }
        return Int(sqlite3_column_int(statement, 0))
    }

    private func execute(
        _ query: String,
        in database: OpaquePointer
    ) throws {
        guard sqlite3_exec(
            database,
            query,
            nil,
            nil,
            nil
        ) == SQLITE_OK else {
            throw SourceRetrievalFailure.indexUnavailable
        }
    }

    private func bind(
        _ value: String,
        at index: Int32,
        in statement: OpaquePointer
    ) throws {
        let result = value.withCString {
            sqlite3_bind_text(
                statement,
                index,
                $0,
                -1,
                unsafeBitCast(
                    -1,
                    to: sqlite3_destructor_type.self
                )
            )
        }
        guard result == SQLITE_OK else {
            throw SourceRetrievalFailure.indexUnavailable
        }
    }

    private func escapedFTSTerm(_ term: String) -> String {
        term.replacingOccurrences(of: "\"", with: "\"\"")
    }
}
#endif
