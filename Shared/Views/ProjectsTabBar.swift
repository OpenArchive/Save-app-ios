//
//  ProjectsTabBar.swift
//  OpenArchive
//
//  Created by Benjamin Erhart on 29.01.19.
//  Copyright © 2019 Open Archive. All rights reserved.
//

import UIKit
import MaterialComponents.MaterialTabs
import YapDatabase
import Localize

protocol ProjectsTabBarDelegate {

    func didSelectAdd(_ tabBar: ProjectsTabBar)

    func didSelect(_ tabBar: ProjectsTabBar, project: Project)
}

class ProjectsTabBar: MDCTabBar, MDCTabBarDelegate {

    static let addTabItemTag = 666

    weak var connection: YapDatabaseConnection?

    var viewName: String?

    weak var mappings: YapDatabaseViewMappings?

    var projects = [Project]()

    var selectedProject: Project? {
        if let index = selectedItem?.tag,
            index < projects.count {
            return projects[index]
        }

        return nil
    }

    var projectsDelegate: ProjectsTabBarDelegate?

    /**
     Don't use this. This is effectively neutered and used for internal purposes!

     You just see this, because Swift doesn't allow us to reduce visibility of properties.
    */
    internal override var delegate: MDCTabBarDelegate? {
        get {
            return self
        }
        set {
            // Do nothing, this is effectively private.
        }
    }

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

    func addToSubview(_ view: UIView) {
        view.addSubview(self)

        translatesAutoresizingMaskIntoConstraints = false

        topAnchor.constraint(equalTo: view.topAnchor).isActive = true
        bottomAnchor.constraint(equalTo: view.bottomAnchor).isActive = true
        leadingAnchor.constraint(equalTo: view.leadingAnchor).isActive = true
        trailingAnchor.constraint(equalTo: view.trailingAnchor).isActive = true
    }

    func handle(_ change: YapDatabaseViewRowChange) {
        var insertedNew = false

        switch change.type {
        case .delete:
            if let indexPath = change.indexPath {
                projects.remove(at: indexPath.row)
                items.remove(at: indexPath.row + 1)
            }
        case .insert:
            if let newIndexPath = change.newIndexPath,
                let project = getProject(at: newIndexPath) {

                projects.insert(project, at: newIndexPath.row)
                items.insert(getItem(project.name, newIndexPath.row), at: newIndexPath.row + 1)

                // When a new project is created, it will be selected immediately.
                selectedItem = items[newIndexPath.row + 1]
                insertedNew = true
            }
        case .move:
            if let indexPath = change.indexPath, let newIndexPath = change.newIndexPath {
                projects.insert(projects.remove(at: indexPath.row), at: newIndexPath.row)
                items.insert(items.remove(at: indexPath.row + 1), at: newIndexPath.row + 1)
            }
        case .update:
            if let indexPath = change.indexPath,
                let project = getProject(at: indexPath) {

                projects[indexPath.row] = project
                items[indexPath.row + 1] = getItem(project.name, indexPath.row)
            }
        }

        // Always select a newly inserted project or fix situation when tab bar
        // was properly populated while the "+" tab is selected, which really
        // shouldn't.
        if insertedNew || selectFirst(),
            let selectedProject = selectedProject {
            projectsDelegate?.didSelect(self, project: selectedProject)
        }
    }


    // MARK: MDCTabBarDelegate

    func tabBar(_ tabBar: MDCTabBar, shouldSelect item: UITabBarItem) -> Bool {
        if item.tag == ProjectsTabBar.addTabItemTag {
            projectsDelegate?.didSelectAdd(self)

            return false
        }

        return true
    }

    func tabBar(_ tabBar: MDCTabBar, didSelect item: UITabBarItem) {
        if item.tag < projects.count {
            projectsDelegate?.didSelect(self, project: projects[item.tag])
        }
    }


    // MARK: Private Methods

    private func setup() {
        itemAppearance = .titles

        displaysUppercaseTitles = false

        setTitleColor(UIColor.gray, for: .normal)
        setTitleColor(UIColor.black, for: .selected)
        bottomDividerColor = UIColor.lightGray

        items.append(getItem("+".localize(), ProjectsTabBar.addTabItemTag))

        read { transaction in
            transaction.enumerateKeysAndObjects(inGroup: Project.collection) {
                collection, key, object, index, stop in

                if let project = object as? Project {
                    self.projects.append(project)
                    self.items.append(self.getItem(project.name, Int(index)))
                }
            }
        }

        _ = selectFirst()
    }

    private func read(_ callback: @escaping (_ transaction: YapDatabaseViewTransaction) -> Void) {
        connection?.read() { transaction in
            if let viewName = self.viewName,
                let viewTransaction = transaction.ext(viewName) as? YapDatabaseViewTransaction {
                callback(viewTransaction)
            }
        }
    }

    private func getItem(_ title: String?, _ tag: Int) -> UITabBarItem {
        return UITabBarItem(title: title, image: nil, tag: tag)
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

    private func selectFirst() -> Bool {
        if selectedItem?.tag == ProjectsTabBar.addTabItemTag && projects.count > 0 {
            selectedItem = items[1] // Add is on 0, first project on 1.

            return true
        }

        return false
    }
}
