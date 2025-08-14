import UIKit
import Flutter

@UIApplicationMain
@objc class AppDelegate: FlutterAppDelegate {
  override func application(
    _ application: UIApplication,
    didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
  ) -> Bool {
    let controller : FlutterViewController = window?.rootViewController as! FlutterViewController
    let diskChannel = FlutterMethodChannel(name: "squirreldisk/disk",
                                           binaryMessenger: controller.binaryMessenger)
    let scanEventChannel = FlutterEventChannel(name: "squirreldisk/scan_events", 
                                               binaryMessenger: controller.binaryMessenger)
    
    diskChannel.setMethodCallHandler({
      [weak self] (call: FlutterMethodCall, result: @escaping FlutterResult) -> Void in
      self?.handleMethodCall(call: call, result: result)
    })
    
    GeneratedPluginRegistrant.register(with: self)
    return super.application(application, didFinishLaunchingWithOptions: launchOptions)
  }
  
  private func handleMethodCall(call: FlutterMethodCall, result: @escaping FlutterResult) {
    switch call.method {
    case "getDrives":
      getDrives(result: result)
    case "startScan":
      startScan(arguments: call.arguments, result: result)
    case "stopScan":
      stopScan(result: result)
    case "showInFolder":
      showInFolder(arguments: call.arguments, result: result)
    default:
      result(FlutterMethodNotImplemented)
    }
  }
  
  private func getDrives(result: @escaping FlutterResult) {
    var drives: [[String: Any]] = []
    
    // Get mounted volumes
    let fileManager = FileManager.default
    if let mountedVolumes = fileManager.mountedVolumeURLs(includingResourceValuesForKeys: [
      .volumeNameKey,
      .volumeTotalCapacityKey,
      .volumeAvailableCapacityKey,
      .volumeIsRemovableKey
    ], options: []) {
      
      for volume in mountedVolumes {
        do {
          let resourceValues = try volume.resourceValues(forKeys: [
            .volumeNameKey,
            .volumeTotalCapacityKey,
            .volumeAvailableCapacityKey,
            .volumeIsRemovableKey
          ])
          
          let name = resourceValues.volumeName ?? volume.lastPathComponent
          let totalSpace = resourceValues.volumeTotalCapacity ?? 0
          let availableSpace = resourceValues.volumeAvailableCapacity ?? 0
          let isRemovable = resourceValues.volumeIsRemovable ?? false
          
          drives.append([
            "name": name,
            "sMountPoint": volume.path,
            "totalSpace": totalSpace,
            "availableSpace": availableSpace,
            "isRemovable": isRemovable
          ])
        } catch {
          print("Error getting volume info: \(error)")
        }
      }
    }
    
    result(drives)
  }
  
  private func startScan(arguments: Any?, result: @escaping FlutterResult) {
    guard let args = arguments as? [String: Any],
          let path = args["path"] as? String else {
      result(FlutterError(code: "INVALID_ARGUMENTS", message: "Invalid arguments", details: nil))
      return
    }
    
    // This is a simplified implementation
    // In a real app, you'd implement proper directory scanning
    DispatchQueue.global(qos: .background).async {
      // Mock scan completion
      DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) {
        result(nil)
      }
    }
  }
  
  private func stopScan(result: @escaping FlutterResult) {
    result(nil)
  }
  
  private func showInFolder(arguments: Any?, result: @escaping FlutterResult) {
    guard let args = arguments as? [String: Any],
          let path = args["path"] as? String else {
      result(FlutterError(code: "INVALID_ARGUMENTS", message: "Invalid arguments", details: nil))
      return
    }
    
    let url = URL(fileURLWithPath: path)
    if FileManager.default.fileExists(atPath: path) {
      NSWorkspace.shared.selectFile(path, inFileViewerRootedAtPath: url.deletingLastPathComponent().path)
      result(nil)
    } else {
      result(FlutterError(code: "FILE_NOT_FOUND", message: "File not found", details: nil))
    }
  }
}