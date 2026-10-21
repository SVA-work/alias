import SwiftUI

enum Palette {
    static let background = Color("GameBackground")
    static let ink = Color("GameInk")
    static let muted = Color("GameMuted")
    static let accent = Color.accentColor
    static let soft = Color("GameSoft")
    static let pink = Color("GamePink")
    static let green = Color("GameGreen")
    static let sage = Color("GameSage")
}
struct GameButtonStyle: ButtonStyle {
    var secondary = false
    func makeBody(configuration: Configuration) -> some View {
        configuration.label.font(.headline).frame(maxWidth: .infinity).padding(.vertical, 19)
            .foregroundStyle(secondary ? Palette.ink : .white)
            .background(secondary ? Palette.soft : Palette.accent, in: RoundedRectangle(cornerRadius: 20))
            .opacity(configuration.isPressed ? 0.7 : 1)
    }
}
struct GameCard<Content: View>: View {
    @ViewBuilder var content: Content
    var body: some View { content.padding(20).frame(maxWidth: .infinity, alignment: .leading).background(.white, in: RoundedRectangle(cornerRadius: 22)) }
}
struct GameHeading: View {
    let title: String
    var subtitle: String? = nil
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title).font(.largeTitle.bold())
            if let subtitle { Text(subtitle).font(.subheadline).foregroundStyle(Palette.muted) }
        }.frame(maxWidth: .infinity, alignment: .leading)
    }
}
struct HalfOval: Shape {
    var upper: Bool
    func path(in rect: CGRect) -> Path {
        var p = Path()
        if upper {
            p.move(to: .zero); p.addLine(to: CGPoint(x: rect.width, y: 0))
            p.addCurve(to: .zero, control1: CGPoint(x: rect.width, y: rect.height * 1.333), control2: CGPoint(x: 0, y: rect.height * 1.333))
        } else {
            p.move(to: CGPoint(x: 0, y: rect.height))
            p.addCurve(to: CGPoint(x: rect.width, y: rect.height), control1: CGPoint(x: 0, y: -rect.height / 3), control2: CGPoint(x: rect.width, y: -rect.height / 3))
            p.addLine(to: CGPoint(x: 0, y: rect.height))
        }
        p.closeSubpath(); return p
    }
}
struct HatArtwork: View {
    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 15).fill(.white).frame(width: 105, height: 135).rotationEffect(.degrees(-14)).offset(x: -52, y: -65)
            Text("КОМЕТА").font(.caption.bold()).rotationEffect(.degrees(-14)).offset(x: -52, y: -93)
            RoundedRectangle(cornerRadius: 15).fill(Palette.pink).frame(width: 105, height: 135).rotationEffect(.degrees(14)).offset(x: 52, y: -65)
            Image(systemName: "sparkles").font(.largeTitle).offset(x: 52, y: -72)
            Ellipse().fill(Palette.accent.opacity(0.8)).frame(width: 280, height: 64).offset(y: 76)
            UnevenRoundedRectangle(topLeadingRadius: 38, topTrailingRadius: 38).fill(Palette.accent).frame(width: 190, height: 148).rotationEffect(.degrees(-5)).offset(y: 12)
            RoundedRectangle(cornerRadius: 5).fill(Palette.pink).frame(width: 190, height: 27).rotationEffect(.degrees(-5)).offset(y: 50)
        }.frame(height: 290).accessibilityHidden(true)
    }
}
