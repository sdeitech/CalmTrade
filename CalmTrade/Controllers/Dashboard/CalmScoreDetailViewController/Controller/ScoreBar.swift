////
////  GaugeBarFramePreferenceKey.swift
////  CalmTrade
////
////  Created by Anas Parekh on 12/09/25.
////
//
//
////
////  SwiftuiGuageView.swift
////  CalmTrade
////
////  Created by Anas Parekh on 08/09/25.
////
//
//import SwiftUI
//
//// MARK: - Model
//struct ScoreTileProps: Equatable {
//    var score: Double
//    var date: String
//}
//
//// MARK: - Main View
//struct ScoreBarTile: View {
//    var props: ScoreTileProps
//
//    @State private var gaugeBarFrame: CGRect = .zero
//
//    var body: some View {
//        VStack(alignment: .leading, spacing: 20) {
//            Spacer()
//
//            GaugeBar(score: props.score)
//                .frame(height: 36)
//                .padding(.top, 8)
//
//            // Title
//            HStack {
//                Spacer()
//                Text(props.date)
//                    .font(.system(size: 32, weight: .semibold, design: .rounded))
//                    .foregroundColor(.white)
//                    .padding(.top, 8)
//                Spacer()
//            }
//
//            Spacer()
//        }
//        .padding(20)
//        .background(Color.clear)
//        .coordinateSpace(name: "container")
//    }
//
//    private static func format(date: Date) -> String {
//        let df = DateFormatter()
//        df.dateFormat = "'Last update' M/d/yyyy HH:mm:ss zzz"
//        return df.string(from: date)
//    }
//}
//
//// MARK: - Previews
//struct ScoreBarTile_Previews: PreviewProvider {
//    static var previews: some View {
//        Group {
//            preview(for: .appleHK, isStreaming: true, score: 100, date: "Yesterday")
//                .previewDisplayName("High Score")
//        }
//        .previewLayout(.sizeThatFits)
//        .background(Color.black)
//    }
//
//    static func preview(for src: DeviceSource, isStreaming: Bool, score: Double, date: String) -> some View {
//        let props = ScoreTileProps(
//            score: score,
//            date: date
//        )
//        return ScoreBarTile(props: props)
//            .frame(width: 820, height: 380)
//    }
//}
