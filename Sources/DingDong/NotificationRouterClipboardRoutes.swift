import AppKit
import Foundation

extension NotificationRouter {
    func captureClipboard() -> HTTPResponse {
        guard let resourceStore, let clipboardRecorder else {
            return .json(statusCode: 503, reason: "Service Unavailable", object: [
                "status": "error",
                "message": "Clipboard capture is not available"
            ])
        }

        guard let item = clipboardRecorder.capture(source: "API") else {
            return .json(statusCode: 204, reason: "No Content", object: [
                "status": "empty",
                "message": "Clipboard has no text"
            ])
        }

        do {
            try ResourceLimits.validateContent(item.content, type: .clipboard)
        } catch ResourceLimitError.contentTooLarge(let maxCharacters) {
            return Self.contentTooLargeResponse(maxCharacters: maxCharacters)
        } catch {
            return .json(statusCode: 500, reason: "Internal Server Error", object: [
                "status": "error",
                "message": "Could not validate clipboard"
            ])
        }

        do {
            let existingClipboard = try resourceStore.list(type: .clipboard, query: nil, limit: nil)
            if existingClipboard.contains(where: { $0.content == item.content }) {
                return HTTPResponse.jsonObject([
                    "status": "duplicate",
                    "message": "Clipboard record already exists"
                ])
            }

            let stored = try resourceStore.add(item)
            return HTTPResponse.jsonObject(statusCode: 201, reason: "Created", [
                "status": "captured",
                "item": ResourceJSON.object(stored)
            ])
        } catch {
            return .json(statusCode: 500, reason: "Internal Server Error", object: [
                "status": "error",
                "message": "Could not save clipboard record"
            ])
        }
    }

    func clipboardOverview() -> HTTPResponse {
        guard let resourceStore else {
            return .json(statusCode: 503, reason: "Service Unavailable", object: [
                "status": "error",
                "message": "Resource library is not available"
            ])
        }

        do {
            let items = try resourceStore.list(type: .clipboard, query: nil, limit: nil)
            return HTTPResponse.jsonObject([
                "status": "ok",
                "service": "DingDong",
                "overview": ClipboardOverview(items: items).object
            ])
        } catch {
            return .json(statusCode: 500, reason: "Internal Server Error", object: [
                "status": "error",
                "message": "Could not read clipboard overview"
            ])
        }
    }

    func clipboardInsights(query: [String: String]) -> HTTPResponse {
        guard let resourceStore else {
            return .json(statusCode: 503, reason: "Service Unavailable", object: [
                "status": "error",
                "message": "Resource library is not available"
            ])
        }

        let includeSensitiveClipboard: Bool
        do {
            includeSensitiveClipboard = try Self.parseBoolQuery(query, key: "includeSensitiveClipboard") ?? false
        } catch {
            return .json(statusCode: 400, reason: "Bad Request", object: [
                "status": "error",
                "message": "includeSensitiveClipboard must be true or false"
            ])
        }

        do {
            let items = try resourceStore.list(type: .clipboard, query: nil, limit: nil)
            return HTTPResponse.jsonObject(ClipboardInsights.object(
                items: items,
                requestedLimit: query["limit"].flatMap(Int.init),
                includeSensitiveClipboard: includeSensitiveClipboard
            ))
        } catch {
            return .json(statusCode: 500, reason: "Internal Server Error", object: [
                "status": "error",
                "message": "Could not read clipboard insights"
            ])
        }
    }

