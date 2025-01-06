import UIKit

class SelectFolderTypeViewController: UIViewController {

    private let subtitleLb: UILabel = {
        let label = UILabel()
        label.text = NSLocalizedString("Select where to store your media.", comment: "")
        label.font = UIFont.systemFont(ofSize: 16, weight: .regular)
        label.textAlignment = .center
        label.numberOfLines = 0
        label.translatesAutoresizingMaskIntoConstraints = false
        return label
    }()

    private lazy var createNewView: UIView = {
        let view = createOptionView(title: NSLocalizedString("Create a New Folder", comment: ""), iconName: "folder.badge.plus", action: #selector(createNew))
        return view
    }()

    private lazy var browseView: UIView = {
        let view = createOptionView(title: NSLocalizedString("Browse Existing Folders", comment: ""), iconName: "folder", action: #selector(browse))
        return view
    }()

    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = UIColor.systemBackground

        setupNavigationBar()
        setupUI()

    }

    private func setupNavigationBar() {
        navigationItem.title = NSLocalizedString("Add a Folder", comment: "")
        let backButton = UIBarButtonItem(image: UIImage(systemName: "chevron.backward"), style: .plain, target: self, action: #selector(dismissController))
        navigationItem.leftBarButtonItem = backButton
    }

    private func setupUI() {
        view.addSubview(subtitleLb)
        view.addSubview(createNewView)
        view.addSubview(browseView)

        NSLayoutConstraint.activate([
            subtitleLb.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor, constant: 20),
            subtitleLb.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 16),
            subtitleLb.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -16)
        ])

        NSLayoutConstraint.activate([
            createNewView.topAnchor.constraint(equalTo: subtitleLb.bottomAnchor, constant: 32),
            createNewView.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 16),
            createNewView.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -20),
            createNewView.heightAnchor.constraint(equalToConstant: 50)
        ])

        NSLayoutConstraint.activate([
            browseView.topAnchor.constraint(equalTo: createNewView.bottomAnchor, constant: 16),
            browseView.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 16),
            browseView.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -20),
            browseView.heightAnchor.constraint(equalTo: createNewView.heightAnchor)
        ])
    }

    private func createOptionView(title: String, iconName: String, action: Selector) -> UIView {
        let container = UIView()
        container.translatesAutoresizingMaskIntoConstraints = false

        let icon = UIImageView(image: UIImage(systemName: iconName))
        icon.tintColor = .systemGray
        icon.translatesAutoresizingMaskIntoConstraints = false

        let label = UILabel()
        label.text = title
        label.font = UIFont.systemFont(ofSize: 16, weight: .regular)
        label.translatesAutoresizingMaskIntoConstraints = false

        let arrow = UIImageView(image: UIImage(systemName: "chevron.right"))
        arrow.tintColor = .systemGray
        arrow.translatesAutoresizingMaskIntoConstraints = false

        let button = UIButton()
        button.addTarget(self, action: action, for: .touchUpInside)
        button.translatesAutoresizingMaskIntoConstraints = false

        container.addSubview(icon)
        container.addSubview(label)
        container.addSubview(arrow)
        container.addSubview(button)

        NSLayoutConstraint.activate([
            icon.centerYAnchor.constraint(equalTo: container.centerYAnchor),
            icon.leadingAnchor.constraint(equalTo: container.leadingAnchor, constant: 16),
            icon.widthAnchor.constraint(equalToConstant: 24),
            icon.heightAnchor.constraint(equalToConstant: 24),

            label.centerYAnchor.constraint(equalTo: container.centerYAnchor),
            label.leadingAnchor.constraint(equalTo: icon.trailingAnchor, constant: 8),

            arrow.centerYAnchor.constraint(equalTo: container.centerYAnchor),
            arrow.trailingAnchor.constraint(equalTo: container.trailingAnchor, constant: -16),

            button.topAnchor.constraint(equalTo: container.topAnchor),
            button.bottomAnchor.constraint(equalTo: container.bottomAnchor),
            button.leadingAnchor.constraint(equalTo: container.leadingAnchor),
            button.trailingAnchor.constraint(equalTo: container.trailingAnchor)
        ])

        return container
    }

    // MARK: - Actions
    @objc private func dismissController() {
        navigationController?.popViewController(animated: true)
    }

    @objc private func createNew() {
          if var viewControllers = navigationController?.viewControllers {
              viewControllers.removeLast()
              viewControllers.append(AddFolderNewViewController(Project(space: SelectedSpace.space)))
              navigationController?.setViewControllers(viewControllers, animated: true)
          }
      }

    @objc func browse() {
        if var viewControllers = navigationController?.viewControllers {
            viewControllers.removeLast()
            viewControllers.append(BrowseViewController())
            navigationController?.setViewControllers(viewControllers, animated: true)
        }}
}
