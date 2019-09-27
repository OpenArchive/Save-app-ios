//
//  ProjectsTabBar.swift
//  OpenArchive
//
//  Created by Benjamin Erhart on 29.01.19.
//  Copyright © 2019 Open Archive. All rights reserved.
//

import UIKit
import YapDatabase
import Localize

protocol ProjectsTabBarDelegate {

    func didSelect(_ tabBar: ProjectsTabBar, project: Project)
}

class ProjectsTabBar: UIScrollView {

    weak var connection: YapDatabaseConnection?

    var viewName: String?

    weak var mappings: YapDatabaseViewMappings?

    var projectTabs = [ProjectTab]()

    var selectedProject: Project? {
        get {
            return projectTabs.first { $0.isSelected }?.project
        }
        set {
            for tab in projectTabs {
                tab.isSelected = newValue != nil && tab.project == newValue
            }
        }
    }

    var projectsDelegate: ProjectsTabBarDelegate?

    
    override init(frame: CGRect) {
        super.init(frame: frame)

        showsVerticalScrollIndicator = false
        showsHorizontalScrollIndicator = false
    }

    required init?(coder: NSCoder) {
        super.init(coder: coder)

        showsVerticalScrollIndicator = false
        showsHorizontalScrollIndicator = false
    }


    // MARK: Public Methods

    func handle(_ change: YapDatabaseViewRowChange) {
        var selectionUpdate = false

        switch change.type {
        case .delete:
            if let indexPath = change.indexPath {
                remove(at: indexPath.row)
            }
        case .insert:
            if let newIndexPath = change.newIndexPath,
                let project = getProject(at: newIndexPath) {

                insert(project, at: newIndexPath.row)

                // When a new project is created, it will be selected immediately.
                selectedProject = project
                selectionUpdate = true
            }
        case .move:
            if let indexPath = change.indexPath, let newIndexPath = change.newIndexPath {
                if let tab = remove(at: indexPath.row) {
                    insert(tab, at: newIndexPath.row)
                }
            }
        case .update:
            if let indexPath = change.indexPath,
                let project = getProject(at: indexPath) {

                update(project, at: indexPath.row)
            }
        @unknown default:
            break
        }

        if selectedProject == nil {
            projectTabs.first?.isSelected = true
            selectionUpdate = true
        }

        // Always select a newly inserted project or fix situation when tab bar
        // was properly populated while the "+" tab is selected, which really
        // shouldn't.
        if selectionUpdate,
            let selectedProject = selectedProject {
            projectsDelegate?.didSelect(self, project: selectedProject)
        }
    }

    func load() {
        read { transaction in
            transaction.enumerateKeysAndObjects(inGroup: Project.collection) {
                collection, key, object, index, stop in

                if let project = object as? Project {
                    if !self.projectTabs.contains(where: { $0.project == project }) {
                        self.insert(project, at: Int(index))

                        if self.selectedProject == nil {
                            self.selectedProject = project
                        }
                    }
                }
            }
        }
    }


    // MARK: Private Methods

    private func read(_ callback: @escaping (_ transaction: YapDatabaseViewTransaction) -> Void) {
        connection?.read() { transaction in
            if let viewName = self.viewName,
                let viewTransaction = transaction.ext(viewName) as? YapDatabaseViewTransaction {
                callback(viewTransaction)
            }
        }
    }

    private func getProject(at indexPath: IndexPath) -> Project? {
        var project: Project?

        if let mappings = mappings {
            read { transaction in
                project = transaction.object(at: indexPath, with: mappings) as? Project
            }
        }

        return project
    }

    @objc private func projectSelected(_ sender: ProjectTab) {
        var scrollX: CGFloat?

        if sender.frame.origin.x < contentOffset.x {
            // Scroll to right, if selected item is partly out of the left edge.
            scrollX = sender.frame.origin.x
        }
        else if sender.frame.origin.x + sender.frame.width > contentOffset.x + bounds.width {
            // Scroll to left, if selected item is partly out of the right edge,
            // but don't scroll further than to the beginning of the item, if
            // it's actually longer than the width of the scroll view.
            scrollX = sender.frame.origin.x + min(0, sender.frame.width - bounds.width)
        }

        // Scroll, if selected item is partly out of view.
        if let scrollX = scrollX {
            setContentOffset(CGPoint(x: scrollX, y: contentOffset.y), animated: true)
        }

        selectedProject = sender.project
        projectsDelegate?.didSelect(self, project: sender.project)
    }

    @discardableResult
    private func remove(at index: Int) -> ProjectTab? {
        guard index < projectTabs.count else {
            return nil
        }

        let tab = projectTabs.remove(at: index)

        tab.removeFromSuperview()

        // Fix layout constraint on next sibling.
        if index < projectTabs.count {
            projectTabs[index].setLeadingConstraint(index > 0 ? projectTabs[index - 1] : nil)
        }
        else {
            projectTabs.last?.trailingConstraintToSuperview?.isActive = true
        }

        return tab
    }

    private func insert(_ project: Project, at index: Int) {
        let tab = ProjectTab(project)
        tab.addTarget(self, action: #selector(projectSelected(_:)), for: .touchUpInside)

        insert(tab, at: index)
    }

    private func insert(_ tab: ProjectTab, at index: Int) {
        // Fix issue when multiple projects are inserted at once, which
        // happens on DB setup for screenshot creation.
        // NOTE: This will mess up the order with more than 2 projects at once!
        if index < projectTabs.count {
            projectTabs.insert(tab, at: index)
        }
        else {
            projectTabs.append(tab)
        }

        let newIndex = projectTabs.firstIndex(of: tab)!
        let leadingSibling = newIndex <= 0 ? nil : projectTabs[newIndex - 1]
        leadingSibling?.trailingConstraintToSuperview?.isActive = false

        tab.addToSuperview(self, leadingConstraintTo: leadingSibling)

        // Fix layout constraints on next sibling.
        if newIndex + 1 < projectTabs.count {
            projectTabs[newIndex + 1].setLeadingConstraint(tab)
        }
        else {
            tab.trailingConstraintToSuperview?.isActive = true
        }
    }

    private func update(_ project: Project, at index: Int) {
        if index < projectTabs.count {
            projectTabs[index].project = project
        }
        else {
            insert(project, at: index)
        }
    }
}