    func clipboardDigest(query: [String: String]) -> HTTPResponse {
        guard let resourceStore else {
            return .json(statusCode: 503, reason: "Service Unavailable", object: [
                "status": "error",
                "message": "Resource library is not available"
            ])
        }

        guard let task = (query["q"] ?? query["task"])?.removingPercentEncoding?.trimmingCharacters(in: .whitespacesAndNewlines),
              !task.isEmpty else {
            return .json(statusCode: 400, reason: "Bad Request", object: [
                "status": "error",
                "message": "q or task is required"
            ])
        }

        let includeContent: Bool
        let includeSensitiveClipboard: Bool
        do {
            includeContent = try Self.parseBoolQuery(query, key: "includeContent") ?? false
            includeSensitiveClipboard = try Self.parseBoolQuery(query, key: "includeSensitiveClipboard") ?? false
        } catch {
            return .json(statusCode: 400, reason: "Bad Request", object: [
                "status": "error",
                "message": "includeContent and includeSensitiveClipboard must be true or false"
            ])
        }

        do {
            let items = try resourceStore.list(type: .clipboard, query: nil, limit: nil)
            return HTTPResponse.jsonObject(ClipboardDigest.object(
                items: items,
                task: task,
                requestedLimit: query["limit"].flatMap(Int.init),
                includeContent: includeContent,
                includeSensitiveClipboard: includeSensitiveClipboard
            ))
        } catch {
            return .json(statusCode: 500, reason: "Internal Server Error", object: [
                "status": "error",
                "message": "Could not read clipboard digest"
            ])
        }
    }

    func collectClipboard(_ body: Data) -> HTTPResponse {
        guard let resourceStore else {
            return .json(statusCode: 503, reason: "Service Unavailable", object: [
                "status": "error",
                "message": "Resource library is not available"
            ])
        }

        do {
            let request = try JSONDecoder().decode(ClipboardCollectionRequest.self, from: body)
            let clipboardItems = try resourceStore.list(type: .clipboard, query: nil, limit: nil)
            let collection = try ClipboardCollection.makeResource(from: request, clipboardItems: clipboardItems)
            try ResourceLimits.validateContent(collection.item.content, type: .knowledge)
            let stored = try resourceStore.add(collection.item)

            return HTTPResponse.jsonObject(statusCode: 201, reason: "Created", [
                "status": "created",
                "item": ResourceJSON.object(stored),
                "included": collection.included.map(ResourceJSON.object),
                "privacy": [
                    "sensitiveClipboardIncluded": request.includeSensitiveClipboard ?? false,
                    "hiddenSensitiveItems": collection.hiddenSensitive,
                    "default": "clipboard collections exclude sensitive clipboard records unless includeSensitiveClipboard=true"
                ],
                "next": [
                    "find": "GET /library?type=knowledge&q=\(Self.encodedQuery(stored.title))",
                    "context": "GET /agent/context?q=\(Self.encodedQuery(stored.title))&limit=10"
                ]
            ])
        } catch ClipboardCollectionError.missingTitle {
            return .json(statusCode: 400, reason: "Bad Request", object: [
                "status": "error",
                "message": "title is required"
            ])
        } catch ClipboardCollectionError.missingSelection {
            return .json(statusCode: 400, reason: "Bad Request", object: [
                "status": "error",
                "message": "task, q, or ids is required"
            ])
        } catch ClipboardCollectionError.noMatches {
            return .json(statusCode: 404, reason: "Not Found", object: [
                "status": "error",
                "message": "No matching clipboard records"
            ])
        } catch ResourceLimitError.contentTooLarge(let maxCharacters) {
            return Self.contentTooLargeResponse(maxCharacters: maxCharacters)
        } catch {
            return .json(statusCode: 400, reason: "Bad Request", object: [
                "status": "error",
                "message": "Invalid clipboard collection JSON body"
            ])
        }
    }

