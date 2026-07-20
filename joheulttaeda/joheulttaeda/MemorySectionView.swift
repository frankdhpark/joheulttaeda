import SwiftUI

struct MemorySectionView: View {
    let onHome: () -> Void

    @State private var selectedMode: MemoryMode = .threads

    var body: some View {
        ZStack(alignment: .bottom) {
            MemoryPalette.background
                .ignoresSafeArea()

            Group {
                switch selectedMode {
                case .moments:
                    MomentsMemoryView()
                case .days:
                    DaysMemoryView()
                case .months:
                    MonthsMemoryView()
                case .threads:
                    ThreadsMemoryView()
                }
            }
            .transition(.opacity)

            LinearGradient(
                colors: [.clear, MemoryPalette.background.opacity(0.96)],
                startPoint: .top,
                endPoint: .bottom
            )
            .frame(height: 78)
            .allowsHitTesting(false)

            MemoryNavigation(selectedMode: $selectedMode, onHome: onHome)
                .padding(.bottom, 8)
        }
        .background(MemoryPalette.background.ignoresSafeArea())
        .accessibilityElement(children: .contain)
        .accessibilityLabel("Memory")
    }
}

private enum MemoryMode: String, CaseIterable, Identifiable {
    case moments = "Moments"
    case days = "Days"
    case months = "Months"
    case threads = "Threads"

    var id: String { rawValue }
}

private enum MemoryPalette {
    static let background = Color(red: 0.982, green: 0.959, blue: 0.945)
    static let paper = Color(red: 0.998, green: 0.995, blue: 0.991)
    static let text = Color(red: 0.45, green: 0.42, blue: 0.39)
    static let subdued = Color(red: 0.68, green: 0.65, blue: 0.62)
    static let navigation = Color(red: 0.91, green: 0.88, blue: 0.84)
    static let scrapbook = Color(red: 0.84, green: 0.84, blue: 0.83)
}

private struct MemoryNavigation: View {
    @Binding var selectedMode: MemoryMode
    let onHome: () -> Void

    var body: some View {
        HStack(spacing: 1) {
            Button(action: onHome) {
                Image(systemName: "house.fill")
                    .font(.system(size: 12, weight: .semibold))
                    .frame(width: 34, height: 32)
            }
            .accessibilityLabel("홈")

            ForEach(MemoryMode.allCases) { mode in
                Button {
                    withAnimation(.easeInOut(duration: 0.17)) {
                        selectedMode = mode
                    }
                } label: {
                    Text(mode.rawValue)
                        .font(.system(size: 10, weight: .medium, design: .rounded))
                        .frame(width: width(for: mode), height: 32)
                        .background {
                            if selectedMode == mode {
                                Capsule()
                                    .fill(.white.opacity(0.94))
                            }
                        }
                }
                .accessibilityAddTraits(selectedMode == mode ? .isSelected : [])
            }
        }
        .foregroundStyle(MemoryPalette.text)
        .padding(3)
        .background(MemoryPalette.navigation, in: Capsule())
        .buttonStyle(.plain)
        .fixedSize()
    }

    private func width(for mode: MemoryMode) -> CGFloat {
        switch mode {
        case .moments: 62
        case .days: 44
        case .months: 55
        case .threads: 58
        }
    }
}

private struct ThreadsMemoryView: View {
    @State private var filter = "All"

    var body: some View {
        ScrollView(.vertical) {
            VStack(alignment: .leading, spacing: 14) {
                HStack(spacing: 0) {
                    filterButton("All")
                    filterButton("Film")
                    filterButton("Scrapbook")
                }
                .padding(3)
                .background(MemoryPalette.navigation, in: Capsule())
                .fixedSize()

                Text("Recommended")
                    .font(.system(size: 15, weight: .bold, design: .rounded))
                    .foregroundStyle(MemoryPalette.text)

                LazyVGrid(
                    columns: [GridItem(.flexible(), spacing: 16), GridItem(.flexible())],
                    spacing: 16
                ) {
                    ThreadCard(style: .film, tape: false)
                    ThreadCard(style: .scrapbook, tape: true)
                    ThreadCard(style: .scrapbook, tape: true)
                    ThreadCard(style: .film, tape: false)
                }

                Text("Same Pose, Different Day")
                    .font(.system(size: 15, weight: .bold, design: .rounded))
                    .foregroundStyle(MemoryPalette.text)
                    .padding(.top, 2)

                ScrollView(.horizontal) {
                    HStack(spacing: 14) {
                        ThreadCard(style: .film, tape: false)
                            .frame(width: 142)
                        ThreadCard(style: .film, tape: false)
                            .frame(width: 142)
                        ThreadCard(style: .film, tape: false)
                            .frame(width: 142)
                    }
                }
                .scrollIndicators(.hidden)
            }
            .padding(.horizontal, 36)
            .padding(.top, 16)
            .padding(.bottom, 92)
        }
        .scrollIndicators(.hidden)
    }

