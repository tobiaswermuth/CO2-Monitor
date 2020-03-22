//
//  SlackSender.swift
//  CO2 Monitor
//
//  Created by Tobias Wermuth on 15.03.20.
//  Copyright © 2020 Tobias Wermuth. All rights reserved.
//

import Foundation

class SlackSender {
  private let hook: String
  
  init(hook: String) {
    self.hook = hook
  }
  
  func sendMessage(text: String) {
    let url = URL(string: hook)
    guard let requestUrl = url else { fatalError() }
    // Prepare URL Request Object
    var request = URLRequest(url: requestUrl)
    request.httpMethod = "POST"
     
    // HTTP Request Parameters which will be sent in HTTP Request Body
    let postString = "{\"text\":\"\(text)\"}";
    // Set HTTP Request Body
    request.setValue("application/json", forHTTPHeaderField: "Content-Type")
    request.httpBody = postString.data(using: String.Encoding.utf8);
    
    // Perform HTTP Request
    let task = URLSession.shared.dataTask(with: request) { (data, response, error) in
            
            // Check for Error
            if let error = error {
                print("Error took place \(error)")
                return
            }
     
            // Convert HTTP Response Data to a String
            if let data = data, let dataString = String(data: data, encoding: .utf8) {
                print("Response data string:\n \(dataString)")
            }
    }
    task.resume()
  }
}
