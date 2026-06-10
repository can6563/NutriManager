import SwiftUI

// MARK: - 토스트

/// 화면 하단에 잠깐 떴다 사라지는 토스트(저장 피드백 등).
struct ToastModifier: ViewModifier {
    @Binding var message: String?
    var systemImage: String = "checkmark.circle.fill"

    func body(content: Content) -> some View {
        content.overlay(alignment: .bottom) {
            if let message {
                HStack(spacing: 8) {
                    Image(systemName: systemImage)
                    Text(message).font(.subheadline.weight(.semibold))
                }
                .foregroundStyle(.white)
                .padding(.horizontal, 18)
                .padding(.vertical, 12)
                .background(Capsule().fill(Color.black.opacity(0.85)))
                .padding(.bottom, 28)
                .transition(.move(edge: .bottom).combined(with: .opacity))
                .onAppear {
                    DispatchQueue.main.asyncAfter(deadline: .now() + 1.8) {
                        withAnimation { self.message = nil }
                    }
                }
            }
        }
        .animation(.spring(duration: 0.35), value: message)
    }
}

extension View {
    func toast(_ message: Binding<String?>, systemImage: String = "checkmark.circle.fill") -> some View {
        modifier(ToastModifier(message: message, systemImage: systemImage))
    }
}

// MARK: - 정보 카드

/// 홈 대시보드의 요약 카드.
struct InfoCard: View {
    let title: String
    let value: String
    let subtitle: String
    let systemImage: String
    var tint: Color = .accentColor

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 6) {
                Image(systemName: systemImage).foregroundStyle(tint)
                Text(title).font(.caption).foregroundStyle(.secondary)
                Spacer()
            }
            Text(value).font(.title2.bold()).foregroundStyle(tint)
            Text(subtitle).font(.caption2).foregroundStyle(.secondary)
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(RoundedRectangle(cornerRadius: 16).fill(Color(.secondarySystemBackground)))
    }
}

// MARK: - D-day 뱃지

struct DDayBadge: View {
    let daysLeft: Int

    var body: some View {
        Text(ExpiryService.ddayLabel(forDaysLeft: daysLeft))
            .font(.caption2.bold())
            .foregroundStyle(.white)
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .background(Capsule().fill(ExpiryService.color(forDaysLeft: daysLeft)))
    }
}

// MARK: - 칩(태그)

struct TagChip: View {
    let text: String
    var systemImage: String? = nil
    var tint: Color = .accentColor

    var body: some View {
        HStack(spacing: 4) {
            if let systemImage { Image(systemName: systemImage).font(.caption2) }
            Text(text).font(.caption2.weight(.medium))
        }
        .foregroundStyle(tint)
        .padding(.horizontal, 10)
        .padding(.vertical, 5)
        .background(Capsule().fill(tint.opacity(0.14)))
    }
}

// MARK: - 섹션 헤더

struct SectionHeader: View {
    let title: String
    var systemImage: String? = nil

    var body: some View {
        HStack(spacing: 6) {
            if let systemImage { Image(systemName: systemImage).foregroundStyle(.accent) }
            Text(title).font(.headline)
            Spacer()
        }
    }
}

// MARK: - 큰 기본 버튼 스타일

struct PrimaryButtonStyle: ButtonStyle {
    var enabled: Bool = true
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.headline)
            .foregroundStyle(.white)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 16)
            .background(
                RoundedRectangle(cornerRadius: 14)
                    .fill(enabled ? Color.accentColor : Color.gray)
            )
            .opacity(configuration.isPressed ? 0.8 : 1)
    }
}
