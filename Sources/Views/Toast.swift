import SwiftUI
import AppKit

enum ToastStyle {
    case info, success, error, progress
    
    var icon: String {
        switch self {
        case .info:     return "link"
        case .success:  return "checkmark.circle.fill"
        case .error:    return "exclamationmark.triangle.fill"
        case .progress: return "arrow.up.circle.fill"
        }
    }
    
    var tint: Color {
        switch self {
        case .info:     return Color.accentColor
        case .success:  return Color.green
        case .error:    return Color.orange
        case .progress: return Color.blue
        }
    }
}

struct Toast: Identifiable {
    let id = UUID()
    let title: String
    let subtitle: String?
    let style: ToastStyle
    let duration: TimeInterval?   // nil = persistent (until manually dismissed)
    let actionTitle: String?
    let action: (() -> Void)?
}

@MainActor
final class ToastCenter: ObservableObject {
    static let shared = ToastCenter()
    @Published var current: Toast? = nil
    
    private var dismissTask: Task<Void, Never>?
    
    func show(_ toast: Toast) {
        dismissTask?.cancel()
        withAnimation(.spring(response: 0.3, dampingFraction: 0.9)) {
            self.current = toast
        }
        
        switch toast.style {
        case .success:
            NSHapticFeedbackManager.defaultPerformer.perform(.alignment, performanceTime: .default)
            NSSound(named: NSSound.Name("Pop"))?.play()
        case .error:
            NSHapticFeedbackManager.defaultPerformer.perform(.levelChange, performanceTime: .default)
            NSSound(named: NSSound.Name("Basso"))?.play()
        default:
            break
        }
        
        if let d = toast.duration {
            dismissTask = Task { [weak self] in
                try? await Task.sleep(nanoseconds: UInt64(d * 1_000_000_000))
                await self?.dismiss()
            }
        }
    }
    
    func dismiss() {
        withAnimation(.easeInOut(duration: 0.22)) {
            self.current = nil
        }
    }
}

extension ToastCenter {
    func info(_ title: String, subtitle: String? = nil, duration: TimeInterval = 1.8) {
        show(Toast(title: title, subtitle: subtitle, style: .info, duration: duration, actionTitle: nil, action: nil))
    }
    func success(_ title: String, subtitle: String? = nil, duration: TimeInterval = 1.6) {
        show(Toast(title: title, subtitle: subtitle, style: .success, duration: duration, actionTitle: nil, action: nil))
    }
    func error(_ title: String, subtitle: String? = nil, duration: TimeInterval = 2.2) {
        show(Toast(title: title, subtitle: subtitle, style: .error, duration: duration, actionTitle: nil, action: nil))
    }
    func progress(_ title: String, subtitle: String? = nil) {
        show(Toast(title: title, subtitle: subtitle, style: .progress, duration: nil, actionTitle: nil, action: nil))
    }
}

struct ToastView: View {
    let toast: Toast
    let onClose: () -> Void
    
    var body: some View {
        HStack(alignment: .center, spacing: 10) {
            Image(systemName: toast.style.icon)
                .font(.system(size: 14, weight: .semibold))
                .foregroundStyle(toast.style.tint)
                .frame(width: 18)
            
            VStack(alignment: .leading, spacing: 2) {
                Text(toast.title)
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(.primary)
                    .lineLimit(2)
                if let subtitle = toast.subtitle {
                    Text(subtitle)
                        .font(.system(size: 11))
                        .foregroundStyle(.secondary)
                        .lineLimit(2)
                }
            }
            .padding(.vertical, 6)
            
            Spacer(minLength: 8)
            
            if let actionTitle = toast.actionTitle, let action = toast.action {
                Button(actionTitle) { action() }
                    .buttonStyle(.bordered)
                    .controlSize(.small)
            }
            
            Button {
                onClose()
            } label: {
                Image(systemName: "xmark")
                    .font(.system(size: 11, weight: .bold))
                    .foregroundStyle(.secondary)
                    .padding(6)
            }
            .buttonStyle(.plain)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .background(.ultraThinMaterial)
        .overlay(
            RoundedRectangle(cornerRadius: 10)
                .strokeBorder(.white.opacity(0.15), lineWidth: 0.5)
        )
        .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
        .shadow(radius: 10, y: 4)
    }
}

struct ToastHost<Content: View>: View {
    @StateObject private var center = ToastCenter.shared
    let edgePadding: CGFloat
    let content: Content
    
    init(edgePadding: CGFloat = 10, @ViewBuilder content: () -> Content) {
        self.edgePadding = edgePadding
        self.content = content()
    }
    
    var body: some View {
        ZStack(alignment: .top) {
            content
            
            if let toast = center.current {
                ToastView(toast: toast) {
                    center.dismiss()
                }
                .transition(.move(edge: .top).combined(with: .opacity))
                .zIndex(1)
                .padding(.top, edgePadding)
                .padding(.horizontal, edgePadding)
            }
        }
    }
}


