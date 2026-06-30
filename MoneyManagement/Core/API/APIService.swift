import Foundation

struct APIService {
    let client: APIClient

    // MARK: - Settings

    func getSettings() async throws -> UserSettings {
        try await client.request("GET", path: "settings")
    }

    func patchSettings(_ body: PatchSettingsRequest) async throws -> UserSettings {
        try await client.request("PATCH", path: "settings", body: body)
    }

    // MARK: - Money context

    func getMoneyContext(forceRefresh: Bool = false) async throws -> MoneyContextResponse {
        var query: [URLQueryItem] = []
        if forceRefresh {
            query.append(URLQueryItem(name: "forceRefresh", value: "true"))
        }
        return try await client.request("GET", path: "money-context", query: query)
    }

    // MARK: - Tags

    func getTags() async throws -> [String] {
        try await client.request("GET", path: "tags")
    }

    // MARK: - Accounts

    func getAccounts() async throws -> [Account] {
        try await client.request("GET", path: "accounts")
    }

    func createAccount(_ body: CreateAccountRequest) async throws -> Account {
        try await client.request("POST", path: "accounts", body: body)
    }

    func updateAccount(id: String, _ body: CreateAccountRequest) async throws -> Account {
        try await client.request("PATCH", path: "accounts/\(id)", body: body)
    }

    func deleteAccount(id: String) async throws {
        let _: SuccessResponse = try await client.request("DELETE", path: "accounts/\(id)")
    }

    // MARK: - Income schedules

    func getIncomeSchedules() async throws -> [IncomePaySchedule] {
        try await client.request("GET", path: "income-schedules")
    }

    func getIncomeSchedule(id: String) async throws -> IncomePaySchedule {
        try await client.request("GET", path: "income-schedules/\(id)")
    }

    func createIncomeSchedule(_ body: CreateIncomeScheduleRequest) async throws -> IncomePaySchedule {
        try await client.request("POST", path: "income-schedules", body: body)
    }

    func updateIncomeSchedule(id: String, _ body: CreateIncomeScheduleRequest) async throws -> IncomePaySchedule {
        try await client.request("PATCH", path: "income-schedules/\(id)", body: body)
    }

    func deleteIncomeSchedule(id: String) async throws {
        let _: SuccessResponse = try await client.request("DELETE", path: "income-schedules/\(id)")
    }

    // MARK: - Income

    func getIncome() async throws -> [Income] {
        try await client.request("GET", path: "income")
    }

    func createIncome(_ body: CreateIncomeRequest) async throws -> Income {
        try await client.request("POST", path: "income", body: body)
    }

    func updateIncome(id: String, _ body: CreateIncomeRequest) async throws -> Income {
        try await client.request("PATCH", path: "income/\(id)", body: body)
    }

    func deleteIncome(id: String) async throws {
        let _: SuccessResponse = try await client.request("DELETE", path: "income/\(id)")
    }

    // MARK: - Expenses

    func getExpenses() async throws -> [ExpenseWithTags] {
        try await client.request("GET", path: "expenses")
    }

    func getExpensePeriodView(period: ExpensePeriodKey) async throws -> ExpensePeriodViewResponse {
        try await client.request(
            "GET",
            path: "expenses/period-view",
            query: [
                URLQueryItem(name: "period", value: period.rawValue),
                URLQueryItem(name: "asOf", value: PayPeriodLogic.todayISO()),
            ]
        )
    }

    func getUpcomingPayable(horizonDays: Int = ExpenseDefaults.upcomingPayableHorizonDays) async throws -> [PayableFutureItem] {
        try await client.request(
            "GET",
            path: "expenses/upcoming-payable",
            query: [
                URLQueryItem(name: "horizonDays", value: String(horizonDays)),
                URLQueryItem(name: "asOf", value: PayPeriodLogic.todayISO()),
            ]
        )
    }

    func createExpense(_ body: CreateExpenseRequest) async throws -> ExpenseWithTags {
        try await client.request("POST", path: "expenses", body: body)
    }

