import SwiftUI

struct DetailSheet: View {
    var target: DetailTarget
    var body: some View { Text(target.key).padding() }
}
