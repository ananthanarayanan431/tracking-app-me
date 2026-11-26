import SwiftUI

struct DetailSheet: View {
    var target: DetailTarget
    var body: some View { Text(target.key).padding() }
}

struct HabitEntrySheet: View {
    var target: HabitEntryTarget
    var body: some View { Text(target.id).padding() }
}

struct AwaySheet: View {
    var gap: Gap
    var body: some View { Text("Away").padding() }
}
