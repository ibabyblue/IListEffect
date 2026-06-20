import UIKit
import ListEffectUIKit
import ListEffectCore

final class TableDemoViewController: UITableViewController {
    private let colors: [UIColor] = [.systemRed, .systemOrange, .systemGreen, .systemBlue, .systemPurple]

    override func viewDidLoad() {
        super.viewDidLoad()
        title = "Springy (Tracking)"
        tableView.rowHeight = 64
        tableView.register(UITableViewCell.self, forCellReuseIdentifier: "c")
        tableView.listEffect.attach(SpringyEffect(stiffness: 2400))
    }

    override func tableView(_ t: UITableView, numberOfRowsInSection s: Int) -> Int { 50 }

    override func tableView(_ t: UITableView, cellForRowAt i: IndexPath) -> UITableViewCell {
        let cell = t.dequeueReusableCell(withIdentifier: "c", for: i)
        cell.backgroundColor = colors[i.row % colors.count].withAlphaComponent(0.85)
        cell.textLabel?.text = "Row #\(i.row)"
        return cell
    }
}
