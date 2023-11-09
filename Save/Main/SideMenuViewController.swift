//
//  SideMenuViewController.swift
//  Save
//
//  Created by Benjamin Erhart on 26.09.23.
//  Copyright © 2023 Open Archive. All rights reserved.
//

import UIKit
import YapDatabase

protocol SideMenuDelegate {

    func hideMenu()

    func selected(project: Project?)

    func addSpace()

    func addFolder()
}

class SideMenuViewController: UIViewController, UITableViewDataSource, UITableViewDelegate {

    var delegate: SideMenuDelegate?

    var projectsConn: YapDatabaseConnection?

    var projectsMappings: YapDatabaseViewMappings?

    private var _selectedProject: Project?
    var selectedProject: Project? {
        get {
            _selectedProject ?? getProject(at: IndexPath(row: 0, section: 0))
        }
        set {
            _selectedProject = newValue
        }
    }

    var space: Space? {
        get {
            nil
        }
        set {
            spaceIcon.image = newValue?.favIcon ?? SelectedSpace.defaultFavIcon
            spaceLb.text = newValue?.prettyName ?? Bundle.main.displayName
        }
    }


    @IBOutlet weak var spaceIcon: UIImageView!
    @IBOutlet weak var spaceLb: UILabel!
    @IBOutlet weak var toggleIcon: UIImageView!
    @IBOutlet weak var spacesTable: UITableView!

    @IBOutlet weak var spacesTableHeight: NSLayoutConstraint! {
        didSet {
            spacesTableHeight.constant = 0
        }
    }

    @IBOutlet weak var projectsTable: UITableView!

    @IBOutlet weak var menuContentWidth: NSLayoutConstraint! {
        didSet {
            menuContentWidth.constant = 0
        }
    }

    @IBOutlet weak var newFolderBt: UIButton! {
        didSet {
            newFolderBt.setTitle(NSLocalizedString("New Folder", comment: ""))
        }
    }


    private var spacesConn = Db.newLongLivedReadConn()

    private var spacesMappings = YapDatabaseViewMappings(
        groups: SpacesView.groups, view: SpacesView.name)


    init() {
        super.init(nibName: String(describing: type(of: self)), bundle: nil)
    }
    
    required init?(coder: NSCoder) {
        super.init(coder: coder)
    }
    


    override func viewDidLoad() {
        super.viewDidLoad()

        spacesTable.register(SideMenuItemCell.nib, forCellReuseIdentifier: SideMenuItemCell.reuseId)
        projectsTable.register(SideMenuItemCell.nib, forCellReuseIdentifier: SideMenuItemCell.reuseId)

        Db.add(observer: self, #selector(yapDatabaseModified))
    }



    // MARK: UITableViewDataSource

    func numberOfSections(in tableView: UITableView) -> Int {
        if tableView == projectsTable {
            return Int(projectsMappings?.numberOfSections() ?? 0)
        }

        return Int(spacesMappings.numberOfSections()) + 1
    }

    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        if tableView == projectsTable {
            return Int(projectsMappings?.numberOfItems(inSection: UInt(section)) ?? 0)
        }

        // "Add Another Account" button.
        if section >= spacesMappings.numberOfSections() {
            return 1
        }

        return Int(spacesMappings.numberOfItems(inSection: UInt(section)))
    }

    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(withIdentifier: SideMenuItemCell.reuseId, for: indexPath) as! SideMenuItemCell

        if tableView == projectsTable {
            let project = getProject(at: indexPath)

            cell.apply(project, select: selectedProject == project)
        }
        else if indexPath.section >= spacesMappings.numberOfSections() {
            cell.applyAdd()
        }
        else {
            let space = getSpace(at: indexPath)
            cell.apply(space, select: SelectedSpace.id == space?.id)
        }

