//
//  ViewController.swift
//  MainActorTest
//
//  Created by SallyXie on 2023/11/8.
//

import UIKit
import Combine

class ViewController: UIViewController {
    @IBOutlet weak var dataLabel: UILabel!

    var cancellable: AnyCancellable? = nil

    override func viewDidLoad() {
        super.viewDidLoad()
        // 沒回Main thread -> crash
//        self.fetchAPI()
        
        
        // 沒回Main thread -> OK
        // 使用 Task 來呼叫 async 函數
        Task {
            await self.asyncFetchAPI()
        }
        
        
        // 沒回Main thread -> crash
//        self.combineFetchAPI()
    }
    
    @MainActor private func updateUI(name: String) {
        self.dataLabel.text = name
    }

    func fetchAPI() {
        guard let url = URL(string: "https://dimanyen.github.io/man.json") else {
            return
        }

        let session = URLSession.shared
        let task = session.dataTask(with: url) { [weak self] data, response, error in
            guard let self = self else { return }

            if let error = error {
                print("Error: \(error.localizedDescription)")
                return
            }

            if let data = data,
               let resultModel = try? JSONDecoder().decode(UserInfoRes.self, from: data) {
                guard let firstData = resultModel.response.first else {
                    return
                }
                // 沒回Main thread -> crash
                self.updateUI(name: firstData.name)
            }
        }

        task.resume()
    }

    func asyncFetchAPI() async {
        guard let url = URL(string: "https://dimanyen.github.io/man.json") else {
            return
        }

        do {
            let (data, _) = try await URLSession.shared.data(from: url)

            let resultModel = try JSONDecoder().decode(UserInfoRes.self, from: data)
            guard let firstData = resultModel.response.first else {
                return
            }
            // 沒回Main thread -> OK
            self.updateUI(name: firstData.name)
        }
        catch {
            print("Error: \(error.localizedDescription)")
        }
    }

    func combineFetchAPI() {
        guard let url = URL(string: "https://dimanyen.github.io/man.json") else {
            return
        }

        self.cancellable = URLSession.shared.dataTaskPublisher(for: url)
            .tryMap { element -> Data in
                guard let httpResponse = element.response as? HTTPURLResponse,
                      httpResponse.statusCode == 200 else {
                    throw URLError(.badServerResponse)
                }
                return element.data
            }
            .decode(type: UserInfoRes.self, decoder: JSONDecoder())
            .sink(receiveCompletion: {
                print("Received completion: \($0).")
            }, receiveValue: { model in
                let firstData = model.response.first!
                // 沒回Main thread -> crash
                self.updateUI(name: firstData.name)
            })
    }
}

public struct UserInfoRes: Decodable {
    public let response: [UserInfo]
}

public struct UserInfo: Decodable {
    public let name: String
    public let kokoid: String
}
