import SwiftUI
import WidgetKit

@main
struct NidoLiveActivityBundle: WidgetBundle {
    var body: some Widget {
        NidoDayWidget()
        NidoLiveActivityWidget()
    }
}