    func updateExpenseAmount(id: String, amount: Int) async throws -> ExpenseWithTags {
        try await client.request("PATCH", path: "expenses/\(id)", body: UpdateExpenseAmountRequest(amount: amount))
    }

    func deleteExpense(id: String) async throws {
        let _: SuccessResponse = try await client.request("DELETE", path: "expenses/\(id)")
    }

    func earlyPayExpense(_ body: EarlyPayExpenseRequest) async throws -> ExpenseWithTags {
        try await client.request("POST", path: "expenses/early-pay", body: body)
    }

    // MARK: - Recurring expenses

    func getRecurringExpenses() async throws -> [RecurringExpenseWithTags] {
        try await client.request("GET", path: "recurring-expenses")
    }

    func createRecurringExpense(_ body: CreateRecurringExpenseRequest) async throws -> RecurringExpenseWithTags {
        try await client.request("POST", path: "recurring-expenses", body: body)
    }

    func updateRecurringExpense(id: String, _ body: CreateRecurringExpenseRequest) async throws -> RecurringExpenseWithTags {
        try await client.request("PATCH", path: "recurring-expenses/\(id)", body: body)
    }

    func deleteRecurringExpense(id: String) async throws {
        let _: SuccessResponse = try await client.request("DELETE", path: "recurring-expenses/\(id)")
    }

    func setCancelReminder(id: String) async throws -> RecurringExpenseWithTags {
        try await client.request("POST", path: "recurring-expenses/\(id)/cancel-reminder")
    }

    func clearCancelReminder(id: String) async throws {
        let _: SuccessResponse = try await client.request("DELETE", path: "recurring-expenses/\(id)/cancel-reminder")
    }

    // MARK: - Planned expenses

    func getPlannedExpenses() async throws -> [PlannedExpenseWithTags] {
        try await client.request("GET", path: "planned-expenses")
    }

    func createPlannedExpense(_ body: CreatePlannedExpenseRequest) async throws -> PlannedExpenseWithTags {
        try await client.request("POST", path: "planned-expenses", body: body)
    }

    func updatePlannedExpense(id: String, _ body: CreatePlannedExpenseRequest) async throws -> PlannedExpenseWithTags {
        try await client.request("PATCH", path: "planned-expenses/\(id)", body: body)
    }

    func deletePlannedExpense(id: String) async throws {
        let _: SuccessResponse = try await client.request("DELETE", path: "planned-expenses/\(id)")
    }

    // MARK: - Budgets

    func getBudgets() async throws -> [BudgetWithTags] {
        try await client.request("GET", path: "budgets")
    }

    func createBudget(_ body: CreateBudgetRequest) async throws -> BudgetWithTags {
        try await client.request("POST", path: "budgets", body: body)
    }

    func updateBudget(id: String, _ body: CreateBudgetRequest) async throws -> BudgetWithTags {
        try await client.request("PATCH", path: "budgets/\(id)", body: body)
    }

    func deleteBudget(id: String) async throws {
        let _: SuccessResponse = try await client.request("DELETE", path: "budgets/\(id)")
    }

    func getBudgetExpenses(budgetId: String) async throws -> [ExpenseWithTags] {
        try await client.request("GET", path: "budgets/\(budgetId)/expenses")
    }

    func createBudgetExpense(budgetId: String, _ body: CreateBudgetExpenseRequest) async throws -> ExpenseWithTags {
        try await client.request("POST", path: "budgets/\(budgetId)/expenses", body: body)
    }

    func deleteBudgetExpense(budgetId: String, expenseId: String) async throws {
        let _: SuccessResponse = try await client.request("DELETE", path: "budgets/\(budgetId)/expenses/\(expenseId)")
    }

    // MARK: - Projections

    func getProjections() async throws -> ProjectionsResponse {
        try await client.request(
            "GET",
            path: "projections",
            query: [URLQueryItem(name: "asOf", value: PayPeriodLogic.todayISO())]
        )
    }
}
