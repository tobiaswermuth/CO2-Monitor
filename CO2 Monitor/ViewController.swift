//
//  ViewController.swift
//  CO2 Monitor
//
//  Created by Tobias Wermuth on 14.03.20.
//  Copyright © 2020 Tobias Wermuth. All rights reserved.
//

import Cocoa

class ViewController: NSViewController, Co2DeviceDelegate {
  @IBOutlet weak var statusLabel: NSTextField!
  
  @IBOutlet weak var co2Label: NSTextField!
  @IBOutlet weak var co2Indicator: NSImageView!
  var co2StatusBarItem: NSStatusItem? = nil

  @IBOutlet weak var tempLabel: NSTextField!
  @IBOutlet weak var tempIndicator: NSImageView!
  var tempStatusBarItem: NSStatusItem? = nil
  
  var co2Device: Co2Device? = nil
  
  override func viewDidLoad() {
    super.viewDidLoad()
    
    // moisture capacity T in °C => 5.02 + 0.323*T + 8.18e-3*T^2 + 3.12e-4*T^3
    //SlackSender(hook: "https://hooks.slack.com/services/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").sendMessage(text: "test")
        
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

    if(co2 <= 800) {
      co2Label.textColor = NSColor(named: NSColor.Name("Good"))
    } else if(co2 <= 1200) {
      co2Label.textColor = NSColor(named: NSColor.Name("Ok"))
    } else {
      co2Label.textColor = NSColor(named: NSColor.Name("Bad"))
    }
    
    UpdateStatusLabel()
    blinkCo2Indicator()
  }
  
  func OnNewTemperatureReading(temperature: Float) {
    let formattedTemp = String(format: "%.1f", temperature)

    tempLabel.stringValue = "\(formattedTemp)°C"
    
    if(temperature <= 19.0) {
      tempLabel.textColor = NSColor(named: NSColor.Name("Cold"))
    } else if(temperature <= 23.0) {
      tempLabel.textColor = NSColor(named: NSColor.Name("Good"))
    } else if(temperature <= 25.0) {
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
