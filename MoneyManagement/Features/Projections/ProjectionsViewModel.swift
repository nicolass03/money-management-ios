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
    // Paint the last-known projections immediately; only show the skeleton when nothing is cached.
    if response == nil { response = deps.dataStore.projections }
    isLoading = (response == nil)
    errorMessage = nil
    needsPrimarySchedule = false
    defer {
      if loadGeneration.isCurrent(token) {
        isLoading = false
      }
    }

    if force {
      deps.invalidateAll()
    }

    do {
      // Fetch shared context and projections together. The API returns 400 when no primary schedule
      // is set (handled below and resolved cheaply server-side before any heavy work), so we don't
      // need settings to resolve before issuing the projections request — running them in parallel
      // removes a round-trip from the skeleton time on the heaviest tab.
      async let contextTask: Void = loadSharedContext(loadToken: token)
      let projections = try await deps.dataStore.getProjections { [deps] in
        try await deps.api.getProjections()
      }
      await contextTask
      guard loadGeneration.isCurrent(token) else { return }
      response = projections
    } catch let error as APIError where error.status == 400 {
      guard loadGeneration.isCurrent(token) else { return }
      needsPrimarySchedule = true
      response = nil
    } catch {
      guard shouldSurfaceLoadError(error, isCurrent: loadGeneration.isCurrent(token)) else { return }
      errorMessage = error.localizedDescription
    }
  }

  private func loadSharedContext(loadToken: Int) async {
    do {
      try await deps.refreshSharedContext()
    } catch {
      guard shouldSurfaceLoadError(error, isCurrent: loadGeneration.isCurrent(loadToken)) else { return }
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
