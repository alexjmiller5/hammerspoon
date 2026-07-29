import Foundation
import ApplicationServices
import AppKit

func getRole(_ el: AXUIElement) -> String {
    var ref: CFTypeRef?
    AXUIElementCopyAttributeValue(el, kAXRoleAttribute as CFString, &ref)
    return (ref as? String) ?? ""
}

func getSize(_ el: AXUIElement) -> CGSize {
    var ref: CFTypeRef?
    AXUIElementCopyAttributeValue(el, kAXSizeAttribute as CFString, &ref)
    var s = CGSize.zero
    if let ref = ref { AXValueGetValue(ref as! AXValue, .cgSize, &s) }
    return s
}

func getPos(_ el: AXUIElement) -> CGPoint {
    var ref: CFTypeRef?
    AXUIElementCopyAttributeValue(el, kAXPositionAttribute as CFString, &ref)
    var p = CGPoint.zero
    if let ref = ref { AXValueGetValue(ref as! AXValue, .cgPoint, &p) }
    return p
}

func getChildren(_ el: AXUIElement) -> [AXUIElement] {
    var ref: CFTypeRef?
    guard AXUIElementCopyAttributeValue(el, kAXChildrenAttribute as CFString, &ref) == .success,
          let children = ref as? [AXUIElement] else { return [] }
    return children
}

struct SidebarInfo {
    let sidebar: AXUIElement
    let width: CGFloat
    let position: CGPoint
    let height: CGFloat
}

// Recursively search for the sidebar pattern:
// A parent group that has 2+ children where one is narrow (94-400px) and another is wide
func findSidebar(in element: AXUIElement, windowWidth: CGFloat, depth: Int = 0) -> SidebarInfo? {
    if depth > 12 { return nil } // prevent infinite recursion

    let children = getChildren(element)
    let groupChildren = children.filter { getRole($0) == "AXGroup" }

    // Check if this element's children contain a sidebar + chat split
    if groupChildren.count >= 2 {
        var sizes: [(AXUIElement, CGSize)] = []
        for child in groupChildren {
            sizes.append((child, getSize(child)))
        }

        // Look for a child that's narrower than the window (potential sidebar)
        // and a sibling that's wider (the chat area)
        for i in 0..<sizes.count {
            let (candidate, candidateSize) = sizes[i]
            let isNarrow = candidateSize.width >= 50 && candidateSize.width < windowWidth * 0.5
            let hasTallHeight = candidateSize.height > 400

            if isNarrow && hasTallHeight {
                // Check if there's a wider sibling
                let hasWiderSibling = sizes.contains { $0.1.width > candidateSize.width && $0.1.height > 400 }
                if hasWiderSibling {
                    let pos = getPos(candidate)
                    return SidebarInfo(
                        sidebar: candidate,
                        width: candidateSize.width,
                        position: pos,
                        height: candidateSize.height
                    )
                }
            }
        }
    }

    // Recurse into children
    for child in groupChildren {
        if let result = findSidebar(in: child, windowWidth: windowWidth, depth: depth + 1) {
            return result
        }
    }

    return nil
}

func simulateDrag(from start: CGPoint, to end: CGPoint) {
    // Save cursor position, then freeze cursor in place during drag
    let savedCursor = NSEvent.mouseLocation
    let screenHeight = NSScreen.main?.frame.height ?? 0
    let savedPoint = CGPoint(x: savedCursor.x, y: screenHeight - savedCursor.y)
    CGAssociateMouseAndMouseCursorPosition(boolean_t(0))

    guard let down = CGEvent(mouseEventSource: nil, mouseType: .leftMouseDown, mouseCursorPosition: start, mouseButton: .left) else {
        CGAssociateMouseAndMouseCursorPosition(boolean_t(1))
        return
    }
    down.post(tap: .cghidEventTap)
    // usleep(50)

    let steps = 5
    for i in 1...steps {
        let t = CGFloat(i) / CGFloat(steps)
        let pt = CGPoint(x: start.x + (end.x - start.x) * t, y: start.y + (end.y - start.y) * t)
        if let drag = CGEvent(mouseEventSource: nil, mouseType: .leftMouseDragged, mouseCursorPosition: pt, mouseButton: .left) {
            drag.post(tap: .cghidEventTap)
        }
        usleep(8000)
    }

    // usleep(50)
    if let up = CGEvent(mouseEventSource: nil, mouseType: .leftMouseUp, mouseCursorPosition: end, mouseButton: .left) {
        up.post(tap: .cghidEventTap)
    }

    // Warp mouse back to original position, then re-associate (cursor snaps to mouse)
    CGWarpMouseCursorPosition(savedPoint)
    CGAssociateMouseAndMouseCursorPosition(boolean_t(1))
}

// Main
guard let app = NSWorkspace.shared.runningApplications.first(where: { $0.localizedName == "Messages" }) else {
    print("Messages not running"); exit(1)
}

let appEl = AXUIElementCreateApplication(app.processIdentifier)
var winsRef: CFTypeRef?
guard AXUIElementCopyAttributeValue(appEl, kAXWindowsAttribute as CFString, &winsRef) == .success,
      let wins = winsRef as? [AXUIElement], let win = wins.first else {
    print("No Messages window"); exit(1)
}

let winPos = getPos(win)
let winSize = getSize(win)
print("Window: pos=\(Int(winPos.x)),\(Int(winPos.y)) size=\(Int(winSize.width))x\(Int(winSize.height))")

guard let info = findSidebar(in: win, windowWidth: winSize.width) else {
    print("Could not find sidebar element"); exit(1)
}

print("Sidebar found: pos=\(Int(info.position.x)),\(Int(info.position.y)) size=\(Int(info.width))x\(Int(info.height))")

let splitterX = info.position.x + info.width
let dragY = info.position.y + info.height / 2
let minWidth: CGFloat = 94
let targetWidth: CGFloat = 320
let threshold: CGFloat = (minWidth + targetWidth) / 2  // ~207

if info.width > threshold {
    // Sidebar is open -> collapse to minimum
    let endX = winPos.x + minWidth
    print("COLLAPSING: drag \(Int(splitterX)),\(Int(dragY)) -> \(Int(endX)),\(Int(dragY))")
    simulateDrag(from: CGPoint(x: splitterX, y: dragY), to: CGPoint(x: endX, y: dragY))
} else {
    // Sidebar is collapsed -> expand
    let endX = winPos.x + targetWidth
    print("EXPANDING: drag \(Int(splitterX)),\(Int(dragY)) -> \(Int(endX)),\(Int(dragY))")
    simulateDrag(from: CGPoint(x: splitterX, y: dragY), to: CGPoint(x: endX, y: dragY))
}

print("Done!")
