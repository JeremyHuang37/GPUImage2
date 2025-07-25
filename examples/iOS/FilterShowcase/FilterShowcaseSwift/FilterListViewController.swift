import UIKit

class FilterListViewController: UITableViewController {
    var filterDisplayViewController: FilterDisplayViewController?
    var objects = NSMutableArray()

    // #pragma mark - Segues

    override func prepare(for segue: UIStoryboardSegue, sender: Any?) {
        if segue.identifier == "showDetail" {
            if let indexPath = self.tableView.indexPathForSelectedRow {
                let filterInList = filterOperations[(indexPath as NSIndexPath).row]
                (segue.destination as! FilterDisplayViewController).filterOperation = filterInList
            }
        }

    }

    // #pragma mark - Table View

    override func numberOfSections(in tableView: UITableView) -> Int {
        return 1
    }

    override func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return filterOperations.count
    }

    override func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(withIdentifier: "Cell", for: indexPath)

        let filterInList: FilterOperationInterface = filterOperations[(indexPath as NSIndexPath).row]
        cell.textLabel?.text = filterInList.listName
        return cell
    }
    
    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
//        tableView.selectRow(at: IndexPath(row: 0, section: 0), animated: true, scrollPosition: .none)
//        performSegue(withIdentifier: "showDetail", sender: nil)
    }
}