    private func filterButton(_ title: String) -> some View {
        Button {
            filter = title
        } label: {
            Text(title)
                .font(.system(size: 10, weight: .medium, design: .rounded))
                .foregroundStyle(MemoryPalette.text)
                .frame(width: title == "Scrapbook" ? 78 : 50, height: 24)
                .background {
                    if filter == title {
                        Capsule().fill(.white)
                    }
                }
        }
        .buttonStyle(.plain)
    }
}

private enum ThreadCardStyle {
    case film
    case scrapbook
}

private struct ThreadCard: View {
    let style: ThreadCardStyle
    let tape: Bool

    var body: some View {
        GeometryReader { proxy in
            let size = proxy.size

            VStack(alignment: .leading, spacing: 3) {
                Group {
                    switch style {
                    case .film:
                        FilmStripPlaceholder()
                    case .scrapbook:
                        ScrapbookPlaceholder(showTape: tape)
                    }
                }
                .frame(height: size.height * 0.68)

                Text(style == .film ? "Film" : "Scrapbook")
                    .font(.system(size: 7, weight: .medium, design: .rounded))
                    .padding(.horizontal, 4)
                    .padding(.vertical, 2)
                    .background(MemoryPalette.navigation, in: Capsule())

                Text("Thread's Title")
                    .font(.system(size: 10, weight: .bold, design: .rounded))
                    .foregroundStyle(MemoryPalette.text)

                Text("2025 · Jul 15th, 2026")
                    .font(.system(size: 6.5, weight: .medium, design: .rounded))
                    .foregroundStyle(MemoryPalette.subdued)
            }
            .padding(7)
            .frame(width: size.width, height: size.height, alignment: .topLeading)
            .background(MemoryPalette.paper)
            .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: 8, style: .continuous)
                    .stroke(.black, lineWidth: 0.9)
            }
        }
        .aspectRatio(0.82, contentMode: .fit)
        .accessibilityElement(children: .combine)
        .accessibilityLabel("Thread's Title")
    }
}

private struct FilmStripPlaceholder: View {
    var body: some View {
        GeometryReader { proxy in
            let gap: CGFloat = 4
            let cellWidth = (proxy.size.width - gap * 3) / 4
            let cellHeight = (proxy.size.height - gap * 2) / 3

            VStack(spacing: gap) {
                ForEach(0..<3, id: \.self) { _ in
                    HStack(spacing: gap) {
                        ForEach(0..<4, id: \.self) { _ in
                            RoundedRectangle(cornerRadius: 3, style: .continuous)
                                .fill(.white)
                                .overlay {
                                    RoundedRectangle(cornerRadius: 3, style: .continuous)
                                        .stroke(.black, lineWidth: 0.8)
                                }
                                .frame(width: cellWidth, height: cellHeight)
                        }
                    }
                }
            }
        }
        .padding(4)
        .background(MemoryPalette.scrapbook)
        .overlay { Rectangle().stroke(.black, lineWidth: 0.8) }
    }
}

private struct ScrapbookPlaceholder: View {
    let showTape: Bool

    var body: some View {
        GeometryReader { proxy in
            ZStack {
                RoundedRectangle(cornerRadius: 4)
                    .fill(MemoryPalette.scrapbook)
                    .overlay { RoundedRectangle(cornerRadius: 4).stroke(.black, lineWidth: 0.8) }
                    .frame(width: proxy.size.width * 0.62, height: proxy.size.height * 0.78)
                    .offset(x: proxy.size.width * 0.16, y: proxy.size.height * 0.08)

                RoundedRectangle(cornerRadius: 4)
                    .fill(Color(red: 0.78, green: 0.78, blue: 0.77))
                    .overlay { RoundedRectangle(cornerRadius: 4).stroke(.black, lineWidth: 0.8) }
                    .frame(width: proxy.size.width * 0.56, height: proxy.size.height * 0.74)
                    .offset(x: -proxy.size.width * 0.15, y: -proxy.size.height * 0.06)

                if showTape {
                    Rectangle()
                        .fill(Color(red: 0.85, green: 0.84, blue: 0.81).opacity(0.90))
                        .frame(width: proxy.size.width * 0.42, height: 15)
                        .rotationEffect(.degrees(-9))
                        .offset(x: -proxy.size.width * 0.23, y: -proxy.size.height * 0.39)
                }
            }
        }
    }
}

