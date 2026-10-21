import SwiftUI
import UIKit

/// The entire pack-selection screen is UIKit; SwiftUI owns its navigation.
struct PacksScreen: UIViewControllerRepresentable {
    @Bindable var model: AppViewModel
    func makeUIViewController(context: Context) -> PacksViewController { PacksViewController(model: model) }
    func updateUIViewController(_ controller: PacksViewController, context: Context) { controller.reload() }
}

final class PackCell: UICollectionViewCell {
    static let identifier = "pack"
    let titleLabel = UILabel(), subtitleLabel = UILabel(), icon = UIImageView(), check = UIImageView()
    override init(frame: CGRect) {
        super.init(frame: frame)
        contentView.layer.cornerRadius = 22
        let labels = UIStackView(arrangedSubviews: [titleLabel, subtitleLabel]); labels.axis = .vertical; labels.spacing = 5
        titleLabel.font = .preferredFont(forTextStyle: .headline); titleLabel.adjustsFontForContentSizeCategory = true
        subtitleLabel.font = .preferredFont(forTextStyle: .caption1); subtitleLabel.adjustsFontForContentSizeCategory = true
        titleLabel.numberOfLines = 2; subtitleLabel.numberOfLines = 2
        let row = UIStackView(arrangedSubviews: [icon, labels, check]); row.spacing = 16; row.alignment = .center
        row.translatesAutoresizingMaskIntoConstraints = false; contentView.addSubview(row)
        NSLayoutConstraint.activate([row.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 18), row.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -18), row.topAnchor.constraint(equalTo: contentView.topAnchor, constant: 18), row.bottomAnchor.constraint(equalTo: contentView.bottomAnchor, constant: -18), icon.widthAnchor.constraint(equalToConstant: 28), check.widthAnchor.constraint(equalToConstant: 24)])
        icon.contentMode = .scaleAspectFit; check.contentMode = .scaleAspectFit
        isAccessibilityElement = true
    }
    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }
    func configure(_ pack: WordPack, selected: Bool) {
        titleLabel.text = pack.title; subtitleLabel.text = pack.subtitle
        icon.image = UIImage(systemName: pack.symbol)
        check.image = UIImage(systemName: selected ? "checkmark.circle.fill" : "circle")
        contentView.backgroundColor = selected ? UIColor(named: "GamePink") : .white
        titleLabel.textColor = UIColor(named: "GameInk"); subtitleLabel.textColor = UIColor(named: "GameMuted")
        icon.tintColor = UIColor(named: "AccentColor"); check.tintColor = UIColor(named: "AccentColor")
        accessibilityLabel = "\(pack.title), \(pack.subtitle)"
        accessibilityTraits = selected ? [.button, .selected] : [.button]
        accessibilityHint = "Двойное касание меняет выбор набора"
    }
}

final class PacksViewController: UIViewController, UICollectionViewDataSource, UICollectionViewDelegate {
    private let model: AppViewModel
    private var collection: UICollectionView!
    private let continueButton = UIButton(type: .system)
    init(model: AppViewModel) { self.model = model; super.init(nibName: nil, bundle: nil) }
    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }
    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = UIColor(named: "GameBackground")
        let heading = UILabel(); heading.text = "Выберите наборы"; heading.font = .preferredFont(forTextStyle: .largeTitle); heading.numberOfLines = 0; heading.textColor = UIColor(named: "GameInk")
        let item = NSCollectionLayoutItem(layoutSize: .init(widthDimension: .fractionalWidth(1), heightDimension: .estimated(88)))
        let group = NSCollectionLayoutGroup.vertical(layoutSize: .init(widthDimension: .fractionalWidth(1), heightDimension: .estimated(88)), subitems: [item])
        let section = NSCollectionLayoutSection(group: group); section.interGroupSpacing = 12
        collection = UICollectionView(frame: .zero, collectionViewLayout: UICollectionViewCompositionalLayout(section: section))
        collection.backgroundColor = .clear; collection.dataSource = self; collection.delegate = self
        collection.register(PackCell.self, forCellWithReuseIdentifier: PackCell.identifier)
        let generate = UIButton(type: .system)
        generate.setTitle("＋ Своя тема с ИИ", for: .normal); generate.titleLabel?.font = .preferredFont(forTextStyle: .headline)
        generate.addTarget(self, action: #selector(createPack), for: .touchUpInside)
        continueButton.setTitle("Дальше", for: .normal); continueButton.backgroundColor = UIColor(named: "AccentColor"); continueButton.setTitleColor(.white, for: .normal); continueButton.layer.cornerRadius = 20; continueButton.titleLabel?.font = .preferredFont(forTextStyle: .headline)
        continueButton.addTarget(self, action: #selector(nextStep), for: .touchUpInside)
        let stack = UIStackView(arrangedSubviews: [heading, generate, collection, continueButton]); stack.axis = .vertical; stack.spacing = 16; stack.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(stack)
        NSLayoutConstraint.activate([stack.leadingAnchor.constraint(equalTo: view.safeAreaLayoutGuide.leadingAnchor, constant: 24), stack.trailingAnchor.constraint(equalTo: view.safeAreaLayoutGuide.trailingAnchor, constant: -24), stack.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor, constant: 8), stack.bottomAnchor.constraint(equalTo: view.safeAreaLayoutGuide.bottomAnchor, constant: -16), continueButton.heightAnchor.constraint(equalToConstant: 58), generate.heightAnchor.constraint(greaterThanOrEqualToConstant: 44)])
        reload()
    }
    override func viewWillAppear(_ animated: Bool) { super.viewWillAppear(animated); reload() }
    func reload() { guard isViewLoaded else { return }; collection.reloadData(); continueButton.isEnabled = !model.selectedPacks.isEmpty; continueButton.alpha = continueButton.isEnabled ? 1 : 0.4 }
    func collectionView(_ collectionView: UICollectionView, numberOfItemsInSection section: Int) -> Int { model.packs.count }
    func collectionView(_ collectionView: UICollectionView, cellForItemAt indexPath: IndexPath) -> UICollectionViewCell {
        let cell = collectionView.dequeueReusableCell(withReuseIdentifier: PackCell.identifier, for: indexPath) as! PackCell
        let pack = model.packs[indexPath.item]; cell.configure(pack, selected: model.selectedPacks.contains(pack.id)); return cell
    }
    func collectionView(_ collectionView: UICollectionView, didSelectItemAt indexPath: IndexPath) {
        let id = model.packs[indexPath.item].id
        if model.selectedPacks.contains(id) { model.selectedPacks.remove(id) } else { model.selectedPacks.insert(id) }
        UISelectionFeedbackGenerator().selectionChanged(); reload()
    }
    func collectionView(_ collectionView: UICollectionView, contextMenuConfigurationForItemAt indexPath: IndexPath, point: CGPoint) -> UIContextMenuConfiguration? {
        let pack = model.packs[indexPath.item]; guard pack.custom else { return nil }
        return UIContextMenuConfiguration(actionProvider: { [weak self] _ in UIMenu(children: [UIAction(title: "Удалить набор", attributes: .destructive) { _ in self?.model.deletePack(pack.id); self?.reload() }]) })
    }
    @objc private func createPack() { model.path.append(.generator) }
    @objc private func nextStep() { model.path.append(.teams) }
}
