import UIKit

public class StickerCollectionController: UICollectionViewController {
    let stickers = [
        UIImage(named: "sticker1"),
        UIImage(named: "sticker2"),
        UIImage(named: "sticker3"),
        UIImage(named: "sticker4"),
        UIImage(named: "sticker5"),
        UIImage(named: "sticker6")
    ]

    init() {
        let layout = UICollectionViewCompositionalLayout { index, environment in
            let itemSize = NSCollectionLayoutSize(
                widthDimension:  .fractionalWidth(1.0 / 2.0),
                heightDimension: .fractionalWidth(1.0 / 2.0)
            )

            let item = NSCollectionLayoutItem(layoutSize: itemSize)
            item.contentInsets = NSDirectionalEdgeInsets(uniform: 5.0)

            let groupSize = NSCollectionLayoutSize(
                widthDimension:  .fractionalWidth(1.0),
                heightDimension: .estimated(100)
            )

            let group = NSCollectionLayoutGroup.horizontal(
                layoutSize: groupSize,
                subitems: [item]
            )

            let section = NSCollectionLayoutSection(group: group)

            return section
        }

        super.init(collectionViewLayout: layout)

        collectionView.alwaysBounceVertical = true
        collectionView.backgroundColor = .secondarySystemGroupedBackground
        collectionView.register(StickerCell.self, forCellWithReuseIdentifier: StickerCell.reuseIdentifier)

        title = "Stickers"
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    public override func collectionView(_ collectionView: UICollectionView, numberOfItemsInSection section: Int) -> Int {
        stickers.count
    }

    public override func collectionView(_ collectionView: UICollectionView, cellForItemAt indexPath: IndexPath) -> UICollectionViewCell {
        let cell = collectionView.dequeueReusableCell(withReuseIdentifier: StickerCell.reuseIdentifier, for: indexPath) as! StickerCell

        cell.image = stickers[indexPath.item]
        cell.addInteraction(PeelOffInteraction())

        return cell
    }
}

public final class StickerCell: UICollectionViewCell {
    static let reuseIdentifier = "StickerCell"

    public var image: UIImage? {
        get {
            imageView.image
        }
        set {
            imageView.image = newValue
        }
    }

    let imageView: UIImageView

    override init(frame: CGRect) {
        imageView = UIImageView()
        imageView.contentMode = .scaleAspectFit

        super.init(frame: frame)

        contentView.addSubview(imageView)
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    public override func prepareForReuse() {
        imageView.image = nil
    }

    public override func layoutSubviews() {
        super.layoutSubviews()

        imageView.frame = contentView.bounds
    }
}
