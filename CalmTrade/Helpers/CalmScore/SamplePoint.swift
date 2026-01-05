import SwiftUI
#if canImport(Charts)
import Charts
#endif

struct SamplePoint: Identifiable, Equatable {
    let id = UUID()
    let time: Date
    let value: Double
    var isGood: Bool { value >= 50 }
}

@available(iOS 16.0, *)
struct DotChartView: View {
    let points: [SamplePoint]
    @State private var selected: SamplePoint?

    var body: some View {
        Chart {
            ForEach(points) { p in
                RuleMark(x: .value("t", p.time))
                    .lineStyle(StrokeStyle(lineWidth: 1, dash: [2, 5]))
                    .foregroundStyle(.gray.opacity(0.25))
            }
            ForEach(points) { p in
                PointMark(
                    x: .value("Time", p.time),
                    y: .value("Value", p.value)
                )
                .symbolSize(p == selected ? 120 : 60)
                .foregroundStyle(p.isGood ? .green : .orange)
            }
            if let s = selected {
                RuleMark(x: .value("Selected", s.time))
                    .lineStyle(StrokeStyle(lineWidth: 1, dash: [3, 6]))
                    .foregroundStyle(.white.opacity(0.6))
                    .annotation(position: .topLeading, spacing: 0) {
                        Text("\(Int(s.value))")
                            .font(.headline)
                            .padding(.horizontal, 10).padding(.vertical, 6)
                            .background(.ultraThickMaterial)
                            .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
                    }
            }
        }
        .chartXAxis {
            AxisMarks(values: .stride(by: .minute, count: 1)) { _ in
//                AxisTick
//                AxisGridLine().hidden()
//                AxisValueLabel(format: .dateTime.hour().minute(.twoDigits).period(), centered: false)
            }
        }
        .chartYAxis {
            AxisMarks(position: .trailing, values: [0, 25, 50]) { _ in
//                AxisGridLine().hidden()
            }
        }
        .chartPlotStyle { $0.background(Color.black).cornerRadius(14) }
        .padding()
        .background(Color.black)
        .chartOverlay { proxy in
            GeometryReader { geo in
                Rectangle().fill(.clear).contentShape(Rectangle())
                    .gesture(DragGesture(minimumDistance: 0)
                        .onChanged { g in
                            let origin = geo[proxy.plotAreaFrame].origin
                            let x = g.location.x - origin.x
                            if let date: Date = proxy.value(atX: x) {
                                selected = points.min { abs($0.time.timeIntervalSince(date)) < abs($1.time.timeIntervalSince(date)) }
                            }
                        })
            }
        }
    }
}

#if DEBUG
private let previewPoints: [SamplePoint] = {
    let cal = Calendar.current
    let base = cal.startOfDay(for: Date())
    let values: [Double] = [25, 40, 40, 48, 60, 58, 62]
    return values.enumerated().map { i, v in
        SamplePoint(time: cal.date(byAdding: .minute, value: i, to: base)!, value: v)
    }
}()

@available(iOS 16.0, *)
#Preview("DotChart • Dark") {
    DotChartView(points: previewPoints)
        .frame(height: 260)
        .padding()
        .background(Color.black)
        .preferredColorScheme(.dark)
}
#endif
