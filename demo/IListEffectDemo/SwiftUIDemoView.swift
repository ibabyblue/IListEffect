import SwiftUI
import ListEffectSwiftUI
import ListEffectCore

/// SwiftUI · Reveal：位置型 scroll-linked 缩放淡入。
struct SwiftUIDemoView: View {
    private let colors: [Color] = [.red, .orange, .green, .blue, .purple]

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

/// SwiftUI · Slide In：入场一次性滑入动画（.entranceEffect）。
struct SlideInSwiftUIDemoView: View {
    private let colors: [Color] = [.red, .orange, .green, .blue, .purple]

    var body: some View {
        ScrollView {
            LazyVStack(spacing: 12) {
                ForEach(0..<50, id: \.self) { i in
                    RoundedRectangle(cornerRadius: 12)
                        .fill(colors[i % colors.count])
                        .frame(height: 80)
                        .overlay(Text("Row #\(i)").foregroundStyle(.white))
                        .entranceEffect(SlideInEffect())
                }
            }
            .padding(.horizontal, 16)
        }
    }
}
