import NoGymKit
import SwiftUI

/// The first step of "New sequence": choose what kind it is.
struct TemplatePickerView: View {
    var body: some View {
        List(TemplateKind.allCases) { kind in
            NavigationLink(value: kind) {
                HStack(spacing: 14) {
                    Image(systemName: kind.symbol)
                        .font(.title2)
                        .frame(width: 36)
                        .foregroundStyle(Color.accentColor)
                    VStack(alignment: .leading, spacing: 2) {
                        Text(kind.title).font(.headline)
                        Text(kind.summary).font(.subheadline).foregroundStyle(.secondary)
                    }
                }
                .padding(.vertical, 6)
            }
        }
        .navigationTitle("New sequence")
        .navigationBarTitleDisplayMode(.inline)
    }
}
