import AppKit
import Foundation

extension NotificationRouter {
    func showUI(query: [String: String]) -> HTTPResponse {
        let tab = query["tab"]?
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .lowercased()
            .nilIfEmpty

        let selectedTab = tab.flatMap(CompanionTab.init(apiValue:))
        if tab != nil, selectedTab == nil {
            return .json(statusCode: 400, reason: "Bad Request", object: [
                "status": "error",
                "message": "tab must be today, library, clipboard, or api"
            ])
        }

        handleShowPanel?(selectedTab)
        return HTTPResponse.jsonObject([
            "status": "shown",
            "tab": selectedTab?.apiValue ?? "current"
        ])
    }


    func listEvents(limit: Int?) -> HTTPResponse {
        guard let agentEventStore else {
            return .json(statusCode: 503, reason: "Service Unavailable", object: [
                "status": "error",
                "message": "Agent events are not available"
            ])
        }

        return HTTPResponse.jsonObject([
            "status": "ok",
            "events": agentEventStore.list(limit: limit).map(AgentEventJSON.object)
        ])
    }


}

private extension String {
    var nilIfEmpty: String? {
        isEmpty ? nil : self
    }
}