    func clipboardHistory(query: [String: String]) -> HTTPResponse {
        guard let resourceStore else {
            return .json(statusCode: 503, reason: "Service Unavailable", object: [
                "status": "error",
                "message": "Resource library is not available"
            ])
        }

        let includeContent: Bool
        let includeSensitiveClipboard: Bool
        do {
            includeContent = try Self.parseBoolQuery(query, key: "includeContent") ?? false
            includeSensitiveClipboard = try Self.parseBoolQuery(query, key: "includeSensitiveClipboard") ?? false
        } catch {
            return .json(statusCode: 400, reason: "Bad Request", object: [
                "status": "error",
                "message": "includeContent and includeSensitiveClipboard must be true or false"
            ])
        }

        let filter = query["filter"]?
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .lowercased()
            .nilIfEmpty
        let selectedFilter = filter.flatMap(ClipboardSmartFilter.init(rawValue:)) ?? .all
        if filter != nil, ClipboardSmartFilter(rawValue: filter!) == nil {
            return .json(statusCode: 400, reason: "Bad Request", object: [
                "status": "error",
                "message": "filter must be one of all, url, command, code, json, path, image, file, email, or sensitive"
            ])
        }

        let group = query["group"]?.trimmingCharacters(in: .whitespacesAndNewlines).nilIfEmpty
        let requestedLimit = query["limit"].flatMap(Int.init) ?? 20
        let limit = min(max(requestedLimit, 0), 50)

        do {
            var items = try resourceStore.list(type: .clipboard, query: query["q"], limit: nil)

            if let group {
                items = items.filter { $0.group.localizedCaseInsensitiveCompare(group) == .orderedSame }
            }

            if let tagQuery = selectedFilter.tagQuery {
                items = items.filter { $0.tags.contains(tagQuery) }
            }

            let hiddenSensitiveCount = includeSensitiveClipboard ? 0 : items.filter(\.isSensitiveClipboard).count
            let visibleItems = includeSensitiveClipboard ? items : items.filter { !$0.isSensitiveClipboard }
            let returnedItems = Array(visibleItems.prefix(limit))

            return HTTPResponse.jsonObject([
                "status": "ok",
                "filter": [
                    "q": query["q"] ?? "",
                    "group": group ?? "all",
                    "filter": selectedFilter.rawValue,
                    "limit": limit,
                    "includeContent": includeContent,
                    "includeSensitiveClipboard": includeSensitiveClipboard
                ],
                "counts": [
                    "matched": items.count,
                    "visible": visibleItems.count,
                    "returned": returnedItems.count,
                    "hiddenSensitive": hiddenSensitiveCount
                ],
                "privacy": [
                    "contentIncluded": includeContent,
                    "sensitiveClipboardIncluded": includeSensitiveClipboard,
                    "default": "clipboard history returns metadata only; pass includeContent=true to read content",
                    "sensitiveDefault": "sensitive clipboard records are hidden unless includeSensitiveClipboard=true"
                ],
                "items": returnedItems.map {
                    ClipboardHistoryJSON.object($0, includeContent: includeContent)
                }
            ])
        } catch {
            return .json(statusCode: 500, reason: "Internal Server Error", object: [
                "status": "error",
                "message": "Could not read clipboard history"
            ])
        }
    }

    func clipboardSnippets(query: [String: String]) -> HTTPResponse {
        guard let resourceStore else {
            return .json(statusCode: 503, reason: "Service Unavailable", object: [
                "status": "error",
                "message": "Resource library is not available"
            ])
        }

        let includeContent: Bool
        let includeSensitiveClipboard: Bool
        do {
            includeContent = try Self.parseBoolQuery(query, key: "includeContent") ?? false
            includeSensitiveClipboard = try Self.parseBoolQuery(query, key: "includeSensitiveClipboard") ?? false
        } catch {
            return .json(statusCode: 400, reason: "Bad Request", object: [
                "status": "error",
                "message": "includeContent and includeSensitiveClipboard must be true or false"
            ])
        }

        let alias = query["alias"].flatMap(Self.normalizedClipboardAlias)
        if query["alias"] != nil, alias == nil {
            return .json(statusCode: 400, reason: "Bad Request", object: [
                "status": "error",
                "message": "alias cannot be empty"
            ])
        }

        let requestedLimit = query["limit"].flatMap(Int.init) ?? 20
        let limit = min(max(requestedLimit, 0), 50)

        do {
            let allItems = try resourceStore.list(type: .clipboard, query: query["q"], limit: nil)
            let snippetItems = allItems.filter { !Self.clipboardAliases(for: $0).isEmpty }
            let aliasItems = alias.map { selectedAlias in
                snippetItems.filter { Self.clipboardAliases(for: $0).contains(selectedAlias) }
            } ?? snippetItems
            let hiddenSensitiveCount = includeSensitiveClipboard ? 0 : aliasItems.filter(\.isSensitiveClipboard).count
            let visibleItems = includeSensitiveClipboard ? aliasItems : aliasItems.filter { !$0.isSensitiveClipboard }
            let returnedItems = Array(visibleItems.prefix(limit))

            return HTTPResponse.jsonObject([
                "status": "ok",
                "filter": [
                    "alias": alias ?? "all",
                    "q": query["q"] ?? "",
                    "limit": limit,
                    "includeContent": includeContent,
                    "includeSensitiveClipboard": includeSensitiveClipboard
                ],
                "counts": [
                    "snippetRecords": snippetItems.count,
                    "matched": aliasItems.count,
                    "visible": visibleItems.count,
                    "returned": returnedItems.count,
                    "hiddenSensitive": hiddenSensitiveCount
                ],
                "aliases": Self.clipboardAliasSummaries(from: visibleItems),
                "privacy": [
                    "contentIncluded": includeContent,
                    "sensitiveClipboardIncluded": includeSensitiveClipboard,
                    "default": "clipboard snippets return metadata only; pass includeContent=true to read content",
                    "sensitiveDefault": "sensitive clipboard snippets are hidden unless includeSensitiveClipboard=true"
                ],
                "items": returnedItems.map {
                    ClipboardHistoryJSON.object($0, includeContent: includeContent, aliases: Self.clipboardAliases(for: $0))
                }
            ])
        } catch {
            return .json(statusCode: 500, reason: "Internal Server Error", object: [
                "status": "error",
                "message": "Could not read clipboard snippets"
            ])
        }
    }

