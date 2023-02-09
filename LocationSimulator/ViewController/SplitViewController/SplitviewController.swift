//
//  SplitviewController.swift
//  LocationSimulator
//
//  Created by David Klopp on 23.12.20.
//  Copyright © 2020 David Klopp. All rights reserved.
//

import AppKit

enum SidebarStyle {
    /// The default sidebar style where the content behind the window is shown.
    case standard
    /// A sidebar style where the sidebar is drawn in front of the MapView.
    case inFrontOfMap

    var blendingMode: NSVisualEffectView.BlendingMode {
        switch self {
        case .standard: return .behindWindow
        case .inFrontOfMap: return .withinWindow
        }
    }

    var material: NSVisualEffectView.Material {
        switch self {
        case .standard: return .sidebar
        case .inFrontOfMap: return .titlebar
        }
    }
}

class SplitViewController: NSSplitViewController {
    @IBOutlet var sidebarSplitViewItem: NSSplitViewItem!

    /// A reference to the current detail view controller. This can be the `NoDeviceViewController` or the
    /// `MapViewController`. Use this variable to change the detailViewController.
    public var detailViewController: NSViewController? {
        get {
            let items = self.splitViewItems
            return items.count >= 2 ? items[1].viewController : nil
        }

        set (newValue) {
            var items = self.splitViewItems
            if let viewController = newValue {
                // Load a new detail view controller.
                let detailedItem = NSSplitViewItem(viewController: viewController)
                if items.count < 2 {
                    items.append(detailedItem)
                } else {
                    items[1] = detailedItem
                }
                self.splitViewItems = items

                // Show the MapView behind the sidebar if we got a MapView
                if viewController as? MapViewController != nil {
                    self.apply(sidebarStyle: .inFrontOfMap, forDetailViewController: viewController)
                } else {
                    self.apply(sidebarStyle: .standard, forDetailViewController: viewController)
                }
            } else {
                // nil => remove the detail view controller.
                self.splitViewItems = items.dropLast()
            }
        }
    }

    /// Readonly sidebar view controller
    public var sidebarViewController: NSViewController? {
        let items = self.splitViewItems
        return items.count >= 1 ? items[0].viewController : nil
    }

    /// True if the sidebar is collapse, false otherwise.
    public private(set) var isSidebarCollapsed: Bool = false

    // MARK: - View Life Cycle

    override func viewDidLoad() {
        super.viewDidLoad()

        self.view.wantsLayer = true

        // Configure the sidebar width.
        if #available(OSX 11.0, *) {
            self.sidebarSplitViewItem.allowsFullHeightLayout = true
            self.sidebarSplitViewItem.titlebarSeparatorStyle = .none
        }
        self.sidebarSplitViewItem.minimumThickness = 150
        self.sidebarSplitViewItem.maximumThickness = 250
    }

    /// Apply a specific custom style to the sidebar.
    /// Note: This functions is obsolete if Apple provides a default way to overlay a sidebar.
    /// - Parameter style: the style to apply to the sidebar
    /// - Parameter forDetailViewController: the current detailViewController
    private func apply(sidebarStyle: SidebarStyle, forDetailViewController detailViewController: NSViewController) {
        guard let mapViewController = detailViewController as? MapViewController,
              let mapView = mapViewController.mapView else {
            return
        }

        guard #available(OSX 11.0, *) else {
            // Only fill the detailViewController on catalina and below
            // Note: MapView has no leading constraint defined in interface builder at compile time
            let leading = mapView.leadingAnchor.constraint(equalTo: detailViewController.view.leadingAnchor)
            leading.isActive = true
            return
        }

        // Change the effectView to our liking
        let effectView = self.sidebarViewController?.view.superview as? NSVisualEffectView
        effectView?.blendingMode = sidebarStyle.blendingMode
        effectView?.material = sidebarStyle.material

        // configure the mapView to always fill the complete splitView
        let leading = mapView.leadingAnchor.constraint(equalTo: self.splitView.leadingAnchor)
        leading.isActive = true

        // Allow drawing out of bounds
        var superView: NSView? = mapView
        while superView != nil {
            superView?.wantsLayer = true
            superView?.layer?.masksToBounds = false
            superView = superView?.superview
        }

        // Reverse the ordering of the splitView items viewController to position detailViewController behind  siderbar
        self.splitView.sortSubviews({ (view1, view2, _) in
            let splitView = view1.superview as? NSSplitView
            let arrangedViews = splitView?.arrangedSubviews
            if view1 == arrangedViews?.first && view2 == arrangedViews?.last {
                return .orderedDescending
            }
            return .orderedAscending
        }, context: nil)
    }

    // MARK: - Toggle Sidebar

    public override func toggleSidebar(_ sender: Any?) {
        self.isSidebarCollapsed = !self.isSidebarCollapsed

        super.toggleSidebar(nil)
    }

    public func toggleSidebar() {
        self.toggleSidebar(nil)
    }

    // MARK: - NSSplitViewDelegate

    override func splitView(_ splitView: NSSplitView, canCollapseSubview subview: NSView) -> Bool {
        return false
    }
}
