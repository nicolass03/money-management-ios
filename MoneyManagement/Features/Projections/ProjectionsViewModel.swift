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

  private var loadGeneration = LoadGeneration()

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

  func load(force: Bool = false) async {
    let token = loadGeneration.next()
    isLoading = true
    errorMessage = nil
    needsPrimarySchedule = false
    defer {
      if loadGeneration.isCurrent(token) {
        isLoading = false
      }
    }

    do {
      if force {
        deps.invalidateAll()
      }

      try await deps.refreshSharedContext()
      guard loadGeneration.isCurrent(token) else { return }
      guard let settings = deps.settings else {
        throw APIError(status: 0, message: "Settings unavailable")
      }
      guard settings.primaryScheduleId != nil else {
        needsPrimarySchedule = true
        response = nil
        return
      }
      response = try await deps.dataStore.getProjections { [deps] in
        try await deps.api.getProjections()
      }
    } catch let error as APIError where error.status == 400 {
      guard loadGeneration.isCurrent(token) else { return }
      needsPrimarySchedule = true
      response = nil
    } catch {
      guard shouldSurfaceLoadError(error, isCurrent: loadGeneration.isCurrent(token)) else { return }
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