private struct MonthsMemoryView: View {
    var body: some View {
        ScrollView(.vertical) {
            VStack(alignment: .leading, spacing: 14) {
                MemoryPullHandle()
                    .frame(height: 33)

                MonthSection(title: "May 2026", layout: .may)
                MonthSection(title: "June 2026", layout: .june)
                MonthSection(title: "July 2026", layout: .july)
            }
            .padding(.horizontal, 38)
            .padding(.bottom, 92)
        }
        .scrollIndicators(.hidden)
    }
}

private struct MemoryPullHandle: View {
    var body: some View {
        ZStack(alignment: .top) {
            RoundedRectangle(cornerRadius: 9, style: .continuous)
                .fill(MemoryPalette.paper.opacity(0.55))
                .overlay(alignment: .bottom) {
                    Rectangle()
                        .fill(.black.opacity(0.14))
                        .frame(height: 0.7)
                }

            Image(systemName: "chevron.up")
                .font(.system(size: 15, weight: .semibold))
                .foregroundStyle(MemoryPalette.text)
                .padding(.top, 3)
        }
    }
}

private enum MonthLayout {
    case may
    case june
    case july
}

private struct MonthSection: View {
    let title: String
    let layout: MonthLayout

    var body: some View {
        VStack(alignment: .leading, spacing: 7) {
            Text(title)
                .font(.system(size: 14, weight: .bold, design: .rounded))
                .foregroundStyle(MemoryPalette.text)

            MonthMosaic(layout: layout)
                .frame(height: layout == .june ? 170 : 142)
        }
    }
}

private struct MonthMosaic: View {
    let layout: MonthLayout

    var body: some View {
        GeometryReader { proxy in
            let w = proxy.size.width
            let h = proxy.size.height
            let gap: CGFloat = 7

            switch layout {
            case .may:
                monthBlock("W1", width: w * 0.54, height: h, square: 11)
                    .position(x: w * 0.27, y: h / 2)
                monthBlock("W2", width: w * 0.46 - gap, height: h * 0.48, square: 10)
                    .position(x: w * 0.77 + gap / 2, y: h * 0.24)
                monthBlock("W3", width: w * 0.22, height: h * 0.48 - gap, square: 8)
                    .position(x: w * 0.66, y: h * 0.76 + gap / 2)
                monthBlock("W4", width: w * 0.24 - gap, height: h * 0.48 - gap, square: 9)
                    .position(x: w * 0.88, y: h * 0.76 + gap / 2)

            case .june:
                monthBlock("W1", width: w * 0.54, height: h, square: 12)
                    .position(x: w * 0.27, y: h / 2)
                monthBlock("W2", width: w * 0.46 - gap, height: h * 0.63, square: 10)
                    .position(x: w * 0.77 + gap / 2, y: h * 0.315)
                monthBlock("W3", width: w * 0.22, height: h * 0.37 - gap, square: 8)
                    .position(x: w * 0.66, y: h * 0.815 + gap / 2)
                monthBlock("W4", width: w * 0.24 - gap, height: h * 0.37 - gap, square: 9)
                    .position(x: w * 0.88, y: h * 0.815 + gap / 2)

            case .july:
                monthBlock("W1", width: w * 0.29, height: h * 0.48, square: 10)
                    .position(x: w * 0.145, y: h * 0.24)
                monthBlock("W2", width: w * 0.29, height: h * 0.48 - gap, square: 9)
                    .position(x: w * 0.145, y: h * 0.76 + gap / 2)
                monthBlock("W3", width: w * 0.71 - gap, height: h, square: 12)
                    .position(x: w * 0.645 + gap / 2, y: h / 2)
            }
        }
    }

    private func monthBlock(_ week: String, width: CGFloat, height: CGFloat, square: CGFloat) -> some View {
        let isCompact = width < 90 || height < 75
        return MemoryPhotoBlock(
            squareSize: square,
            heading: week,
            detail: isCompact ? "#ipsum" : "#lorem\n#ipsum\nlorem ipsum dolor sit amet"
        )
            .frame(width: width, height: height)
    }
}

private struct DaysMemoryView: View {
    var body: some View {
        VStack(spacing: 10) {
            MonthNavigationHeader()

            ScrollView(.vertical) {
                DayGrid()
                    .frame(height: 650)
                    .padding(.horizontal, 30)
                    .padding(.bottom, 92)
            }
            .scrollIndicators(.hidden)
        }
        .padding(.top, 12)
    }
}

