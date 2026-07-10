import Foundation

private let logger = AppLog.library

actor FileQuizAuditStore: QuizAuditStoring {
    enum Failpoint: Sendable {
        case beforeDraftWrite
        case afterDraftWriteBeforeReplace
        case beforeDraftDelete
        case afterAttemptWriteBeforeDraftDelete
    }

    private let fileManager: FileManager
    private let rootURL: URL
    private let clock: any QuizAuditClock
    private var failpoints: Set<Failpoint> = []

    init(
        fileManager: FileManager = .default,
        rootURL: URL? = nil,
        clock: any QuizAuditClock = SystemQuizAuditClock()
    ) {
        self.fileManager = fileManager
        if let rootURL {
            self.rootURL = rootURL
        } else {
            let support = fileManager.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
            self.rootURL = support.appendingPathComponent("QuizAudit", isDirectory: true)
        }
        self.clock = clock
    }

    var draftsDirectory: URL {
        rootURL.appendingPathComponent("Drafts", isDirectory: true)
    }

    var completedDirectory: URL {
        rootURL.appendingPathComponent("Completed", isDirectory: true)
    }

    func setFailpoints(_ failpoints: Set<Failpoint>) {
        self.failpoints = failpoints
    }

    func createDraft(_ draft: QuizDraft) async throws -> QuizDraft {
        try ensureDirectories()
        let url = draftURL(for: draft.id)
        guard !fileManager.fileExists(atPath: url.path) else {
            throw QuizAuditStoreError.draftAlreadyExists(draft.id)
        }
        try await writeDraft(draft, to: url)
        return draft
    }

    func draft(id: UUID) async throws -> QuizDraft? {
        let url = draftURL(for: id)
        guard fileManager.fileExists(atPath: url.path) else { return nil }
        return try decodeDraft(at: url, fileID: id)
    }

    func listDrafts() async -> QuizAuditListResult<QuizDraftSummary> {
        await listDraftSummaries(matching: { _ in true })
    }

    func listDrafts(forChapter chapterID: String, bookID: String) async -> QuizAuditListResult<QuizDraftSummary> {
        await listDraftSummaries { draft in
            draft.chapter.chapterID == chapterID && draft.chapter.bookID == bookID
        }
    }

    func listDrafts(forBook bookID: String) async -> QuizAuditListResult<QuizDraftSummary> {
        await listDraftSummaries { $0.chapter.bookID == bookID }
    }

    func apply(
        transition: QuizDraftTransition,
        to draftID: UUID,
        expectedRevision: Int
    ) async throws -> QuizDraft {
        guard var draft = try await draft(id: draftID) else {
            throw QuizAuditStoreError.draftNotFound(draftID)
        }
        guard draft.revision == expectedRevision else {
            throw QuizAuditStoreError.staleRevision(expected: expectedRevision, actual: draft.revision)
        }

        let updated = try QuizDraftTransitionApplier.apply(transition, to: draft, now: clock.now())
        try await replaceDraft(updated)
        return updated
    }

    func discardDraft(id: UUID, expectedRevision: Int) async throws {
        guard let draft = try await draft(id: id) else {
            throw QuizAuditStoreError.draftNotFound(id)
        }
        guard draft.revision == expectedRevision else {
            throw QuizAuditStoreError.staleRevision(expected: expectedRevision, actual: draft.revision)
        }
        try fileManager.removeItem(at: draftURL(for: id))
    }

    func finalize(draftID: UUID) async throws -> CompletedQuizAttempt {
        if let draft = try await draft(id: draftID) {
            return try await finalizeExistingDraft(draft)
        }

        if let attempt = try await attempt(id: draftID) {
            return attempt
        }

        throw QuizAuditStoreError.draftNotFound(draftID)
    }

    func attempt(id: UUID) async throws -> CompletedQuizAttempt? {
        let url = attemptURL(for: id)
        guard fileManager.fileExists(atPath: url.path) else { return nil }
        return try decodeAttempt(at: url, fileID: id)
    }

    func listAttempts() async -> QuizAuditListResult<CompletedAttemptSummary> {
        await listAttemptSummaries(matching: { _ in true })
    }

    func listAttempts(forChapter chapterID: String, bookID: String) async -> QuizAuditListResult<CompletedAttemptSummary> {
        await listAttemptSummaries { attempt in
            attempt.chapter.chapterID == chapterID && attempt.chapter.bookID == bookID
        }
    }

    func listAttempts(forBook bookID: String) async -> QuizAuditListResult<CompletedAttemptSummary> {
        await listAttemptSummaries { $0.chapter.bookID == bookID }
    }

    // MARK: - Private

    private func finalizeExistingDraft(_ draft: QuizDraft) async throws -> CompletedQuizAttempt {
        try QuizAuditValidator.validateForCompletion(draft)
        let derivedAttempt = CompletedQuizAttempt(from: draft)

        if let existing = try await attempt(id: draft.id) {
            if semanticContentEquals(existing, derivedAttempt) {
                if fileManager.fileExists(atPath: draftURL(for: draft.id).path) {
                    try? fileManager.removeItem(at: draftURL(for: draft.id))
                }
                return existing
            }
            throw QuizAuditStoreError.attemptConflict(draft.id)
        }

        let attemptURL = attemptURL(for: derivedAttempt.id)
        try await writeAttempt(derivedAttempt, to: attemptURL)
        await triggerFailpoint(.afterAttemptWriteBeforeDraftDelete)

        let draftURL = draftURL(for: draft.id)
        if fileManager.fileExists(atPath: draftURL.path) {
            await triggerFailpoint(.beforeDraftDelete)
            try fileManager.removeItem(at: draftURL)
        }

        return derivedAttempt
    }

    private func replaceDraft(_ draft: QuizDraft) async throws {
        let url = draftURL(for: draft.id)
        await triggerFailpoint(.beforeDraftWrite)
        try await writeDraft(draft, to: url)
        await triggerFailpoint(.afterDraftWriteBeforeReplace)
    }

    private func writeDraft(_ draft: QuizDraft, to url: URL) async throws {
        try QuizAuditValidator.validateDraftIdentity(draft, fileID: draft.id)
        try writePayload(draft, to: url)
    }

    private func writeAttempt(_ attempt: CompletedQuizAttempt, to url: URL) async throws {
        try QuizAuditValidator.validateAttemptIdentity(attempt, fileID: attempt.id)
        try writePayload(attempt, to: url)
    }

    private func writePayload<T: Encodable>(_ payload: T, to url: URL) throws {
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        encoder.outputFormatting = [.sortedKeys]
        let data = try encoder.encode(payload)
        let tempURL = url.deletingLastPathComponent().appendingPathComponent(".\(UUID().uuidString).tmp")
        do {
            try data.write(to: tempURL, options: .atomic)
            if fileManager.fileExists(atPath: url.path) {
                try fileManager.removeItem(at: url)
            }
            try fileManager.moveItem(at: tempURL, to: url)
        } catch {
            try? fileManager.removeItem(at: tempURL)
            logger.error("writePayload failed: \(error.localizedDescription, privacy: .public)")
            throw QuizAuditStoreError.writeFailed
        }
    }

    private func decodeDraft(at url: URL, fileID: UUID) throws -> QuizDraft {
        let draft: QuizDraft = try decodePayload(at: url)
        try QuizAuditValidator.validateDraftIdentity(draft, fileID: fileID)
        return draft
    }

    private func decodeAttempt(at url: URL, fileID: UUID) throws -> CompletedQuizAttempt {
        let attempt: CompletedQuizAttempt = try decodePayload(at: url)
        try QuizAuditValidator.validateAttemptIdentity(attempt, fileID: fileID)
        return attempt
    }

    private func decodePayload<T: Decodable>(at url: URL) throws -> T {
        do {
            let data = try Data(contentsOf: url)
            let decoder = JSONDecoder()
            decoder.dateDecodingStrategy = .iso8601
            return try decoder.decode(T.self, from: data)
        } catch let error as QuizAuditValidationError {
            throw QuizAuditStoreError.validation(error)
        } catch {
            throw QuizAuditStoreError.readFailed
        }
    }

    private func listDraftSummaries(
        matching predicate: (QuizDraft) -> Bool
    ) async -> QuizAuditListResult<QuizDraftSummary> {
        var issues: [RecoveryIssue] = []
        var summaries: [QuizDraftSummary] = []

        guard let urls = try? fileManager.contentsOfDirectory(
            at: draftsDirectory,
            includingPropertiesForKeys: nil
        ) else {
            return QuizAuditListResult(items: [], issues: [])
        }

        for url in urls where url.pathExtension == "json" {
            guard let fileID = UUID(uuidString: url.deletingPathExtension().lastPathComponent) else {
                issues.append(RecoveryIssue(kind: .identityMismatch, fileURL: url, message: "Invalid draft filename."))
                continue
            }

            do {
                let draft = try decodeDraft(at: url, fileID: fileID)
                if predicate(draft) {
                    if let shadow = try await shadowAttempt(for: draft) {
                        if semanticContentEquals(shadow, CompletedQuizAttempt(from: draft)) {
                            try? fileManager.removeItem(at: url)
                            issues.append(RecoveryIssue(kind: .shadowDraft, fileURL: url, message: "Removed shadow draft \(draft.id)."))
                            continue
                        }
                        issues.append(RecoveryIssue(kind: .conflictingPair, fileURL: url, message: "Draft \(draft.id) conflicts with completed attempt."))
                        continue
                    }
                    summaries.append(QuizDraftSummary(draft: draft))
                }
            } catch let error as QuizAuditStoreError {
                issues.append(recoveryIssue(for: error, url: url))
            } catch {
                issues.append(RecoveryIssue(kind: .corruptFile, fileURL: url, message: error.localizedDescription))
            }
        }

        summaries.sort(by: Self.sortSummaries)
        return QuizAuditListResult(items: summaries, issues: issues)
    }

    private func listAttemptSummaries(
        matching predicate: (CompletedQuizAttempt) -> Bool
    ) async -> QuizAuditListResult<CompletedAttemptSummary> {
        var issues: [RecoveryIssue] = []
        var summaries: [CompletedAttemptSummary] = []

        guard let urls = try? fileManager.contentsOfDirectory(
            at: completedDirectory,
            includingPropertiesForKeys: nil
        ) else {
            return QuizAuditListResult(items: [], issues: [])
        }

        for url in urls where url.pathExtension == "json" {
            guard let fileID = UUID(uuidString: url.deletingPathExtension().lastPathComponent) else {
                issues.append(RecoveryIssue(kind: .identityMismatch, fileURL: url, message: "Invalid attempt filename."))
                continue
            }

            do {
                let attempt = try decodeAttempt(at: url, fileID: fileID)
                if predicate(attempt) {
                    summaries.append(CompletedAttemptSummary(attempt: attempt))
                }
            } catch let error as QuizAuditStoreError {
                issues.append(recoveryIssue(for: error, url: url))
            } catch {
                issues.append(RecoveryIssue(kind: .corruptFile, fileURL: url, message: error.localizedDescription))
            }
        }

        summaries.sort(by: Self.sortAttemptSummaries)
        return QuizAuditListResult(items: summaries, issues: issues)
    }

    private func shadowAttempt(for draft: QuizDraft) async throws -> CompletedQuizAttempt? {
        try await attempt(id: draft.id)
    }

    private func recoveryIssue(for error: QuizAuditStoreError, url: URL) -> RecoveryIssue {
        switch error {
        case .validation(.unsupportedSchema):
            return RecoveryIssue(kind: .unsupportedSchema, fileURL: url, message: error.localizedDescription ?? "Unsupported schema.")
        case .validation(.identityMismatch):
            return RecoveryIssue(kind: .identityMismatch, fileURL: url, message: error.localizedDescription ?? "Identity mismatch.")
        default:
            return RecoveryIssue(kind: .corruptFile, fileURL: url, message: error.localizedDescription ?? "Corrupt file.")
        }
    }

    private func ensureDirectories() throws {
        try fileManager.createDirectory(at: draftsDirectory, withIntermediateDirectories: true)
        try fileManager.createDirectory(at: completedDirectory, withIntermediateDirectories: true)
    }

    private func draftURL(for id: UUID) -> URL {
        draftsDirectory.appendingPathComponent("\(id.uuidString).json")
    }

    private func attemptURL(for id: UUID) -> URL {
        completedDirectory.appendingPathComponent("\(id.uuidString).json")
    }

    private func triggerFailpoint(_ failpoint: Failpoint) async {
        if failpoints.contains(failpoint) {
            failpoints.remove(failpoint)
        }
    }

    private static func sortSummaries(_ lhs: QuizDraftSummary, _ rhs: QuizDraftSummary) -> Bool {
        if lhs.updatedAt != rhs.updatedAt {
            return lhs.updatedAt > rhs.updatedAt
        }
        return lhs.id.uuidString < rhs.id.uuidString
    }

    private static func sortAttemptSummaries(_ lhs: CompletedAttemptSummary, _ rhs: CompletedAttemptSummary) -> Bool {
        if lhs.completedAt != rhs.completedAt {
            return lhs.completedAt > rhs.completedAt
        }
        return lhs.id.uuidString < rhs.id.uuidString
    }
}

private func semanticContentEquals(_ lhs: CompletedQuizAttempt, _ rhs: CompletedQuizAttempt) -> Bool {
    let encoder = JSONEncoder()
    encoder.dateEncodingStrategy = .iso8601
    encoder.outputFormatting = [.sortedKeys]
    guard let left = try? encoder.encode(lhs), let right = try? encoder.encode(rhs) else {
        return false
    }
    return left == right
}
