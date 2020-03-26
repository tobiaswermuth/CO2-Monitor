//
//  ViewController.swift
//  CO2 Monitor
//
//  Created by Tobias Wermuth on 14.03.20.
//  Copyright © 2020 Tobias Wermuth. All rights reserved.
//

import Cocoa

class ViewController: NSViewController, Co2DeviceDelegate {
  private let goodCo2 = 800
  private let okCo2 = 1200
  
  private let co2Warning = 1000
  private let co2WarningTimeoutInS = 15 * 60
  
  private let coldTemp: Float = 19.0
  private let goodTemp: Float = 23.0
  private let okTemp: Float = 25.0
  
  @IBOutlet weak var statusLabel: NSTextField!
  
  @IBOutlet weak var co2Label: NSTextField!
  @IBOutlet weak var co2Indicator: NSImageView!
  var co2StatusBarItem: NSStatusItem? = nil

  @IBOutlet weak var tempLabel: NSTextField!
  @IBOutlet weak var tempIndicator: NSImageView!
  var tempStatusBarItem: NSStatusItem? = nil
  
  var co2Device: Co2Device? = nil
  
  var allowWarning = true
  
  override func viewDidLoad() {
    super.viewDidLoad()
    
    // TODO: moisture capacity T in °C => 5.02 + 0.323*T + 8.18e-3*T^2 + 3.12e-4*T^3
    
    // TODO: SlackSender(hook: "SLACK_HOOK_URL").sendMessage(text: "test")
        
    // TODO: show co2 increase over last 10min -> guess number of people in room?
        
    let statusBar = NSStatusBar.system
    co2StatusBarItem = statusBar.statusItem(withLength: NSStatusItem.variableLength)
    tempStatusBarItem = statusBar.statusItem(withLength: NSStatusItem.variableLength)
        
    hideCo2Indicator()
    hideTempIndicator()
    
    co2Device = Co2Device(delegate: self)
    co2Device!.startContinuousUpdates()
  }
  
  func OnNewCo2Reading(co2: Int) {
    co2Label.stringValue = "\(co2)ppm"

    if(co2 <= goodCo2) {
      co2Label.textColor = NSColor(named: NSColor.Name("Good"))
    } else if(co2 <= okCo2) {
      co2Label.textColor = NSColor(named: NSColor.Name("Ok"))
    } else {
      co2Label.textColor = NSColor(named: NSColor.Name("Bad"))
    }
    
    if(co2 > co2Warning && allowWarning) {
      NSRunningApplication.current.activate(options: NSApplication.ActivationOptions.activateIgnoringOtherApps)

      let alert = NSAlert()
      alert.messageText = "Open a window!"
      alert.informativeText = "The CO2 concentration is above \(co2Warning)ppm."
      alert.alertStyle = .warning
      alert.addButton(withTitle: "OK")
      alert.runModal()
      
      allowWarning = false
      Timer.scheduledTimer(withTimeInterval: TimeInterval(co2WarningTimeoutInS), repeats: false) { (timer) in
        self.allowWarning = true
      }
    }
    
    UpdateStatusLabel()
    blinkCo2Indicator()
  }
  
  func OnNewTemperatureReading(temperature: Float) {
    let formattedTemp = String(format: "%.1f", temperature)

    tempLabel.stringValue = "\(formattedTemp)°C"
    
    if(temperature <= coldTemp) {
      tempLabel.textColor = NSColor(named: NSColor.Name("Cold"))
    } else if(temperature <= goodTemp) {
      tempLabel.textColor = NSColor(named: NSColor.Name("Good"))
    } else if(temperature <= okTemp) {
      tempLabel.textColor = NSColor(named: NSColor.Name("Ok"))
    } else {
      tempLabel.textColor = NSColor(named: NSColor.Name("Bad"))
    }
    
    UpdateStatusLabel()
    blinkTempIndicator()
  }
  
  func OnConnectionStatusUpdated(status: ConnectionStatus) {
    switch status {
    case ConnectionStatus.Connected:
      statusLabel.stringValue = "Connected"
      statusLabel.textColor = NSColor(named: NSColor.Name("Good"))
    case ConnectionStatus.Connecting:
      statusLabel.stringValue = "Connecting"
      statusLabel.textColor = NSColor(named: NSColor.Name("Ok"))
    case ConnectionStatus.Disconnected:
      statusLabel.stringValue = "Disconnected"
      statusLabel.textColor = NSColor(named: NSColor.Name("Bad"))
    }
    
    tempLabel.stringValue = "- °C"
    tempLabel.textColor = NSColor(named: NSColor.Name("Unknown"))
    
    co2Label.stringValue = "- ppm"
    co2Label.textColor = NSColor(named: NSColor.Name("Unknown"))
    
    UpdateStatusLabel()
  }
  
  private func UpdateStatusLabel() {
    co2StatusBarItem?.button?.title = "\(co2Label.stringValue)"
    co2StatusBarItem?.button?.contentTintColor = co2Label.textColor
    
    tempStatusBarItem?.button?.title = "\(tempLabel.stringValue)"
    tempStatusBarItem?.button?.contentTintColor = tempLabel.textColor
  }
  
  func blinkCo2Indicator() {
    co2Indicator.isHidden = false
    Timer.scheduledTimer(timeInterval: 0.5, target: self, selector: #selector(self.hideCo2Indicator), userInfo: nil, repeats: false)
  }
  
  @objc func hideCo2Indicator() {
    co2Indicator.isHidden = true
  }
  
  func blinkTempIndicator() {
    tempIndicator.isHidden = false
    Timer.scheduledTimer(timeInterval: 0.5, target: self, selector: #selector(self.hideTempIndicator), userInfo: nil, repeats: false)
  }
  
  @objc func hideTempIndicator() {
    tempIndicator.isHidden = true
  }
}