private struct MonthNavigationHeader: View {
    var body: some View {
        VStack(spacing: 7) {
            HStack(spacing: 14) {
                Text("May 2026")
                    .foregroundStyle(MemoryPalette.subdued.opacity(0.65))
                Image(systemName: "chevron.left")
                Text("June 2026")
                    .fontWeight(.bold)
                Image(systemName: "chevron.right")
                Text("July 2026")
                    .foregroundStyle(MemoryPalette.subdued.opacity(0.65))
            }
            .font(.system(size: 13, weight: .semibold, design: .rounded))
            .foregroundStyle(MemoryPalette.text)

            HStack(spacing: 0) {
                ForEach(1...4, id: \.self) { week in
                    Text("W\(week)")
                        .font(.system(size: 9, weight: .medium, design: .rounded))
                        .frame(width: 40, height: 20)
                        .background {
                            if week == 4 {
                                Capsule().fill(.white)
                            }
                        }
                }
            }
            .foregroundStyle(MemoryPalette.text)
            .padding(2)
            .background(MemoryPalette.navigation, in: Capsule())
        }
    }
}

private struct DayGrid: View {
    var body: some View {
        GeometryReader { proxy in
            let w = proxy.size.width
            let gap: CGFloat = 7

            DayCard(day: "21st", weekday: "SUN", square: 13)
                .frame(width: w * 0.62, height: 190)
                .position(x: w * 0.31, y: 95)

            DayCard(day: "22nd", weekday: "MON", square: 12)
                .frame(width: w * 0.38 - gap, height: 120)
                .position(x: w * 0.81 + gap / 2, y: 60)

            DayCard(day: "23rd", weekday: "THU", square: 9)
                .frame(width: w * 0.38 - gap, height: 63)
                .position(x: w * 0.81 + gap / 2, y: 155 + gap / 2)

            DayCard(day: "24th", weekday: "WED", square: 13)
                .frame(width: w * 0.40, height: 155)
                .position(x: w * 0.20, y: 190 + gap + 77.5)

            DayCard(day: "25th", weekday: "THU", square: 13)
                .frame(width: w * 0.60 - gap, height: 155)
                .position(x: w * 0.70 + gap / 2, y: 190 + gap + 77.5)

            DayCard(day: "26th", weekday: "FRI", square: 12)
                .frame(width: w * 0.62, height: 145)
                .position(x: w * 0.31, y: 190 + 155 + gap * 2 + 72.5)

            DayCard(day: "27th", weekday: "SAT", square: 11)
                .frame(width: w * 0.38 - gap, height: 145)
                .position(x: w * 0.81 + gap / 2, y: 190 + 155 + gap * 2 + 72.5)
        }
    }
}

private struct DayCard: View {
    let day: String
    let weekday: String
    let square: CGFloat

    var body: some View {
        MemoryPhotoBlock(
            squareSize: square,
            heading: "\(day)\n\(weekday)",
            detail: "#lorem\n#ipsum\nlorem ipsum dolor sit amet"
        )
    }
}

private struct MomentsMemoryView: View {
    var body: some View {
        VStack(spacing: 8) {
            WeekNavigationHeader()

            ScrollView(.vertical) {
                HStack(alignment: .top, spacing: 8) {
                    TimelineLabels()
                        .frame(width: 50, height: 640)

                    MomentsGrid()
                        .frame(height: 640)
                }
                .padding(.horizontal, 29)
                .padding(.bottom, 92)
            }
            .scrollIndicators(.hidden)
        }
        .padding(.top, 10)
    }
}

private struct WeekNavigationHeader: View {
    private let days = ["21st\nSUN", "22nd\nMON", "23rd\nTUE", "24th\nWED", "25th\nTHU", "26th\nFRI", "27th\nSAT"]

    var body: some View {
        VStack(spacing: 6) {
            HStack(spacing: 16) {
                Text("Jun · W3")
                    .foregroundStyle(MemoryPalette.subdued)
                Image(systemName: "chevron.left")
                VStack(spacing: 0) {
                    Text("2026").font(.system(size: 7, weight: .bold))
                    Text("Jun · W4").fontWeight(.bold)
                }
                Image(systemName: "chevron.right")
                Text("Jul · W1")
                    .foregroundStyle(MemoryPalette.subdued)
            }
            .font(.system(size: 12, weight: .semibold, design: .rounded))
            .foregroundStyle(MemoryPalette.text)

            HStack(spacing: 0) {
                ForEach(Array(days.enumerated()), id: \.offset) { index, day in
                    Text(day)
                        .font(.system(size: 6.5, weight: .bold, design: .rounded))
                        .multilineTextAlignment(.center)
                        .frame(width: 34, height: 27)
                        .background {
                            if index == 0 {
                                Capsule().fill(.white)
                            }
                        }
                }
            }
            .foregroundStyle(MemoryPalette.text)
            .padding(2)
            .background(MemoryPalette.navigation, in: Capsule())
        }
    }
}

