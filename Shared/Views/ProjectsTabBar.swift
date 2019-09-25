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

    func didSelectAdd(_ tabBar: ProjectsTabBar)

    func didSelect(_ tabBar: ProjectsTabBar, project: Project)
}

class ProjectsTabBar: UIView {

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

    private lazy var addBt: UIButton = {
        let bt = UIButton(type: .contactAdd)
        bt.addTarget(self, action: #selector(add), for: .touchUpInside)

        bt.translatesAutoresizingMaskIntoConstraints = false

        addSubview(bt)

        bt.leadingAnchor.constraint(equalTo: self.leadingAnchor).isActive = true
        bt.centerYAnchor.constraint(equalTo: self.centerYAnchor).isActive = true

        return bt
    }()

    private lazy var container: UIScrollView = {
        let container = UIScrollView(frame: .zero)

        container.showsVerticalScrollIndicator = false
        container.showsHorizontalScrollIndicator = false

        container.translatesAutoresizingMaskIntoConstraints = false

        addSubview(container)

        container.leadingAnchor.constraint(equalTo: addBt.trailingAnchor, constant: 8).isActive = true
        container.trailingAnchor.constraint(equalTo: trailingAnchor).isActive = true
        container.topAnchor.constraint(equalTo: topAnchor).isActive = true
        container.bottomAnchor.constraint(equalTo: bottomAnchor).isActive = true

        return container
    }()

    init(frame: CGRect, _ connection: YapDatabaseConnection?, viewName: String,
         _ mappings: YapDatabaseViewMappings) {
        
        self.connection = connection
        self.viewName = viewName
        self.mappings = mappings

        super.init(frame: frame)

        setup()
    }

    required init?(coder: NSCoder) {
        super.init(coder: coder)

        setup()
    }


    // MARK: Public Methods

    func addToSuperview(_ view: UIView) {
        translatesAutoresizingMaskIntoConstraints = false

        view.addSubview(self)

        topAnchor.constraint(equalTo: view.topAnchor).isActive = true
        bottomAnchor.constraint(equalTo: view.bottomAnchor).isActive = true
        leadingAnchor.constraint(equalTo: view.leadingAnchor).isActive = true
        trailingAnchor.constraint(equalTo: view.trailingAnchor).isActive = true
    }

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


    // MARK: Private Methods

    private func setup() {
        // Trigger lazy creators.
        _ = container

        read { transaction in
            transaction.enumerateKeysAndObjects(inGroup: Project.collection) {
                collection, key, object, index, stop in

                if let project = object as? Project {
                    self.insert(project, at: Int.max)

                    if self.selectedProject == nil {
                        self.selectedProject = project
                    }
                }
            }
        }
    }

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

    @objc private func add() {
        projectsDelegate?.didSelectAdd(self)
    }

    @objc private func projectSelected(_ sender: ProjectTab) {
        if sender.frame.origin.x < container.contentOffset.x
            || sender.frame.origin.x + sender.frame.width > container.contentOffset.x + container.bounds.width {

            container.setContentOffset(CGPoint(x: sender.frame.origin.x, y: container.contentOffset.y), animated: true)
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

        tab.addToSuperview(container, leadingConstraintTo: leadingSibling)

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