    func clipboardGroups() -> HTTPResponse {
        guard let resourceStore else {
            return .json(statusCode: 503, reason: "Service Unavailable", object: [
                "status": "error",
                "message": "Resource library is not available"
            ])
        }

        do {
            let items = try resourceStore.list(type: .clipboard, query: nil, limit: nil)
            return HTTPResponse.jsonObject([
                "status": "ok",
                "groups": LibraryGroupSummary.summaries(from: items).map(ResourceGroupJSON.object),
                "overview": ClipboardOverview(items: items).object
            ])
        } catch {
            return .json(statusCode: 500, reason: "Internal Server Error", object: [
                "status": "error",
                "message": "Could not read clipboard groups"
            ])
        }
    }

    func updateClipboard(path: String, body: Data) -> HTTPResponse {
        guard let resourceStore else {
            return .json(statusCode: 503, reason: "Service Unavailable", object: [
                "status": "error",
                "message": "Resource library is not available"
            ])
        }

        guard let id = clipboardRecordID(from: path) else {
            return .json(statusCode: 400, reason: "Bad Request", object: [
                "status": "error",
                "message": "Invalid clipboard id"
            ])
        }

        do {
            let request = try JSONDecoder().decode(ResourceUpdateRequest.self, from: body)
            guard request.title != nil || request.group != nil || request.tags != nil || request.pinned != nil else {
                return .json(statusCode: 400, reason: "Bad Request", object: [
                    "status": "error",
                    "message": "title, group, tags, or pinned is required"
                ])
            }

            guard request.type == nil, request.content == nil, request.source == nil else {
                return .json(statusCode: 400, reason: "Bad Request", object: [
                    "status": "error",
                    "message": "clipboard patch cannot change type, content, or source"
                ])
            }

            if let title = request.title, title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                return .json(statusCode: 400, reason: "Bad Request", object: [
                    "status": "error",
                    "message": "title cannot be empty"
                ])
            }

            let clipboardItems = try resourceStore.list(type: .clipboard, query: nil, limit: nil)
            guard let existingItem = clipboardItems.first(where: { $0.id == id }) else {
                return .json(statusCode: 404, reason: "Not Found", object: [
                    "status": "error",
                    "message": "Clipboard record not found"
                ])
            }

            let changes = Self.clipboardOrganizationChanges(request, existingItem: existingItem)
            guard let item = try resourceStore.update(id: id, changes: changes) else {
                return .json(statusCode: 404, reason: "Not Found", object: [
                    "status": "error",
                    "message": "Clipboard record not found"
                ])
            }

            return HTTPResponse.jsonObject([
                "status": "updated",
                "item": ClipboardHistoryJSON.object(item, includeContent: false)
            ])
        } catch {
            return .json(statusCode: 400, reason: "Bad Request", object: [
                "status": "error",
                "message": "Invalid clipboard patch JSON body"
            ])
        }
    }

    static func clipboardOrganizationChanges(_ request: ResourceUpdateRequest, existingItem: ResourceItem) -> ResourceUpdateRequest {
        guard let tags = request.tags else {
            return request
        }

        let mergedTags = uniqueTags(existingItem.tags + tags)
        return ResourceUpdateRequest(
            group: request.group,
            title: request.title,
            tags: mergedTags,
            pinned: request.pinned
        )
    }

    static func uniqueTags(_ tags: [String]) -> [String] {
        var seen = Set<String>()
        var result: [String] = []
        for tag in tags {
            let trimmed = tag.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !trimmed.isEmpty else {
                continue
            }

            let key = trimmed.lowercased()
            guard !seen.contains(key) else {
                continue
            }

            seen.insert(key)
            result.append(trimmed)
        }
        return result
    }

    static func clipboardAliases(for item: ResourceItem) -> [String] {
        let aliases = item.tags.compactMap { tag -> String? in
            let trimmed = tag.trimmingCharacters(in: .whitespacesAndNewlines)
            guard trimmed.lowercased().hasPrefix("alias:") else {
                return nil
            }

            return normalizedClipboardAlias(String(trimmed.dropFirst("alias:".count)))
        }

        return uniqueTags(aliases).map { $0.lowercased() }
    }

    static func normalizedClipboardAlias(_ value: String) -> String? {
        let trimmed = value
            .removingPercentEncoding?
            .trimmingCharacters(in: .whitespacesAndNewlines) ?? value.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else {
            return nil
        }

        return trimmed.lowercased()
    }

    static func clipboardAliasSummaries(from items: [ResourceItem]) -> [[String: Any]] {
        var buckets: [String: [ResourceItem]] = [:]
        for item in items {
            for alias in clipboardAliases(for: item) {
                buckets[alias, default: []].append(item)
            }
        }

        return buckets
            .map { alias, items in
                [
                    "alias": alias,
                    "count": items.count,
                    "pinnedCount": items.filter(\.pinned).count,
                    "latestUpdatedAt": isoTimestamp(items.map(\.updatedAt).max() ?? Date(timeIntervalSince1970: 0))
                ] as [String: Any]
            }
            .sorted { lhs, rhs in
                (lhs["alias"] as? String ?? "") < (rhs["alias"] as? String ?? "")
            }
    }

    static func isoTimestamp(_ date: Date) -> String {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        return formatter.string(from: date)
    }

    func promoteClipboard(path: String, body: Data) -> HTTPResponse {
        guard let resourceStore else {
            return .json(statusCode: 503, reason: "Service Unavailable", object: [
                "status": "error",
                "message": "Resource library is not available"
            ])
        }

        guard let id = clipboardID(from: path) else {
            return .json(statusCode: 400, reason: "Bad Request", object: [
                "status": "error",
                "message": "Invalid clipboard id"
            ])
        }

        do {
            let clipboardItems = try resourceStore.list(type: .clipboard, query: nil, limit: nil)
            guard let clipboardItem = clipboardItems.first(where: { $0.id == id }) else {
                return .json(statusCode: 404, reason: "Not Found", object: [
                    "status": "error",
                    "message": "Clipboard record not found"
                ])
            }

            let request = try Self.parsePromotionRequest(body)
            let promoted = try request.makeResource(from: clipboardItem)
            let stored = try resourceStore.add(promoted)

            return HTTPResponse.jsonObject(statusCode: 201, reason: "Created", [
                "status": "promoted",
                "sourceID": clipboardItem.id.uuidString,
                "item": ResourceJSON.object(stored)
            ])
        } catch ClipboardPromotionError.invalidTargetType {
            return .json(statusCode: 400, reason: "Bad Request", object: [
                "status": "error",
                "message": "targetType cannot be clipboard"
            ])
        } catch {
            return .json(statusCode: 400, reason: "Bad Request", object: [
                "status": "error",
                "message": "Invalid promotion JSON body"
            ])
        }
    }

    func restoreClipboard(path: String) -> HTTPResponse {
        guard let resourceStore else {
            return .json(statusCode: 503, reason: "Service Unavailable", object: [
                "status": "error",
                "message": "Resource library is not available"
            ])
        }

        guard let id = clipboardRestoreID(from: path) else {
            return .json(statusCode: 400, reason: "Bad Request", object: [
                "status": "error",
                "message": "Invalid clipboard id"
            ])
        }

        do {
            let clipboardItems = try resourceStore.list(type: .clipboard, query: nil, limit: nil)
            guard let clipboardItem = clipboardItems.first(where: { $0.id == id }) else {
                return .json(statusCode: 404, reason: "Not Found", object: [
                    "status": "error",
                    "message": "Clipboard record not found"
                ])
            }

            guard writePasteboard(clipboardItem.content) else {
                return .json(statusCode: 500, reason: "Internal Server Error", object: [
                    "status": "error",
                    "message": "Could not restore clipboard"
                ])
            }

            return HTTPResponse.jsonObject([
                "status": "restored",
                "id": clipboardItem.id.uuidString,
                "title": clipboardItem.title,
                "contentCharacterCount": clipboardItem.content.count
            ])
        } catch {
            return .json(statusCode: 500, reason: "Internal Server Error", object: [
                "status": "error",
                "message": "Could not read clipboard record"
            ])
        }
    }

    func restoreClipboardSnippet(path: String, query: [String: String]) -> HTTPResponse {
        guard let resourceStore else {
            return .json(statusCode: 503, reason: "Service Unavailable", object: [
                "status": "error",
                "message": "Resource library is not available"
            ])
        }

        guard let alias = clipboardSnippetAlias(from: path) else {
            return .json(statusCode: 400, reason: "Bad Request", object: [
                "status": "error",
                "message": "Invalid clipboard snippet alias"
            ])
        }

        let includeSensitiveClipboard: Bool
        do {
            includeSensitiveClipboard = try Self.parseBoolQuery(query, key: "includeSensitiveClipboard") ?? false
        } catch {
            return .json(statusCode: 400, reason: "Bad Request", object: [
                "status": "error",
                "message": "includeSensitiveClipboard must be true or false"
            ])
        }

        do {
            let clipboardItems = try resourceStore.list(type: .clipboard, query: nil, limit: nil)
            let matches = clipboardItems
                .filter { Self.clipboardAliases(for: $0).contains(alias) }
                .filter { includeSensitiveClipboard || !$0.isSensitiveClipboard }
                .sorted { lhs, rhs in
                    if lhs.pinned != rhs.pinned {
                        return lhs.pinned && !rhs.pinned
                    }

                    return lhs.updatedAt > rhs.updatedAt
                }

            guard let item = matches.first else {
                return .json(statusCode: 404, reason: "Not Found", object: [
                    "status": "error",
                    "message": "Clipboard snippet not found"
                ])
            }

            guard writePasteboard(item.content) else {
                return .json(statusCode: 500, reason: "Internal Server Error", object: [
                    "status": "error",
                    "message": "Could not restore clipboard snippet"
                ])
            }

            return HTTPResponse.jsonObject([
                "status": "restored",
                "alias": alias,
                "id": item.id.uuidString,
                "title": item.title,
                "contentCharacterCount": item.content.count
            ])
        } catch {
            return .json(statusCode: 500, reason: "Internal Server Error", object: [
                "status": "error",
                "message": "Could not read clipboard snippet"
            ])
        }
    }

    func setClipboardMonitoring(enabledValue: String?, body: Data) -> HTTPResponse {
        let enabled = enabledValue.flatMap(Self.parseBool) ?? Self.parseMonitorBody(body)
        guard let enabled else {
            return .json(statusCode: 400, reason: "Bad Request", object: [
                "status": "error",
                "message": "enabled must be true or false"
            ])
        }

        handleClipboardMonitoring?(enabled)
        return .json(object: [
            "status": enabled ? "enabled" : "disabled",
            "feature": "clipboard-monitor"
        ])
    }


}

private extension String {
    var nilIfEmpty: String? {
        isEmpty ? nil : self
    }
}
