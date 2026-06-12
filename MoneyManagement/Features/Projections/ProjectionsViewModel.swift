import Foundation
import Observation

@Observable
@MainActor
final class ProjectionsViewModel {
  private let deps: AppDependencies

  var response: ProjectionsResponse?
  var expandedPayDates: Set<String> = []
  var isLoading = false
  var errorMessage: String?
  var needsPrimarySchedule = false

  init(deps: AppDependencies) {
    self.deps = deps
  }

  var latestCumulativeFree: Int? {
    guard let rows = response?.rows else { return nil }
    return ProjectionDisplayLogic.visibleRows(from: rows).last?.cumulativeFree
      ?? rows.last?.cumulativeFree
  }

  var displayRows: [ProjectionRow] {
    guard let rows = response?.rows else { return [] }
    return ProjectionDisplayLogic.visibleRows(from: rows)
  }

  func load() async {
    isLoading = true
    errorMessage = nil
    needsPrimarySchedule = false
    defer { isLoading = false }

    do {
      try await deps.refreshSharedContext()
      guard deps.settings?.primaryScheduleId != nil else {
        needsPrimarySchedule = true
        response = nil
        return
      }
      response = try await deps.api.getProjections()
    } catch let error as APIError where error.status == 400 {
      needsPrimarySchedule = true
      errorMessage = error.message
    } catch {
      errorMessage = error.localizedDescription
    }
  }

  func toggleExpanded(_ row: ProjectionRow) {
    if expandedPayDates.contains(row.payDate) {
      expandedPayDates.remove(row.payDate)
    } else {
      expandedPayDates.insert(row.payDate)
    }
  }
}
