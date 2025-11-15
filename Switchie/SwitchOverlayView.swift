import SwiftUI
import AppKit

struct SwitchOverlayView: View {
    let candidates: [NSRunningApplication]
    let selectedIndex: Int?
    let searchText: String
    let showNumberBadges: Bool
    let markedBundleIDs: Set<String>
    let onSelect: (NSRunningApplication) -> Void
    let onClose: () -> Void
    let onUnmarkAll: () -> Void
    let onQuitAll: () -> Void
    var onMark: ((NSRunningApplication) -> Void)? = nil

    private let itemSize: CGFloat = 72
    private let iconSize: CGFloat = 56

    var body: some View {
        content
            .background(
                RoundedRectangle(cornerRadius: 18, style: .continuous)
                    .fill(Color(NSColor.windowBackgroundColor))
            )
            .padding(20)
            .fixedSize(horizontal: false, vertical: true)
            .accessibilityElement(children: .contain)
    }

    // MARK: - Content

    private var content: some View {
        VStack(spacing: 10) {
            if !searchText.isEmpty {
                searchBadge
            }

            if candidates.isEmpty {
                emptyState
            } else {
                itemsScroll
            }

            footer
        }
        .padding(.top, 10)
        .padding(.bottom, 10)
        .padding(.horizontal, 8)
    }

    // MARK: - Footer

    private var footer: some View {
        HStack(spacing: 8) {
            footerButton(label: "Close", systemImage: "xmark", action: onClose)

            if !markedBundleIDs.isEmpty {
                footerButton(label: "Unmark all", systemImage: "star.slash", action: onUnmarkAll)
            }

            footerButton(label: "Quit all", systemImage: "power", action: onQuitAll)
        }
        .padding(.horizontal, 8)
        .padding(.top, 4)
    }

