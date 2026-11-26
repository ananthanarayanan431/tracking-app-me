import SwiftUI

struct LimitsPage: View {
    @Environment(AppModel.self) private var model
    @Environment(\.skin) private var skin

    var body: some View {
        Card { EmptyNote("Coming up") }
    }
}
