import AppKit
import Foundation

extension NotificationRouter {
    func listResources(typeName: String?, query: String?, limit: Int?) -> HTTPResponse {
        guard let resourceStore else {
            return .json(statusCode: 503, reason: "Service Unavailable", object: [
                "status": "error",
                "message": "Resource library is not available"
            ])
        }

        let type = typeName.flatMap(ResourceType.init(rawValue:))
        if typeName != nil, type == nil {
            return .json(statusCode: 400, reason: "Bad Request", object: [
                "status": "error",
                "message": "Invalid resource type"
            ])
        }

        do {
            let items = try resourceStore.list(type: type, query: query, limit: limit)
            return HTTPResponse.jsonObject([
                "status": "ok",
                "items": items.map(ResourceJSON.object)
            ])
        } catch {
            return .json(statusCode: 500, reason: "Internal Server Error", object: [
                "status": "error",
                "message": "Could not read resource library"
            ])
        }
    }


    func listResourceGroups(typeName: String?) -> HTTPResponse {
        guard let resourceStore else {
            return .json(statusCode: 503, reason: "Service Unavailable", object: [
                "status": "error",
                "message": "Resource library is not available"
            ])
        }

        let type = typeName.flatMap(ResourceType.init(rawValue:))
        if typeName != nil, type == nil {
            return .json(statusCode: 400, reason: "Bad Request", object: [
                "status": "error",
                "message": "Invalid resource type"
            ])
        }

        do {
            let items = try resourceStore.list(type: type, query: nil, limit: nil)
            return HTTPResponse.jsonObject([
                "status": "ok",
                "groups": LibraryGroupSummary.summaries(from: items).map(ResourceGroupJSON.object)
            ])
        } catch {
            return .json(statusCode: 500, reason: "Internal Server Error", object: [
                "status": "error",
                "message": "Could not read resource groups"
            ])
        }
    }

    func exportResources(query: [String: String]) -> HTTPResponse {
        guard let resourceStore else {
            return .json(statusCode: 503, reason: "Service Unavailable", object: [
                "status": "error",
                "message": "Resource library is not available"
            ])
        }

        let type = query["type"].flatMap(ResourceType.init(rawValue:))
        if query["type"] != nil, type == nil {
            return .json(statusCode: 400, reason: "Bad Request", object: [
                "status": "error",
                "message": "Invalid resource type"
            ])
        }

        let clipboardVisibility: AgentClipboardVisibility
        do {
            clipboardVisibility = try Self.parseClipboardVisibility(query)
        } catch {
            return Self.invalidClipboardVisibilityResponse()
        }

        do {
            let resources = try resourceStore.list(type: type, query: query["q"], limit: nil)
            return HTTPResponse.jsonObject(LibraryExport.object(
                resources: resources,
                type: type,
                query: query["q"],
                requestedLimit: query["limit"].flatMap(Int.init),
                clipboardVisibility: clipboardVisibility
            ))
        } catch {
            return .json(statusCode: 500, reason: "Internal Server Error", object: [
                "status": "error",
                "message": "Could not export resource library"
            ])
        }
    }


