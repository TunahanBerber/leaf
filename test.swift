import GoogleSignIn
import UIKit
func test() async throws {
    let result = try await GIDSignIn.sharedInstance.signIn(
        withPresenting: UIViewController(),
        hint: nil,
        additionalScopes: nil,
        nonce: "test-nonce"
    )
}