    private func footerButton(label: String, systemImage: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            HStack(spacing: 5) {
                Image(systemName: systemImage)
                    .font(.system(size: 10, weight: .medium))
                Text(label)
                    .font(.system(size: 11, weight: .medium))
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 5)
            .background(
                Capsule(style: .continuous)
                    .fill(Color.primary.opacity(0.06))
                    .overlay(
                        Capsule(style: .continuous)
                            .stroke(Color.primary.opacity(0.08), lineWidth: 0.5)
                    )
            )
            .foregroundStyle(.secondary)
        }
        .buttonStyle(.plain)
    }

    private var searchBadge: some View {
        HStack(spacing: 6) {
            Image(systemName: "magnifyingglass")
                .imageScale(.small)
                .foregroundStyle(.tertiary)
            Text(searchText)
                .font(.system(size: 13, weight: .medium, design: .rounded))
                .foregroundStyle(.primary)
                .accessibilityLabel("Search: \(searchText)")
        }
        .padding(.vertical, 5)
        .padding(.horizontal, 10)
        .background(
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .fill(.white.opacity(0.08))
        )
    }

    private var itemsScroll: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 10) {
                ForEach(Array(candidates.enumerated()), id: \.1.processIdentifier) { idx, app in
                    itemView(app: app, index: idx, isSelected: idx == selectedIndex)
                        .onTapGesture { onSelect(app) }
                        .overlay(
                            RightClickHandler { onMark?(app) }
                        )
                }
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 12)
        }
        .frame(minHeight: 120)
    }

    private var emptyState: some View {
        VStack(spacing: 12) {
            Image(systemName: "magnifyingglass")
                .symbolRenderingMode(.hierarchical)
                .font(.system(size: 36, weight: .light))
                .foregroundStyle(.tertiary)
                .accessibilityHidden(true)

            Text("No matches")
                .font(.system(size: 13, weight: .medium))
                .foregroundStyle(.secondary)
        }
        .padding(.vertical, 28)
        .frame(minHeight: 120)
        .accessibilityLabel(searchText.isEmpty
            ? "No applications to display"
            : "No applications match \(searchText)")
    }

    // MARK: - Item View

    @ViewBuilder
    private func itemView(app: NSRunningApplication, index: Int, isSelected: Bool) -> some View {
        let isMarked = app.bundleIdentifier.map { markedBundleIDs.contains($0) } ?? false

        VStack(spacing: 6) {
            ZStack(alignment: .topLeading) {
                AppIconView(app: app, size: iconSize)
                    .overlay {
                        if isSelected {
                            RoundedRectangle(cornerRadius: 12, style: .continuous)
                                .stroke(Color.accentColor, lineWidth: 2.5)
                                .shadow(color: Color.accentColor.opacity(0.5), radius: 6)
                        }
                    }
                    .shadow(color: .black.opacity(0.25), radius: 4, x: 0, y: 2)

                if showNumberBadges && index < 10 {
                    numberBadge(index == 9 ? "0" : "\(index + 1)")
                        .offset(x: -6, y: -6)
                        .accessibilityHidden(true)
                }
            }
            .overlay(alignment: .bottomTrailing) {
                if isMarked {
                    Image(systemName: "star.fill")
                        .font(.system(size: 12, weight: .bold))
                        .foregroundStyle(.yellow)
                        .shadow(color: .black.opacity(0.4), radius: 2, x: 0, y: 1)
                        .offset(x: 4, y: 4)
                }
            }

            Text(app.localizedName ?? app.bundleIdentifier ?? "App")
                .font(.system(size: 11, weight: isSelected ? .semibold : .regular))
                .foregroundStyle(isSelected ? .primary : .secondary)
                .lineLimit(1)
                .frame(width: itemSize)
                .truncationMode(.tail)
        }
        .frame(width: itemSize)
        .padding(.vertical, 8)
        .padding(.horizontal, 6)
        .background(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .fill(isSelected ? Color.white.opacity(0.1) : Color.clear)
        )
        .accessibilityElement(children: .combine)
        .accessibilityLabel(accessibilityLabel(app: app, index: index, isSelected: isSelected))
    }

    private func numberBadge(_ number: String) -> some View {
        Text(number)
            .font(.system(size: 10, weight: .bold, design: .rounded))
            .foregroundStyle(.white)
            .padding(.horizontal, 5)
            .padding(.vertical, 2)
            .background(
                Capsule(style: .continuous)
                    .fill(Color.black.opacity(0.5))
                    .overlay(
                        Capsule(style: .continuous)
                            .stroke(.white.opacity(0.2), lineWidth: 0.5)
                    )
            )
    }

    private func accessibilityLabel(app: NSRunningApplication, index: Int, isSelected: Bool) -> String {
        let name = app.localizedName ?? app.bundleIdentifier ?? "App"
        let prefix = isSelected ? "Selected" : "Item"
        let badge = showNumberBadges && index < 10 ? ", shortcut \(index == 9 ? "0" : "\(index + 1)")" : ""
        let marked = app.bundleIdentifier.map { markedBundleIDs.contains($0) } ?? false
        return "\(prefix): \(name)\(badge)\(marked ? ", marked" : "")"
    }
}

private struct RightClickHandler: NSViewRepresentable {
    let action: () -> Void

    func makeNSView(context: Context) -> RightClickView {
        let view = RightClickView()
        view.action = action
        return view
    }

    func updateNSView(_ nsView: RightClickView, context: Context) {
        nsView.action = action
    }

    final class RightClickView: NSView {
        var action: (() -> Void)?

        override func acceptsFirstMouse(for event: NSEvent?) -> Bool { true }

        override func hitTest(_ point: NSPoint) -> NSView? {
            guard let event = NSApp.currentEvent else { return nil }
            if event.type == .rightMouseDown { return super.hitTest(point) }
            if event.type == .leftMouseDown, event.modifierFlags.contains(.control) {
                return super.hitTest(point)
            }
            return nil
        }

        override func rightMouseDown(with event: NSEvent) {
            action?()
        }

        override func mouseDown(with event: NSEvent) {
            if event.modifierFlags.contains(.control) {
                action?()
            }
        }
    }
}
