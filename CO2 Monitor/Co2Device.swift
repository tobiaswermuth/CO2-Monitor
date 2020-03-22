//
//  Co2Device.swift
//  CO2 Monitor
//
//  Created by Tobias Wermuth on 14.03.20.
//  Copyright © 2020 Tobias Wermuth. All rights reserved.
//

import Foundation
import hidapi

protocol Co2DeviceDelegate {
  func OnNewCo2Reading(co2: Int)
  func OnNewTemperatureReading(temperature: Float)
  func OnConnectionStatusUpdated(status: ConnectionStatus)
}

class Co2Device {
  private let KEY: [UInt8] = [0xc4, 0xc6, 0xc0, 0x92, 0x40, 0x23, 0xdc, 0x96];
  private let vendorId: UInt16 = 0x04d9
  private let productId: UInt16 = 0xa052
  
  private var device: OpaquePointer? = nil
  private let delegate: Co2DeviceDelegate
  private var updateTimer: Timer? = nil
  
  var lastCo2Reading: Int? = nil
  var lastTemperatureReading: Float? = nil
  var lastStatus: ConnectionStatus = ConnectionStatus.Disconnected
  
  init(delegate: Co2DeviceDelegate) {
    self.delegate = delegate
    
    delegate.OnConnectionStatusUpdated(status: lastStatus)
  }
  
  func startContinuousUpdates() {
    DispatchQueue.global(qos: .utility).async {
      if(self.updateTimer != nil) {
        return
      }
      
      self.updateTimer = Timer.scheduledTimer(timeInterval: 0.5, target: self, selector: #selector(self.readAll), userInfo: nil, repeats: true)
      
      let runLoop = RunLoop.current
      runLoop.add(self.updateTimer!, forMode: .default)
      runLoop.run()
    }
  }
  
  func stopContinuousUpdates() {
    if(updateTimer != nil) {
      return
    }
    
    updateTimer?.invalidate()
    updateTimer = nil
  }
  
  @objc func readAll() {
    if(!isConnected()) {
      connect()
    }
    
    var gotCo2 = false
    var gotTemp = false
    
    while(!gotCo2 || !gotTemp) {
      if(!isConnected()) {
        break
      }
      
      switch readData() {
      case Reading.CO2(let co2): do {
          lastCo2Reading = co2
          DispatchQueue.main.async {
            self.delegate.OnNewCo2Reading(co2: co2)
          }
          gotCo2 = true
        }
        
      case Reading.Temperature(let temp): do {
          lastTemperatureReading = temp
          DispatchQueue.main.async {
            self.delegate.OnNewTemperatureReading(temperature: temp)
          }
          gotTemp = true
        }
          
      case Reading.Other: break
      }
    }
  }
  
  func connect() {
    if(!isConnected()) {
      createDevice()
    }
  }
  
  func disconnect() {
    stopContinuousUpdates()
    
    if(isConnected()) {
      hid_close(device)
    }
    
    device = nil
    
    updateConnectionStatus(status: ConnectionStatus.Disconnected)
  }
  
  func isConnected() -> Bool {
    return device != nil
  }
  
  private func updateConnectionStatus(status: ConnectionStatus) {
    if(status != lastStatus) {
      lastStatus = status
      DispatchQueue.main.async {
        self.delegate.OnConnectionStatusUpdated(status: status)
      }
    }
  }
  
  private func createDevice() {
    device = hid_open(vendorId, productId, nil)
    
    if (device == nil) {
      print("No device found")
      return
    } else {
      print("Device found")
    }
    
    updateConnectionStatus(status: ConnectionStatus.Connecting)
    
    let report_id: UInt8 = 0x00;

    var report: [UInt8] = [UInt8](KEY)
    report.insert(report_id, at: 0)
    
    hid_send_feature_report(device, report, 9)
    
    print("Device initiated")
    
    updateConnectionStatus(status: ConnectionStatus.Connected)
  }
  
  private func readData() -> Reading {
    let BUF_LEN = 8
    var buf = [UInt8](repeating: 0, count: BUF_LEN + 1)
    
    let status = hid_read(device, &buf, BUF_LEN)
    if(status < 0) {
      print("Could not read from device")
      disconnect()
      return Reading.Other
    }
    
    let decrypted = decrypt(data: buf)
    return decode(decrypted: decrypted)
  }
  
  private func decrypt(data: [UInt8]) -> [UInt8] {
      let CSTATE: [UInt8] = [0x48, 0x74, 0x65, 0x6D, 0x70, 0x39, 0x39, 0x65];
      let SHUFFLE: [Int] = [2, 4, 0, 7, 1, 6, 5, 3];

      var phase1 = [UInt8](repeating: 0, count: 8)
      for (index, element) in SHUFFLE.enumerated() {
        phase1[element] = data[index];
      }

      var phase2 = [UInt8](repeating: 0, count: 8)
      for i in 0...7 {
          phase2[i] = phase1[i] ^ KEY[i];
      }

      var phase3 = [UInt8](repeating: 0, count: 8)
      for i in 0...7 {
          phase3[i] = (phase2[i] >> 3 | phase2[(i + 7) % 8] << 5) & 0xff;
      }

      var tmp = [UInt8](repeating: 0, count: 8)
      for i in 0...7 {
          tmp[i] = (CSTATE[i] >> 4 | CSTATE[i] << 4) & 0xff;
      }

      var out = [UInt8](repeating: 0, count: 8)
      for i in 0...7 {
          out[i] = UInt8((UInt32(0x100) + UInt32(phase3[i]) - UInt32(tmp[i])) & 0xff);
      }

      var sum: UInt16 = 0
      for i in 0...2 {
           sum += UInt16(out[i])
      }
      let checkSum: UInt8 = UInt8(sum & 0xff)
    
      if out[4] != 0x0d || checkSum != out[3] {
        print("Checksum validation failed");
        disconnect()
      }
    
      return out
  }
  
  private func decode(decrypted: [UInt8]) -> Reading {
      let op = decrypted[0];
      let val = UInt16(decrypted[1]) << 8 | UInt16(decrypted[2]);
    
      if(op == 0x50) {
        let co2 = Int(val)
        if(co2 > 20000) { // this happens somtimes at the first reading
          return Reading.Other
        }
        return Reading.CO2(co2)
      } else if(op == 0x42) {
        return Reading.Temperature(Float(val) / 16.0 - 273.15)
      } else {
        return Reading.Other
      }
  }
}

extension String {
    init(wString: UnsafeMutablePointer<wchar_t>) {
        if let nsstr = NSString(bytes: wString,
                                length: wcslen(wString) * MemoryLayout<wchar_t>.size,
                                encoding: String.Encoding.utf32LittleEndian.rawValue) {
            self.init(nsstr)
        } else {
            self.init()
        }
    }
}

enum Reading {
  case CO2(Int)
  case Temperature(Float)
  case Other
}

enum ConnectionStatus {
  case Connecting
  case Connected
  case Disconnected
}
