#include "squirreldisk_plugin.h"

#include <windows.h>
#include <shellapi.h>
#include <vector>
#include <thread>
#include <filesystem>
#include <iostream>
#include <sstream>

namespace fs = std::filesystem;

namespace squirreldisk_windows {

void SquirrelDiskPlugin::RegisterWithRegistrar(flutter::PluginRegistrarWindows* registrar) {
  auto channel = std::make_unique<flutter::MethodChannel<flutter::EncodableValue>>(
      registrar->messenger(), "squirreldisk/disk",
      &flutter::StandardMethodCodec::GetInstance());

  auto event_channel = std::make_unique<flutter::EventChannel<flutter::EncodableValue>>(
      registrar->messenger(), "squirreldisk/scan_events",
      &flutter::StandardMethodCodec::GetInstance());

  auto plugin = std::make_unique<SquirrelDiskPlugin>();

  channel->SetMethodCallHandler(
      [plugin_pointer = plugin.get()](const auto& call, auto result) {
        plugin_pointer->HandleMethodCall(call, std::move(result));
      });

  registrar->AddPlugin(std::move(plugin));
}

SquirrelDiskPlugin::SquirrelDiskPlugin() {}

SquirrelDiskPlugin::~SquirrelDiskPlugin() {}

void SquirrelDiskPlugin::HandleMethodCall(
    const flutter::MethodCall<flutter::EncodableValue>& method_call,
    std::unique_ptr<flutter::MethodResult<flutter::EncodableValue>> result) {
  
  if (method_call.method_name().compare("getDrives") == 0) {
    GetDisks(std::move(result));
  } else if (method_call.method_name().compare("startScan") == 0) {
    StartScan(method_call.arguments(), std::move(result));
  } else if (method_call.method_name().compare("stopScan") == 0) {
    StopScan(std::move(result));
  } else if (method_call.method_name().compare("showInFolder") == 0) {
    ShowInFolder(method_call.arguments(), std::move(result));
  } else {
    result->NotImplemented();
  }
}

void SquirrelDiskPlugin::GetDisks(std::unique_ptr<flutter::MethodResult<flutter::EncodableValue>> result) {
  flutter::EncodableList disk_list;

  DWORD drives = GetLogicalDrives();
  for (int i = 0; i < 26; i++) {
    if (drives & (1 << i)) {
      char drive_letter = 'A' + i;
      std::string drive_path = std::string(1, drive_letter) + ":\\";
      
      ULARGE_INTEGER free_bytes, total_bytes;
      if (GetDiskFreeSpaceExA(drive_path.c_str(), &free_bytes, &total_bytes, nullptr)) {
        flutter::EncodableMap disk_info;
        disk_info[flutter::EncodableValue("name")] = flutter::EncodableValue(drive_path);
        disk_info[flutter::EncodableValue("sMountPoint")] = flutter::EncodableValue(drive_path);
        disk_info[flutter::EncodableValue("totalSpace")] = flutter::EncodableValue(static_cast<int64_t>(total_bytes.QuadPart));
        disk_info[flutter::EncodableValue("availableSpace")] = flutter::EncodableValue(static_cast<int64_t>(free_bytes.QuadPart));
        
        UINT drive_type = GetDriveTypeA(drive_path.c_str());
        disk_info[flutter::EncodableValue("isRemovable")] = flutter::EncodableValue(
          drive_type == DRIVE_REMOVABLE || drive_type == DRIVE_CDROM
        );
        
        disk_list.push_back(flutter::EncodableValue(disk_info));
      }
    }
  }

  result->Success(flutter::EncodableValue(disk_list));
}

void SquirrelDiskPlugin::StartScan(const flutter::EncodableValue* arguments,
                                  std::unique_ptr<flutter::MethodResult<flutter::EncodableValue>> result) {
  if (is_scanning_) {
    result->Error("ALREADY_SCANNING", "A scan is already in progress");
    return;
  }

  const auto* args = std::get_if<flutter::EncodableMap>(arguments);
  if (!args) {
    result->Error("INVALID_ARGUMENTS", "Invalid arguments provided");
    return;
  }

  auto path_it = args->find(flutter::EncodableValue("path"));
  if (path_it == args->end()) {
    result->Error("MISSING_PATH", "Path argument is required");
    return;
  }

  const std::string* path = std::get_if<std::string>(&path_it->second);
  if (!path) {
    result->Error("INVALID_PATH", "Path must be a string");
    return;
  }

  is_scanning_ = true;
  
  // Start scanning in a separate thread
  std::thread([this, path = *path]() {
    try {
      // This is a simplified implementation
      // In a real app, you'd implement proper directory scanning
      flutter::EncodableMap scan_result;
      scan_result[flutter::EncodableValue("type")] = flutter::EncodableValue("completed");
      scan_result[flutter::EncodableValue("data")] = flutter::EncodableValue("[]"); // Mock empty result
      
      if (event_sink_) {
        event_sink_->Success(flutter::EncodableValue(scan_result));
      }
    } catch (...) {
      flutter::EncodableMap error_result;
      error_result[flutter::EncodableValue("type")] = flutter::EncodableValue("error");
      error_result[flutter::EncodableValue("message")] = flutter::EncodableValue("Scan failed");
      
      if (event_sink_) {
        event_sink_->Success(flutter::EncodableValue(error_result));
      }
    }
    
    is_scanning_ = false;
  }).detach();

  result->Success();
}

void SquirrelDiskPlugin::StopScan(std::unique_ptr<flutter::MethodResult<flutter::EncodableValue>> result) {
  is_scanning_ = false;
  result->Success();
}

void SquirrelDiskPlugin::ShowInFolder(const flutter::EncodableValue* arguments,
                                     std::unique_ptr<flutter::MethodResult<flutter::EncodableValue>> result) {
  const auto* args = std::get_if<flutter::EncodableMap>(arguments);
  if (!args) {
    result->Error("INVALID_ARGUMENTS", "Invalid arguments provided");
    return;
  }

  auto path_it = args->find(flutter::EncodableValue("path"));
  if (path_it == args->end()) {
    result->Error("MISSING_PATH", "Path argument is required");
    return;
  }

  const std::string* path = std::get_if<std::string>(&path_it->second);
  if (!path) {
    result->Error("INVALID_PATH", "Path must be a string");
    return;
  }

  // Use ShellExecute to open the folder in Windows Explorer
  HINSTANCE result_code = ShellExecuteA(nullptr, "open", path->c_str(), nullptr, nullptr, SW_SHOWNORMAL);
  
  if (reinterpret_cast<intptr_t>(result_code) <= 32) {
    result->Error("FAILED_TO_OPEN", "Failed to open folder");
  } else {
    result->Success();
  }
}

} // namespace squirreldisk_windows