    func addResource(_ body: Data) -> HTTPResponse {
        guard let resourceStore else {
            return .json(statusCode: 503, reason: "Service Unavailable", object: [
                "status": "error",
                "message": "Resource library is not available"
            ])
        }

        do {
            let request = try JSONDecoder().decode(ResourceCreateRequest.self, from: body)
            guard !request.title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty,
                  !request.content.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
                return .json(statusCode: 400, reason: "Bad Request", object: [
                    "status": "error",
                    "message": "title and content are required"
                ])
            }

            try ResourceLimits.validateContent(request.content, type: request.type)
            let item = try resourceStore.add(request.makeItem())
            return HTTPResponse.jsonObject(statusCode: 201, reason: "Created", [
                "status": "created",
                "item": ResourceJSON.object(item)
            ])
        } catch ResourceLimitError.contentTooLarge(let maxCharacters) {
            return Self.contentTooLargeResponse(maxCharacters: maxCharacters)
        } catch {
            return .json(statusCode: 400, reason: "Bad Request", object: [
                "status": "error",
                "message": "Invalid resource JSON body"
            ])
        }
    }

    func importResources(_ body: Data) -> HTTPResponse {
        guard let resourceStore else {
            return .json(statusCode: 503, reason: "Service Unavailable", object: [
                "status": "error",
                "message": "Resource library is not available"
            ])
        }

        do {
            let request = try JSONDecoder().decode(LibraryImportRequest.self, from: body)
            guard request.type != .clipboard else {
                return .json(statusCode: 400, reason: "Bad Request", object: [
                    "status": "error",
                    "message": "clipboard resources cannot be bulk imported"
                ])
            }

            guard !request.path.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
                return .json(statusCode: 400, reason: "Bad Request", object: [
                    "status": "error",
                    "message": "path is required"
                ])
            }

            let existing = try resourceStore.list(type: request.type, query: nil, limit: nil)
            let result = try libraryImporter.candidates(from: request, existing: existing)
            let stored = try result.imported.map { try resourceStore.add($0) }

            return HTTPResponse.jsonObject([
                "status": "imported",
                "importedCount": stored.count,
                "skippedCount": result.skippedCount,
                "scannedCount": result.scannedCount,
                "items": stored.map(ResourceJSON.object)
            ])
        } catch LibraryImportError.missingDirectory {
            return .json(statusCode: 400, reason: "Bad Request", object: [
                "status": "error",
                "message": "Import path is not a directory"
            ])
        } catch {
            return .json(statusCode: 400, reason: "Bad Request", object: [
                "status": "error",
                "message": "Invalid import JSON body"
            ])
        }
    }

    func updateResource(path: String, body: Data) -> HTTPResponse {
        guard let resourceStore else {
            return .json(statusCode: 503, reason: "Service Unavailable", object: [
                "status": "error",
                "message": "Resource library is not available"
            ])
        }

        guard let id = resourceID(from: path) else {
            return .json(statusCode: 400, reason: "Bad Request", object: [
                "status": "error",
                "message": "Invalid resource id"
            ])
        }

        do {
            let request = try JSONDecoder().decode(ResourceUpdateRequest.self, from: body)
            guard request.hasChanges else {
                return .json(statusCode: 400, reason: "Bad Request", object: [
                    "status": "error",
                    "message": "At least one resource field is required"
                ])
            }

            if let title = request.title, title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                return .json(statusCode: 400, reason: "Bad Request", object: [
                    "status": "error",
                    "message": "title cannot be empty"
                ])
            }

            if let content = request.content, content.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                return .json(statusCode: 400, reason: "Bad Request", object: [
                    "status": "error",
                    "message": "content cannot be empty"
                ])
            }

            let existingItem = try resourceStore.list(type: nil, query: nil, limit: nil).first { $0.id == id }
            guard let existingItem else {
                return .json(statusCode: 404, reason: "Not Found", object: [
                    "status": "error",
                    "message": "Resource not found"
                ])
            }

            if let content = request.content {
                try ResourceLimits.validateContent(content, type: request.type ?? existingItem.type)
            }

            guard let item = try resourceStore.update(id: id, changes: request) else {
                return .json(statusCode: 404, reason: "Not Found", object: [
                    "status": "error",
                    "message": "Resource not found"
                ])
            }

            return HTTPResponse.jsonObject([
                "status": "updated",
                "item": ResourceJSON.object(item)
            ])
        } catch ResourceLimitError.contentTooLarge(let maxCharacters) {
            return Self.contentTooLargeResponse(maxCharacters: maxCharacters)
        } catch {
            return .json(statusCode: 400, reason: "Bad Request", object: [
                "status": "error",
                "message": "Invalid resource JSON body"
            ])
        }
    }

    func deleteResource(path: String) -> HTTPResponse {
        guard let resourceStore else {
            return .json(statusCode: 503, reason: "Service Unavailable", object: [
                "status": "error",
                "message": "Resource library is not available"
            ])
        }

        guard let id = resourceID(from: path) else {
            return .json(statusCode: 400, reason: "Bad Request", object: [
                "status": "error",
                "message": "Invalid resource id"
            ])
        }

        do {
            guard try resourceStore.delete(id: id) else {
                return .json(statusCode: 404, reason: "Not Found", object: [
                    "status": "error",
                    "message": "Resource not found"
                ])
            }

            return .json(object: [
                "status": "deleted",
                "id": id.uuidString
            ])
        } catch {
            return .json(statusCode: 500, reason: "Internal Server Error", object: [
                "status": "error",
                "message": "Could not delete resource"
            ])
        }
    }

    func seedDefaultResources() -> HTTPResponse {
        guard let resourceStore else {
            return .json(statusCode: 503, reason: "Service Unavailable", object: [
                "status": "error",
                "message": "Resource library is not available"
            ])
        }

        do {
            let result = try DefaultResourceSeeds.install(into: resourceStore, onlyIfEmpty: false)
            return HTTPResponse.jsonObject([
                "status": "seeded",
                "defaults": result.object
            ])
        } catch {
            return .json(statusCode: 500, reason: "Internal Server Error", object: [
                "status": "error",
                "message": "Could not seed default resources"
            ])
        }
    }

    func indexKnowledge(idValue: String?, pathValue: String?, limitValue: String?) -> HTTPResponse {
        do {
            let rootPath = try knowledgeRootPath(idValue: idValue, pathValue: pathValue)
            let result = try knowledgeIndexer.index(rootPath: rootPath, maxFiles: limitValue.flatMap(Int.init) ?? KnowledgeIndexer.defaultMaxFiles)
            return HTTPResponse.jsonObject([
                "status": "ok",
                "root": result.root,
                "scannedCount": result.scannedCount,
                "skippedCount": result.skippedCount,
                "truncated": result.truncated,
                "files": result.files.map(KnowledgeIndexJSON.object)
            ])
        } catch KnowledgeIndexRouteError.missingInput {
            return .json(statusCode: 400, reason: "Bad Request", object: [
                "status": "error",
                "message": "id or path is required"
            ])
        } catch KnowledgeIndexRouteError.invalidID {
            return .json(statusCode: 400, reason: "Bad Request", object: [
                "status": "error",
                "message": "Invalid knowledge resource id"
            ])
        } catch KnowledgeIndexRouteError.notFound {
            return .json(statusCode: 404, reason: "Not Found", object: [
                "status": "error",
                "message": "Knowledge resource not found"
            ])
        } catch KnowledgeIndexRouteError.notKnowledge {
            return .json(statusCode: 400, reason: "Bad Request", object: [
                "status": "error",
                "message": "Resource is not a knowledge item"
            ])
        } catch KnowledgeIndexError.missingDirectory {
            return .json(statusCode: 400, reason: "Bad Request", object: [
                "status": "error",
                "message": "Knowledge path is not a directory"
            ])
        } catch {
            return .json(statusCode: 500, reason: "Internal Server Error", object: [
                "status": "error",
                "message": "Could not index knowledge path"
            ])
        }
    }

    func knowledgeRootPath(idValue: String?, pathValue: String?) throws -> String {
        if let path = pathValue?.removingPercentEncoding?.trimmingCharacters(in: .whitespacesAndNewlines), !path.isEmpty {
            return path
        }

        guard let idValue, !idValue.isEmpty else {
            throw KnowledgeIndexRouteError.missingInput
        }

        guard let id = UUID(uuidString: idValue), let resourceStore else {
            throw KnowledgeIndexRouteError.invalidID
        }

        let items = try resourceStore.list(type: .knowledge, query: nil, limit: nil)
        guard let item = items.first(where: { $0.id == id }) else {
            let allItems = try resourceStore.list(type: nil, query: nil, limit: nil)
            if allItems.contains(where: { $0.id == id }) {
                throw KnowledgeIndexRouteError.notKnowledge
            }
            throw KnowledgeIndexRouteError.notFound
        }

        return item.content
    }


}

private extension String {
    var nilIfEmpty: String? {
        isEmpty ? nil : self
    }
}