        return cell
    }


    // MARK: UITableViewDelegate

    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        if tableView == projectsTable {
            selectedProject = getProject(at: indexPath)

            delegate?.selected(project: selectedProject)

            DispatchQueue.main.asyncAfter(deadline: .now() + 1) {
                tableView.deselectRow(at: indexPath, animated: false)
            }
        }
        else if indexPath.section >= spacesMappings.numberOfSections() {
            delegate?.addSpace()
        }
        else {
            SelectedSpace.space = getSpace(at: indexPath)
            SelectedSpace.store()

            selectedProject = getProject(at: IndexPath(row: 0, section: 0))

            delegate?.hideMenu()
        }
    }


    // MARK: Actions

    @IBAction func hide() {
        delegate?.hideMenu()
    }

    @IBAction func toggleSpaces() {
        if spacesTableHeight.constant <= 0 {
            let height = spacesTable.contentSize.height
                + spacesTable.contentInset.top
                + spacesTable.contentInset.bottom

            UIView.animate(withDuration: 0.25) {
                self.spacesTableHeight.constant = height
                self.spacesTable.superview?.layoutIfNeeded()
            }

            setToggleIcon(true)
        }
        else {
            UIView.animate(withDuration: 0.25) {
                self.spacesTableHeight.constant = 0
                self.spacesTable.superview?.layoutIfNeeded()
            }

            setToggleIcon(false)
        }
    }

    @IBAction func newFolder() {
        delegate?.addFolder()
    }


    // MARK: Public Methods

    func reload() {
        if !contains(project: selectedProject) {
            selectedProject = getProject(at: IndexPath(row: 0, section: 0))
        }

        projectsTable.reloadData()
    }

    func animate(_ toggle: Bool, _ completion: ((_ finished: Bool) -> Void)? = nil) {
        if toggle {
            view.alpha = 0

            UIView.animate(withDuration: 0.25, animations: {
                self.view.alpha = 1
                self.menuContentWidth.constant = 240
                self.view.layoutIfNeeded()
            }, completion: completion)
        }
        else {
            UIView.animate(withDuration: 0.25, animations: {
                self.view.alpha = 0
                self.menuContentWidth.constant = 0
                self.spacesTableHeight.constant = 0
                self.setToggleIcon(false)

                self.view.layoutIfNeeded()
            }) { finished in
                completion?(finished)

                self.view.alpha = 1
            }
        }
    }


    // MARK: Observers

    /**
     Callback for `YapDatabaseModified` and `YapDatabaseModifiedExternally` notifications.

     Shall be called, when something changes the database.
     */
    @objc func yapDatabaseModified(notification: Notification) {
        guard let notifications = spacesConn?.beginLongLivedReadTransaction(),
            let viewConn = spacesConn?.ext(SpacesView.name) as? YapDatabaseViewConnection else {
            return
        }

        if !spacesMappings.isNextSnapshot(notifications) || viewConn.hasChanges(for: notifications) {
            spacesConn?.update(mappings: spacesMappings)

            spacesTable.reloadData()
        }
    }


    // MARK: Private Methods

    private func getProject(at indexPath: IndexPath) -> Project? {
        guard let mappings = projectsMappings else {
            return nil
        }

        var project: Project?

        projectsConn?.readInView(mappings.view) { transaction, _ in
            project = transaction?.object(at: indexPath, with: mappings) as? Project
        }

        return project
    }

    private func contains(project: Project?) -> Bool {
        guard let project = project, let mappings = projectsMappings else {
            return false
        }

        var found = false

        projectsConn?.readInView(mappings.view) { transaction, _ in
            found = transaction?.indexPath(forKey: project.id, inCollection: Project.collection, with: mappings) != nil
        }

        return found
    }

    private func getSpace(at indexPath: IndexPath) -> Space? {
        var space: Space?

        spacesConn?.readInView(SpacesView.name) { transaction, _ in
            space = transaction?.object(at: indexPath, with: self.spacesMappings) as? Space
        }

        return space
    }

    private func setToggleIcon(_ toggle: Bool) {
        toggleIcon.image = UIImage(systemName: toggle ? "chevron.up" : "chevron.down")
    }
}
