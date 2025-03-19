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
    
    func pushPrivateServerSetting(space: Space)
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
            serverNameLbl.text = newValue?.prettyName ?? Bundle.main.displayName
        }
    }


    @IBOutlet weak var header: UIView! {
        didSet {
            header.accessibilityIdentifier = "viewHeader"
        }
    }

    @IBOutlet weak var serverNameLbl: UILabel! {
        didSet {
            serverNameLbl.text = NSLocalizedString("Servers", comment: "")
            serverNameLbl.font = .montserrat(forTextStyle: .callout, with: .traitUIOptimized)
            
        }
    }
    @IBOutlet weak var toggleIcon: UIImageView!
    @IBOutlet weak var spacesTable: UITableView!

    @IBOutlet weak var spaceIcon: UIImageView!
    @IBOutlet weak var spaceLb: UILabel!

    @IBOutlet weak var projectsTable: UITableView!

    @IBOutlet weak var menuContentWidth: NSLayoutConstraint! {
        didSet {
            menuContentWidth.constant = 0
        }
    }

    @IBOutlet weak var addFolderBt: UIButton! {
        didSet {
            addFolderBt.titleLabel?.font = .montserrat(forTextStyle: .headline, with: .traitUIOptimized)
            addFolderBt.titleLabel?.text = NSLocalizedString("New Folder", comment: "")
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
            cell.accessibilityIdentifier = "cellAddAccount"
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
        if spacesTable.isHidden {
            spacesTable.alpha = 0
            spacesTable.isHidden = false

            UIView.animate(withDuration: 0.25) {
                self.spacesTable.alpha = 1
                self.spacesTable.superview?.layoutIfNeeded()
            }

            setToggleIcon(true)
        }
        else {
            UIView.animate(withDuration: 0.25, animations: {
                self.spacesTable.layer.opacity = 0
                self.spacesTable.superview?.layoutIfNeeded()
            }) { _ in
                self.spacesTable.isHidden = true
                self.spacesTable.alpha = 1
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
                self.spacesTable.alpha = 0
                self.setToggleIcon(false)

                self.view.layoutIfNeeded()
            }) { finished in
                completion?(finished)

                self.view.alpha = 1
                self.spacesTable.isHidden = true
                self.spacesTable.alpha = 1
            }
        }
    }


    // MARK: Observers

    /**
     Callback for `YapDatabaseModified` and `YapDatabaseModifiedExternally` notifications.

     Shall be called, when something changes the database.
     */
    @objc func yapDatabaseModified(notification: Notification) {
        if spacesConn?.hasChanges(spacesMappings) ?? false {
            
            spacesTable.reloadData()
            serverNameLbl.text = SelectedSpace.space?.prettyName ?? ""
        }
    }


    // MARK: Private Methods

    private func getProject(at indexPath: IndexPath) -> Project? {
        projectsConn?.object(at: indexPath, in: projectsMappings)
    }

    private func contains(project: Project?) -> Bool {
        projectsConn?.indexPath(of: project, with: projectsMappings) != nil
    }

    private func getSpace(at indexPath: IndexPath) -> Space? {
        spacesConn?.object(at: indexPath, in: spacesMappings)
    }

    private func setToggleIcon(_ toggle: Bool) {
        toggleIcon.image = UIImage(systemName: toggle ? "chevron.up" : "chevron.down")
    }
}
