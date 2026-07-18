import SwiftUI
import ListEffectSwiftUI
import ListEffectCore

/// Demonstrates the SwiftUI scroll-linked reveal modifier.
struct SwiftUIDemoView: View {
    /// The repeating colors used by example rows.
    private let colors: [Color] = [.red, .orange, .green, .blue, .purple]

    /// The scrollable SwiftUI reveal catalog.
    var body: some View {
        ScrollView {
            LazyVStack(spacing: 12) {
                ForEach(0..<50, id: \.self) { i in
                    RoundedRectangle(cornerRadius: 12)
                        .fill(colors[i % colors.count])
                        .frame(height: 80)
                        .overlay(Text("Row #\(i)").foregroundStyle(.white))
                        .listEffect(RevealEffect(minScale: 0.8))
                }
            }
            .padding(.horizontal, 16)
        }
    }
}
