import SwiftUI

@main
struct GestureFixtureApp: App {
    @AppStorage("fixtureTapped") private var tapped = false
    @AppStorage("fixtureSwiped") private var swiped = false

    var body: some Scene {
        WindowGroup {
            VStack(spacing: 24) {
                Text("XCTest 手势验证")
                    .font(.title2.bold())
                Button("点按这里") { tapped = true }
                    .buttonStyle(.borderedProminent)
                    .accessibilityIdentifier("fixture.tap")
                Text("在此区域向上滑动")
                    .frame(maxWidth: .infinity, minHeight: 220)
                    .background(.blue.opacity(0.12), in: RoundedRectangle(cornerRadius: 16))
                    .contentShape(Rectangle())
                    .gesture(DragGesture().onEnded { gesture in
                        if gesture.translation.height < -35 { swiped = true }
                    })
                    .accessibilityElement(children: .ignore)
                    .accessibilityLabel("在此区域向上滑动")
                    .accessibilityIdentifier("fixture.swipe")
                Text(tapped && swiped ? "点按和滑动通过" : "点按 \(tapped ? "通过" : "待测") · 滑动 \(swiped ? "通过" : "待测")")
                    .foregroundStyle(tapped && swiped ? Color.green : Color.primary)
                    .accessibilityIdentifier(tapped && swiped ? "fixture.passed" : "fixture.pending")
            }
            .padding(24)
            .onAppear {
                if ProcessInfo.processInfo.arguments.contains("--reset-gesture-result") {
                    tapped = false
                    swiped = false
                }
            }
        }
    }
}