private struct TimelineLabels: View {
    private let labels = ["8 AM", "10 AM", "12 PM", "2 PM", "4 PM", "6 PM", "8 PM"]

    var body: some View {
        GeometryReader { proxy in
            Path { path in
                path.move(to: CGPoint(x: proxy.size.width - 5, y: 7))
                path.addLine(to: CGPoint(x: proxy.size.width - 5, y: proxy.size.height - 7))
            }
            .stroke(MemoryPalette.subdued.opacity(0.35), lineWidth: 1)

            ForEach(Array(labels.enumerated()), id: \.offset) { index, label in
                HStack(spacing: 3) {
                    Text(label)
                        .font(.system(size: 9, weight: .semibold, design: .rounded))
                    Circle()
                        .fill(MemoryPalette.text)
                        .frame(width: 4, height: 4)
                }
                .foregroundStyle(MemoryPalette.text)
                .position(x: proxy.size.width / 2, y: CGFloat(index) * 100 + 8)
            }
        }
    }
}

private struct MomentsGrid: View {
    var body: some View {
        GeometryReader { proxy in
            let w = proxy.size.width
            let gap: CGFloat = 7
            let half = (w - gap) / 2

            moment("8:10 AM", x: half / 2, y: 57, width: half, height: 114, square: 11)
            moment("10:39 AM", x: half + gap + half / 2, y: 57, width: half, height: 114, square: 12)

            moment("11:20 AM", x: w * 0.18, y: 177, width: w * 0.36, height: 112, square: 10)
            moment("1:12 PM", x: w * 0.68, y: 177, width: w * 0.64 - gap, height: 112, square: 11)

            moment("2:30 PM", x: w * 0.25, y: 283, width: w * 0.50 - gap / 2, height: 92, square: 10)
            moment("3:33 PM", x: w * 0.75, y: 283, width: w * 0.50 - gap / 2, height: 92, square: 10)

            moment("2:30 PM", x: w * 0.31, y: 382, width: w * 0.62 - gap / 2, height: 96, square: 11)
            moment("5:29 PM", x: w * 0.81, y: 382, width: w * 0.38 - gap / 2, height: 96, square: 9)

            moment("6:10 PM", x: w * 0.25, y: 476, width: w * 0.50 - gap / 2, height: 84, square: 10)
            moment("7:59 PM", x: w * 0.75, y: 476, width: w * 0.50 - gap / 2, height: 84, square: 10)
        }
    }

    private func moment(
        _ time: String,
        x: CGFloat,
        y: CGFloat,
        width: CGFloat,
        height: CGFloat,
        square: CGFloat
    ) -> some View {
        MemoryPhotoBlock(squareSize: square, heading: time, detail: "#lorem\n#ipsum")
            .frame(width: width, height: height)
            .position(x: x, y: y)
    }
}

private struct MemoryPhotoBlock: View {
    let squareSize: CGFloat
    let heading: String
    let detail: String

    var body: some View {
        ZStack(alignment: .topLeading) {
            MemoryCheckerboard(squareSize: squareSize)

            Text(heading)
                .font(.system(size: 10, weight: .bold, design: .rounded))
                .foregroundStyle(MemoryPalette.text)
                .padding(.top, 7)
                .padding(.leading, 8)

            Text(detail)
                .font(.system(size: 7.5, weight: .medium, design: .rounded))
                .foregroundStyle(MemoryPalette.text)
                .padding(.leading, 8)
                .padding(.bottom, 7)
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottomLeading)
        }
        .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .stroke(.black, lineWidth: 0.9)
        }
    }
}

private struct MemoryCheckerboard: View {
    let squareSize: CGFloat

    var body: some View {
        Canvas { context, size in
            context.fill(Path(CGRect(origin: .zero, size: size)), with: .color(.white))

            let columns = Int(ceil(size.width / squareSize))
            let rows = Int(ceil(size.height / squareSize))

            for row in 0..<rows {
                for column in 0..<columns where (row + column).isMultiple(of: 2) {
                    let rect = CGRect(
                        x: CGFloat(column) * squareSize,
                        y: CGFloat(row) * squareSize,
                        width: squareSize,
                        height: squareSize
                    )
                    context.fill(Path(rect), with: .color(Color.black.opacity(0.055)))
                }
            }
        }
    }
}
