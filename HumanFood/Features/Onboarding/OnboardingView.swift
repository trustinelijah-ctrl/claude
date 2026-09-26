import AVFoundation
import SwiftUI

struct OnboardingView: View {
    var onFinish: () -> Void

    @State private var page = 0
    private let pages = 3

    var body: some View {
        ZStack {
            HF.Palette.canvas.ignoresSafeArea()

            VStack(spacing: 0) {
                TabView(selection: $page) {
                    intro.tag(0)
                    score.tag(1)
                    principles.tag(2)
                }
                .tabViewStyle(.page(indexDisplayMode: .never))
                .animation(HF.Motion.soft, value: page)

                HStack(spacing: 6) {
                    ForEach(0..<pages, id: \.self) { i in
                        Capsule()
                            .fill(HF.Palette.ink.opacity(i == page ? 0.9 : 0.15))
                            .frame(width: i == page ? 22 : 7, height: 7)
                    }
                }
                .animation(HF.Motion.snappy, value: page)
                .padding(.bottom, 24)

                Button(page < pages - 1 ? "Continue" : "Start scanning") {
                    Haptics.tap()
                    if page < pages - 1 {
                        page += 1
                    } else {
                        finish()
                    }
                }
                .buttonStyle(PrimaryButtonStyle())
                .padding(.horizontal, HF.Space.gutter)

                Text(page == pages - 1 ? "Scores are our opinion, not medical advice." : " ")
                    .font(HF.Font.caption)
                    .foregroundStyle(HF.Palette.inkTertiary)
                    .padding(.top, 12)
                    .padding(.bottom, 8)
            }
        }
    }

    private var intro: some View {
        VStack(alignment: .leading, spacing: 18) {
            Spacer()
            Image(systemName: "leaf")
                .font(.system(size: 34, weight: .light))
                .foregroundStyle(HF.Palette.accent)
            Text("Eat like\na human.")
                .font(HF.Font.display(54))
                .foregroundStyle(HF.Palette.ink)
                .lineSpacing(-4)
            Text("Scan anything in the aisle and see, in a second, how close it is to real food.")
                .font(.system(size: 19))
                .foregroundStyle(HF.Palette.inkSecondary)
            Spacer()
            Spacer()
        }
        .padding(.horizontal, HF.Space.gutter + 8)
    }

    private var score: some View {
        VStack(spacing: 28) {
            Spacer()
            if page == 1 {
                ScoreHero(score: 91, size: 190)
            } else {
                Color.clear.frame(height: 280)
            }
            VStack(spacing: 10) {
                Text("One number.\nThe whole story.")
                    .font(HF.Font.display(34))
                    .multilineTextAlignment(.center)
                Text("0 to 100, built from processing, nutrients, ingredients and additives — with healthier swaps whenever there's a better choice.")
                    .font(HF.Font.body)
                    .foregroundStyle(HF.Palette.inkSecondary)
                    .multilineTextAlignment(.center)
            }
            Spacer()
        }
        .padding(.horizontal, HF.Space.gutter + 8)
    }

    private var principles: some View {
        VStack(alignment: .leading, spacing: 22) {
            Spacer()
            Text("Built on\nwhole-food science.")
                .font(HF.Font.display(38))
                .foregroundStyle(HF.Palette.ink)
            VStack(alignment: .leading, spacing: 16) {
                principle("leaf", "Whole foods over ultra-processed")
                principle("carrot", "Mostly plants, as in The China Study")
                principle("cube", "Less added sugar, salt and refined oil")
                principle("cart", "Grocery mode ranks your whole basket")
            }
            Spacer()
            Spacer()
        }
        .padding(.horizontal, HF.Space.gutter + 8)
    }

    private func principle(_ symbol: String, _ text: String) -> some View {
        HStack(spacing: 14) {
            Image(systemName: symbol)
                .font(.system(size: 16))
                .foregroundStyle(HF.Palette.accent)
                .frame(width: 36, height: 36)
                .background(HF.Palette.accent.opacity(0.1), in: Circle())
            Text(text).font(.system(size: 17)).foregroundStyle(HF.Palette.ink)
        }
    }

    private func finish() {
        Task {
            _ = await AVCaptureDevice.requestAccess(for: .video)
            onFinish()
        }
    }
}
