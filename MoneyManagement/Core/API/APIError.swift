import Foundation

struct APIError: LocalizedError {
    let status: Int
    let message: String

    var errorDescription: String? { message }

    var isUnauthorized: Bool { status == 401 }
}
