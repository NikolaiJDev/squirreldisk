#include "squirreldisk_plugin.h"
#include "logger.h"

#include <filesystem>
#include <shellapi.h>
#include <thread>
#include <vector>

// Ensure ERROR macro doesn't conflict with our enum after including logger.h
#ifdef ERROR
#undef ERROR  
#endif

#include <windows.h>
#include <shlwapi.h>
#include <shlobj.h>
#include <iostream>
#include <chrono>
#include <ctime>
#include <optional>

#include <flutter/event_stream_handler_functions.h>
#include <flutter_windows.h>
#include <flutter/plugin_registrar_manager.h>

namespace fs = std::filesystem;
using namespace squirreldisk_windows;

namespace squirreldisk_windows {

    std::string WStringToString(const std::wstring& wstr) {
        if (wstr.empty()) return std::string();

        int size_needed = WideCharToMultiByte(CP_UTF8, 0, &wstr[0], (int)wstr.size(), NULL, 0, NULL, NULL);
        std::string strTo(size_needed, 0);
        WideCharToMultiByte(CP_UTF8, 0, &wstr[0], (int)wstr.size(), &strTo[0], size_needed, NULL, NULL);
        return strTo;
    }

    std::wstring StringToWString(const std::string& str) {
        if (str.empty()) return std::wstring();

        int size_needed = MultiByteToWideChar(CP_UTF8, 0, &str[0], (int)str.size(), NULL, 0);
        std::wstring wstrTo(size_needed, 0);
        MultiByteToWideChar(CP_UTF8, 0, &str[0], (int)str.size(), &wstrTo[0], size_needed);
        return wstrTo;
    }

    void SquirrelDiskPlugin::RegisterWithRegistrar(flutter::PluginRegistrarWindows *registrar) {
        // Initialize logging system first
        if (!Logger::getInstance().initialize()) {
            OutputDebugStringA("Failed to initialize logger!");
        }
        
        LOG_INFO("SquirrelDiskPlugin starting registration");
        LOG_MEMORY("plugin_registration_start");
        
        auto channel = std::make_unique<flutter::MethodChannel<flutter::EncodableValue>>(
                registrar->messenger(), "squirreldisk",
                        &flutter::StandardMethodCodec::GetInstance());

        auto event_channel = std::make_unique<flutter::EventChannel<flutter::EncodableValue>>(
                registrar->messenger(), "squirreldisk_events",
                        &flutter::StandardMethodCodec::GetInstance());

        auto plugin = std::make_unique<SquirrelDiskPlugin>();
        plugin->method_channel_ = std::move(channel);
        plugin->event_channel_ = std::move(event_channel);

        plugin->method_channel_->SetMethodCallHandler(
                [plugin_pointer = plugin.get()](const auto &call, auto result) {
                    plugin_pointer->HandleMethodCall(call, std::move(result));
                });

        auto thread_safe_sink = std::make_unique<ThreadSafeScanEventSink>();
        plugin->thread_safe_event_sink_ = std::move(thread_safe_sink);

        auto stream_handler = std::make_unique<flutter::StreamHandlerFunctions<flutter::EncodableValue>>(
                [plugin_pointer = plugin.get()](
                        const flutter::EncodableValue* arguments,
                        std::unique_ptr<flutter::EventSink<flutter::EncodableValue>>&& events)
                        -> std::unique_ptr<flutter::StreamHandlerError<flutter::EncodableValue>> {
                    plugin_pointer->thread_safe_event_sink_->SetEventSink(std::move(events));
                    return nullptr;
                },
                        [plugin_pointer = plugin.get()](const flutter::EncodableValue* arguments)
                                -> std::unique_ptr<flutter::StreamHandlerError<flutter::EncodableValue>> {
                            plugin_pointer->thread_safe_event_sink_->SetEventSink(nullptr);
                            return nullptr;
                        });

        plugin->event_channel_->SetStreamHandler(std::move(stream_handler));

        // Для Windows используем статическое хранение плагина
        static auto saved_plugin = std::move(plugin);
        
        LOG_INFO("SquirrelDiskPlugin registration completed successfully");
        LOG_MEMORY("plugin_registration_complete");
    }

    void SquirrelDiskPlugin::RegisterWithMessenger(flutter::BinaryMessenger *messenger) {
        auto plugin = std::make_unique<SquirrelDiskPlugin>();
        auto channel = std::make_unique<flutter::MethodChannel<flutter::EncodableValue>>(
                messenger, "squirreldisk",
                        &flutter::StandardMethodCodec::GetInstance());

        auto event_channel = std::make_unique<flutter::EventChannel<flutter::EncodableValue>>(
                messenger, "squirreldisk_events",
                        &flutter::StandardMethodCodec::GetInstance());

        plugin->method_channel_ = std::move(channel);
        plugin->event_channel_ = std::move(event_channel);

        plugin->method_channel_->SetMethodCallHandler(
                [plugin_pointer = plugin.get()](const auto &call, auto result) {
                    plugin_pointer->HandleMethodCall(call, std::move(result));
                });

        auto thread_safe_sink = std::make_unique<ThreadSafeScanEventSink>();
        plugin->thread_safe_event_sink_ = std::move(thread_safe_sink);

        auto stream_handler = std::make_unique<flutter::StreamHandlerFunctions<flutter::EncodableValue>>(
                [plugin_pointer = plugin.get()](
                        const flutter::EncodableValue* arguments,
                        std::unique_ptr<flutter::EventSink<flutter::EncodableValue>>&& events)
                        -> std::unique_ptr<flutter::StreamHandlerError<flutter::EncodableValue>> {
                    plugin_pointer->thread_safe_event_sink_->SetEventSink(std::move(events));
                    return nullptr;
                },
                        [plugin_pointer = plugin.get()](const flutter::EncodableValue* arguments)
                                -> std::unique_ptr<flutter::StreamHandlerError<flutter::EncodableValue>> {
                            plugin_pointer->thread_safe_event_sink_->SetEventSink(nullptr);
                            return nullptr;
                        });

        plugin->event_channel_->SetStreamHandler(std::move(stream_handler));

        // Сохраняем указатель для последующего использования
        static auto saved_plugin = std::move(plugin);
    }

    SquirrelDiskPlugin::SquirrelDiskPlugin() {
        LOG_INFO("SquirrelDiskPlugin constructor called");
        LOG_MEMORY("constructor");
    }

    SquirrelDiskPlugin::~SquirrelDiskPlugin() {
        LOG_INFO("SquirrelDiskPlugin destructor called");
        
        // Ensure scanning is stopped
        is_scanning_.store(false);
        
        // Clear cache and batches
        ClearCache();
        {
            std::lock_guard<std::mutex> lock(batch_mutex_);
            current_batch_.clear();
        }
        
        // Clean up message window
        if (msg_hwnd_) {
            DestroyWindow(msg_hwnd_);
            msg_hwnd_ = nullptr;
        }
        
        Logger::getInstance().shutdown();
        LOG_INFO("SquirrelDiskPlugin destructor complete");
    }

    LRESULT CALLBACK SquirrelDiskPlugin::MsgWndProc(HWND hwnd, UINT msg, WPARAM wparam, LPARAM lparam) {
    auto *plugin = reinterpret_cast<SquirrelDiskPlugin *>(GetWindowLongPtrW(hwnd, GWLP_USERDATA));
    if (plugin && msg == kMsgFlush) {
    plugin->thread_safe_event_sink_->Flush();
}
return DefWindowProcW(hwnd, msg, wparam, lparam);
}

void SquirrelDiskPlugin::EnsureMessageWindow() {
    if (msg_hwnd_) return;

    WNDCLASSW wc = {};
    wc.lpfnWndProc = MsgWndProc;
    wc.hInstance = GetModuleHandleW(nullptr);
    wc.lpszClassName = L"SquirrelDiskMessageWindow";
    RegisterClassW(&wc);

    msg_hwnd_ = CreateWindowW(
            wc.lpszClassName,
            L"",
            0,
            0, 0, 0, 0,
            HWND_MESSAGE,
            nullptr,
            wc.hInstance,
            nullptr);

    SetWindowLongPtrW(msg_hwnd_, GWLP_USERDATA, reinterpret_cast<LONG_PTR>(this));
}

void SquirrelDiskPlugin::PostFlush() const {
    if (msg_hwnd_) {
        PostMessageW(msg_hwnd_, kMsgFlush, 0, 0);
    }
}

void SquirrelDiskPlugin::HandleMethodCall(
        const flutter::MethodCall<flutter::EncodableValue> &method_call,
        std::unique_ptr<flutter::MethodResult<flutter::EncodableValue>> result) {

    const auto &method = method_call.method_name();
    LOG_PLUGIN_CALL(method, "");
    LOG_MEMORY("method_call_" + method);

    if (method == "getDisks") {
        GetDisks(std::move(result));
    } else if (method == "getDiskInfo") {
        GetDiskInfo(method_call.arguments(), std::move(result));
    } else if (method == "startScan") {
        StartScan(method_call.arguments(), std::move(result));
    } else if (method == "stopScan") {
        StopScan(std::move(result));
    } else if (method == "pauseScan") {
        PauseScan(std::move(result));
    } else if (method == "resumeScan") {
        ResumeScan(std::move(result));
    } else if (method == "showInFolder") {
        ShowInFolder(method_call.arguments(), std::move(result));
    } else if (method == "getScanStatistics") {
        GetScanStatistics(std::move(result));
    } else if (method == "deleteFileOrFolder") {
        DeleteFileOrFolder(method_call.arguments(), std::move(result));
    } else if (method == "getFileProperties") {
        GetFileProperties(method_call.arguments(), std::move(result));
    } else if (method == "openFile") {
        OpenFile(method_call.arguments(), std::move(result));
    } else {
        LOG_WARNING("Unknown method called: " + method);
        result->NotImplemented();
    }
}

void SquirrelDiskPlugin::GetDiskInfo(const flutter::EncodableValue *arguments,
                                     std::unique_ptr<flutter::MethodResult<flutter::EncodableValue>> result) {
    if (!arguments) {
        result->Error("INVALID_ARGUMENT", "Arguments cannot be null");
        return;
    }

    const auto *args = std::get_if<flutter::EncodableMap>(arguments);
    if (!args) {
        result->Error("INVALID_ARGUMENT", "Arguments must be a map");
        return;
    }

    auto path_it = args->find(flutter::EncodableValue("path"));
    if (path_it == args->end()) {
        result->Error("MISSING_ARGUMENT", "Missing 'path' argument");
        return;
    }

    const std::string *path = std::get_if<std::string>(&path_it->second);
    if (!path) {
        result->Error("INVALID_ARGUMENT", "'path' must be a string");
        return;
    }

    try {
        ULARGE_INTEGER free_bytes, total_bytes;
        if (GetDiskFreeSpaceExA(path->c_str(), &free_bytes, &total_bytes, nullptr)) {
            flutter::EncodableMap disk_info;
            disk_info[flutter::EncodableValue("path")] = flutter::EncodableValue(*path);
            disk_info[flutter::EncodableValue("totalSpace")] = flutter::EncodableValue(static_cast<int64_t>(total_bytes.QuadPart));
            disk_info[flutter::EncodableValue("freeSpace")] = flutter::EncodableValue(static_cast<int64_t>(free_bytes.QuadPart));
            disk_info[flutter::EncodableValue("usedSpace")] = flutter::EncodableValue(static_cast<int64_t>(total_bytes.QuadPart - free_bytes.QuadPart));

            result->Success(flutter::EncodableValue(disk_info));
        } else {
            result->Error("DISK_ERROR", "Failed to get disk information");
        }
    } catch (const std::exception& e) {
        result->Error("DISK_ERROR", e.what());
    }
}

void SquirrelDiskPlugin::GetDisks(std::unique_ptr<flutter::MethodResult<flutter::EncodableValue>> result) {
    LOG_OPERATION("GetDisks", "Starting disk enumeration");
    LOG_MEMORY("get_disks_start");
    
    flutter::EncodableList disk_list;

    try {
        DWORD drives = GetLogicalDrives();
        LOG_INFO("Found logical drives mask: " + std::to_string(drives));
        
        for (char drive = 'A'; drive <= 'Z'; ++drive) {
            if (drives & (1 << (drive - 'A'))) {
                std::string drive_path = std::string(1, drive) + ":\\";
                LOG_DEBUG("Processing drive: " + drive_path);

                // Проверим, доступен ли диск
                DWORD sectors_per_cluster, bytes_per_sector, free_clusters, total_clusters;
                if (!GetDiskFreeSpaceA(drive_path.c_str(), &sectors_per_cluster, &bytes_per_sector, &free_clusters, &total_clusters)) {
                    LOG_WARNING("Drive " + drive_path + " is not accessible, skipping");
                    continue;
                }

                UINT drive_type = GetDriveTypeA(drive_path.c_str());
                std::string type_name;
                std::string drive_icon;

                switch (drive_type) {
                    case DRIVE_FIXED: 
                        type_name = "fixed"; 
                        drive_icon = "storage";
                        break;
                    case DRIVE_REMOVABLE: 
                        type_name = "removable"; 
                        drive_icon = "usb";
                        break;
                    case DRIVE_REMOTE: 
                        type_name = "network"; 
                        drive_icon = "lan";
                        break;
                    case DRIVE_CDROM: 
                        type_name = "cdrom"; 
                        drive_icon = "album";
                        break;
                    case DRIVE_RAMDISK: 
                        type_name = "ramdisk"; 
                        drive_icon = "memory";
                        break;
                    default: 
                        type_name = "unknown"; 
                        drive_icon = "storage";
                        break;
                }

                // Получение расширенной информации о диске
                std::string disk_label;
                std::string file_system;
                std::string serial_number;
                wchar_t volume_name[MAX_PATH + 1] = {0};
                wchar_t file_system_name[MAX_PATH + 1] = {0};
                DWORD volume_serial = 0;
                DWORD max_component_length = 0;
                DWORD file_system_flags = 0;

                std::wstring wide_drive_path = StringToWString(drive_path);

                bool volume_info_success = GetVolumeInformationW(
                    wide_drive_path.c_str(),
                    volume_name, MAX_PATH + 1,
                    &volume_serial,
                    &max_component_length,
                    &file_system_flags,
                    file_system_name, MAX_PATH + 1
                );

                if (volume_info_success) {
                    disk_label = WStringToString(std::wstring(volume_name));
                    file_system = WStringToString(std::wstring(file_system_name));
                    
                    // Форматируем серийный номер
                    std::stringstream ss;
                    ss << std::hex << std::uppercase << volume_serial;
                    serial_number = ss.str();
                }

                // Если метка диска пустая, создадим стандартную
                if (disk_label.empty()) {
                    if (drive_type == DRIVE_REMOVABLE) {
                        disk_label = "Removable Disk (" + std::string(1, drive) + ":)";
                    } else if (drive_type == DRIVE_CDROM) {
                        disk_label = "DVD Drive (" + std::string(1, drive) + ":)";
                    } else if (drive_type == DRIVE_REMOTE) {
                        disk_label = "Network Drive (" + std::string(1, drive) + ":)";
                    } else {
                        // Определяем тип по букве диска для системных дисков
                        if (drive == 'C') {
                            disk_label = "Windows (" + std::string(1, drive) + ":)";
                        } else if (drive >= 'D' && drive <= 'Z') {
                            disk_label = "Local Disk (" + std::string(1, drive) + ":)";
                        } else {
                            disk_label = "Disk " + std::string(1, drive);
                        }
                    }
                }

                if (file_system.empty()) {
                    file_system = "Unknown";
                }

                // Создаем информацию о диске
                flutter::EncodableMap disk_info;
                disk_info[flutter::EncodableValue("name")] = flutter::EncodableValue(disk_label);
                disk_info[flutter::EncodableValue("mountPoint")] = flutter::EncodableValue(drive_path);
                disk_info[flutter::EncodableValue("type")] = flutter::EncodableValue(type_name);
                disk_info[flutter::EncodableValue("fileSystem")] = flutter::EncodableValue(file_system);
                disk_info[flutter::EncodableValue("icon")] = flutter::EncodableValue(drive_icon);
                disk_info[flutter::EncodableValue("serialNumber")] = flutter::EncodableValue(serial_number);
                disk_info[flutter::EncodableValue("driveLetter")] = flutter::EncodableValue(std::string(1, drive));

                // Получаем точную информацию о месте на диске
                ULARGE_INTEGER free_bytes_available, total_bytes, free_bytes;
                if (GetDiskFreeSpaceExA(drive_path.c_str(), &free_bytes_available, &total_bytes, &free_bytes)) {
                    int64_t total_space = static_cast<int64_t>(total_bytes.QuadPart);
                    int64_t free_space = static_cast<int64_t>(free_bytes.QuadPart);
                    int64_t available_space = static_cast<int64_t>(free_bytes_available.QuadPart);
                    int64_t used_space = total_space - free_space;

                    disk_info[flutter::EncodableValue("totalSpace")] = flutter::EncodableValue(total_space);
                    disk_info[flutter::EncodableValue("freeSpace")] = flutter::EncodableValue(free_space);
                    disk_info[flutter::EncodableValue("availableSpace")] = flutter::EncodableValue(available_space);
                    disk_info[flutter::EncodableValue("usedSpace")] = flutter::EncodableValue(used_space);
                    
                    // Вычисляем процент использования
                    double usage_percentage = total_space > 0 ? (static_cast<double>(used_space) / total_space) * 100.0 : 0.0;
                    disk_info[flutter::EncodableValue("usagePercentage")] = flutter::EncodableValue(usage_percentage);
                } else {
                    disk_info[flutter::EncodableValue("totalSpace")] = flutter::EncodableValue(static_cast<int64_t>(0));
                    disk_info[flutter::EncodableValue("freeSpace")] = flutter::EncodableValue(static_cast<int64_t>(0));
                    disk_info[flutter::EncodableValue("availableSpace")] = flutter::EncodableValue(static_cast<int64_t>(0));
                    disk_info[flutter::EncodableValue("usedSpace")] = flutter::EncodableValue(static_cast<int64_t>(0));
                    disk_info[flutter::EncodableValue("usagePercentage")] = flutter::EncodableValue(0.0);
                }

                // Дополнительные свойства диска
                disk_info[flutter::EncodableValue("isReady")] = flutter::EncodableValue(true);
                disk_info[flutter::EncodableValue("isSystemDrive")] = flutter::EncodableValue(drive == 'C');
                disk_info[flutter::EncodableValue("maxComponentLength")] = flutter::EncodableValue(static_cast<int64_t>(max_component_length));
                
                // Флаги файловой системы
                flutter::EncodableMap fs_features;
                fs_features[flutter::EncodableValue("supportsCompression")] = flutter::EncodableValue((file_system_flags & FILE_FILE_COMPRESSION) != 0);
                fs_features[flutter::EncodableValue("supportsEncryption")] = flutter::EncodableValue((file_system_flags & FILE_SUPPORTS_ENCRYPTION) != 0);
                fs_features[flutter::EncodableValue("supportsVolumeQuotas")] = flutter::EncodableValue((file_system_flags & FILE_VOLUME_QUOTAS) != 0);
                fs_features[flutter::EncodableValue("supportsCaseSensitive")] = flutter::EncodableValue((file_system_flags & FILE_CASE_SENSITIVE_SEARCH) != 0);
                disk_info[flutter::EncodableValue("fileSystemFeatures")] = flutter::EncodableValue(fs_features);

                disk_list.push_back(flutter::EncodableValue(disk_info));
            }
        }

        // Добавляем информацию о системе
        flutter::EncodableMap system_info;
        
        // Информация о памяти
        MEMORYSTATUSEX mem_status;
        mem_status.dwLength = sizeof(mem_status);
        if (GlobalMemoryStatusEx(&mem_status)) {
            system_info[flutter::EncodableValue("totalMemory")] = flutter::EncodableValue(static_cast<int64_t>(mem_status.ullTotalPhys));
            system_info[flutter::EncodableValue("availableMemory")] = flutter::EncodableValue(static_cast<int64_t>(mem_status.ullAvailPhys));
            system_info[flutter::EncodableValue("memoryUsagePercentage")] = flutter::EncodableValue(static_cast<double>(mem_status.dwMemoryLoad));
        }

        // Добавляем системную информацию в результат
        flutter::EncodableMap response;
        response[flutter::EncodableValue("disks")] = flutter::EncodableValue(disk_list);
        response[flutter::EncodableValue("systemInfo")] = flutter::EncodableValue(system_info);

        LOG_OPERATION("GetDisks", "Successfully enumerated " + std::to_string(disk_list.size()) + " disks");
        LOG_MEMORY("get_disks_complete");
        
        result->Success(flutter::EncodableValue(response));

    } catch (const std::exception& e) {
        LOG_ERROR("Exception in GetDisks: " + std::string(e.what()));
        result->Error("DISK_ENUMERATION_ERROR", std::string("Failed to enumerate disks: ") + e.what());
    }
}

void SquirrelDiskPlugin::PauseScan(std::unique_ptr<flutter::MethodResult<flutter::EncodableValue>> result) {
    // Реализация паузы сканирования
    result->Success();
}

void SquirrelDiskPlugin::ResumeScan(std::unique_ptr<flutter::MethodResult<flutter::EncodableValue>> result) {
    // Реализация возобновления сканирования
    result->Success();
}

void SquirrelDiskPlugin::GetScanStatistics(std::unique_ptr<flutter::MethodResult<flutter::EncodableValue>> result) {
    flutter::EncodableMap stats;
    stats[flutter::EncodableValue("processedItems")] = flutter::EncodableValue(static_cast<int64_t>(processed_items_.load()));
    stats[flutter::EncodableValue("totalFilesFound")] = flutter::EncodableValue(static_cast<int64_t>(total_files_found_.load()));
    stats[flutter::EncodableValue("totalDirectoriesFound")] = flutter::EncodableValue(static_cast<int64_t>(total_directories_found_.load()));
    stats[flutter::EncodableValue("totalSizeProcessed")] = flutter::EncodableValue(static_cast<int64_t>(total_size_processed_.load()));
    stats[flutter::EncodableValue("isScanning")] = flutter::EncodableValue(is_scanning_.load());

    result->Success(flutter::EncodableValue(stats));
}

void SquirrelDiskPlugin::StartScan(
        const flutter::EncodableValue* arguments,
        std::unique_ptr<flutter::MethodResult<flutter::EncodableValue>> result) {

    LOG_OPERATION("StartScan", "Scan request received");

    if (is_scanning_.load()) {
        LOG_WARNING("StartScan called while scan already in progress");
        result->Error("SCAN_IN_PROGRESS", "A scan is already in progress");
        return;
    }

    if (!arguments) {
        LOG_ERROR("StartScan called with null arguments");
        result->Error("INVALID_ARGUMENT", "Arguments cannot be null");
        return;
    }

    const auto* args = std::get_if<flutter::EncodableMap>(arguments);
    if (!args) {
        LOG_ERROR("StartScan called with invalid arguments type");
        result->Error("INVALID_ARGUMENT", "Arguments must be a map");
        return;
    }

    auto path_it = args->find(flutter::EncodableValue("path"));
    if (path_it == args->end()) {
        LOG_ERROR("StartScan called without path argument");
        result->Error("MISSING_ARGUMENT", "Missing 'path' argument");
        return;
    }

    const std::string* path = std::get_if<std::string>(&path_it->second);
    if (!path || path->empty()) {
        LOG_ERROR("StartScan called with empty path");
        result->Error("INVALID_ARGUMENT", "'path' must be a non-empty string");
        return;
    }

    LOG_OPERATION("StartScan", "Starting scan of path: " + *path);
    LOG_MEMORY("scan_start");

    int max_depth = -1;
    auto depth_it = args->find(flutter::EncodableValue("maxDepth"));
    if (depth_it != args->end()) {
        const int32_t* depth_ptr = std::get_if<int32_t>(&depth_it->second);
        if (depth_ptr) {
            max_depth = *depth_ptr;
        }
    }

    bool include_hidden = false;
    auto hidden_it = args->find(flutter::EncodableValue("includeHidden"));
    if (hidden_it != args->end()) {
        const bool* hidden_ptr = std::get_if<bool>(&hidden_it->second);
        if (hidden_ptr) {
            include_hidden = *hidden_ptr;
        }
    }

    is_scanning_.store(true);
    processed_items_.store(0);
    total_files_found_.store(0);
    total_directories_found_.store(0);
    total_size_processed_.store(0);

    if (thread_safe_event_sink_) {
        std::thread([this, scan_path = *path, max_depth, include_hidden]() {
            try {
                LOG_OPERATION("StartScan", "Scan thread started for: " + scan_path);
                LOG_MEMORY("scan_thread_start");
                
                auto send_func = [this](const flutter::EncodableMap& event) {
                    if (thread_safe_event_sink_ && is_scanning_.load()) {
                        thread_safe_event_sink_->SendEventSafe(flutter::EncodableValue(event));
                        PostFlush();
                    }
                };

                auto items = ScanDirectoryOptimized(scan_path, max_depth, 0, include_hidden, send_func);

                if (is_scanning_.load()) {  // Only send completion if not cancelled
                    flutter::EncodableMap completion_event;
                    completion_event[flutter::EncodableValue("type")] = flutter::EncodableValue("completed");
                    completion_event[flutter::EncodableValue("totalItems")] = flutter::EncodableValue(static_cast<int64_t>(items.size()));

                    send_func(completion_event);
                    LOG_OPERATION("StartScan", "Scan completed successfully with " + std::to_string(items.size()) + " items");
                } else {
                    LOG_OPERATION("StartScan", "Scan was cancelled");
                }

            } catch (const std::exception& e) {
                LOG_ERROR("Exception in scan thread: " + std::string(e.what()));
                
                if (thread_safe_event_sink_ && is_scanning_.load()) {
                    flutter::EncodableMap error_event;
                    error_event[flutter::EncodableValue("type")] = flutter::EncodableValue("error");
                    error_event[flutter::EncodableValue("message")] = flutter::EncodableValue(e.what());

                    thread_safe_event_sink_->SendEventSafe(flutter::EncodableValue(error_event));
                    PostFlush();
                }
            } catch (...) {
                LOG_ERROR("Unknown exception in scan thread");
                
                if (thread_safe_event_sink_ && is_scanning_.load()) {
                    flutter::EncodableMap error_event;
                    error_event[flutter::EncodableValue("type")] = flutter::EncodableValue("error");
                    error_event[flutter::EncodableValue("message")] = flutter::EncodableValue("Unknown error occurred during scan");

                    thread_safe_event_sink_->SendEventSafe(flutter::EncodableValue(error_event));
                    PostFlush();
                }
            }

            is_scanning_.store(false);
            LOG_MEMORY("scan_thread_complete");
            LOG_OPERATION("StartScan", "Scan thread finished");
        }).detach();
    } else {
        LOG_ERROR("thread_safe_event_sink_ is null, cannot start scan");
        result->Error("INTERNAL_ERROR", "Event sink not available");
        return;
    }

    result->Success();
}

void SquirrelDiskPlugin::StopScan(std::unique_ptr<flutter::MethodResult<flutter::EncodableValue>> result) {
    LOG_OPERATION("StopScan", "Stop scan requested");
    LOG_MEMORY("stop_scan");
    
    is_scanning_.store(false);
    
    // Clear cache and batches to free memory
    ClearCache();
    {
        std::lock_guard<std::mutex> lock(batch_mutex_);
        current_batch_.clear();
    }
    
    LOG_OPERATION("StopScan", "Scan stopped and resources cleaned up");
    result->Success();
}

void SquirrelDiskPlugin::ShowInFolder(const flutter::EncodableValue* arguments,
                                      std::unique_ptr<flutter::MethodResult<flutter::EncodableValue>> result) {
    if (!arguments) {
        result->Error("INVALID_ARGUMENT", "Arguments cannot be null");
        return;
    }

    const auto* args = std::get_if<flutter::EncodableMap>(arguments);
    if (!args) {
        result->Error("INVALID_ARGUMENT", "Arguments must be a map");
        return;
    }

    auto path_it = args->find(flutter::EncodableValue("path"));
    if (path_it == args->end()) {
        result->Error("MISSING_ARGUMENT", "Missing 'path' argument");
        return;
    }

    const std::string* path = std::get_if<std::string>(&path_it->second);
    if (!path) {
        result->Error("INVALID_ARGUMENT", "'path' must be a string");
        return;
    }

    std::wstring wide_path = StringToWString(*path);
    HINSTANCE hr = ShellExecuteW(nullptr, L"open", L"explorer.exe",
                                 (L"/select,\"" + wide_path + L"\"").c_str(),
                                 nullptr, SW_SHOWNORMAL);

    if (reinterpret_cast<intptr_t>(hr) > 32) {
        result->Success();
    } else {
        result->Error("SHELL_ERROR", "Failed to open folder in explorer");
    }
}

std::string SquirrelDiskPlugin::GetFileExtension(const fs::path& file_path) {
    return WStringToString(file_path.extension().wstring());
}

std::string SquirrelDiskPlugin::DetermineFileType(const fs::directory_entry& entry) {
    std::error_code ec;
    if (entry.is_directory(ec)) {
        return "directory";
    } else if (entry.is_regular_file(ec)) {
        return "file";
    } else if (entry.is_symlink(ec)) {
        return "symlink";
    }
    return "unknown";
}

std::string SquirrelDiskPlugin::GetFileCategory(const std::string& extension) {
    static const std::unordered_map<std::string, std::string> categories = {
            {".txt", "document"}, {".doc", "document"}, {".docx", "document"},
            {".pdf", "document"}, {".xls", "document"}, {".xlsx", "document"},
            {".jpg", "image"}, {".jpeg", "image"}, {".png", "image"}, {".gif", "image"},
            {".mp3", "audio"}, {".wav", "audio"}, {".flac", "audio"},
            {".mp4", "video"}, {".avi", "video"}, {".mkv", "video"},
            {".exe", "executable"}, {".msi", "executable"}, {".bat", "executable"}
    };

    auto it = categories.find(extension);
    return it != categories.end() ? it->second : "other";
}

uint64_t SquirrelDiskPlugin::GetFileTime(const std::filesystem::path& file_path, bool creation_time) {
    try {
        std::error_code ec;
        auto ftime = std::filesystem::last_write_time(file_path, ec);
        if (ec) {
            return 0;
        }

        // Конвертация file_time_type в time_t для Windows
        auto sctp = std::chrono::time_point_cast<std::chrono::system_clock::duration>(
                ftime - std::filesystem::file_time_type::clock::now() + std::chrono::system_clock::now()
        );

        auto time_t_value = std::chrono::system_clock::to_time_t(sctp);
        return static_cast<uint64_t>(time_t_value);
    } catch (...) {
        return 0;
    }
}

bool SquirrelDiskPlugin::IsHidden(const std::filesystem::path& file_path) {
    DWORD attributes = GetFileAttributesW(file_path.wstring().c_str());
    return (attributes != INVALID_FILE_ATTRIBUTES) && (attributes & FILE_ATTRIBUTE_HIDDEN);
}

bool SquirrelDiskPlugin::IsSystem(const std::filesystem::path& file_path) {
    DWORD attributes = GetFileAttributesW(file_path.wstring().c_str());
    return (attributes != INVALID_FILE_ATTRIBUTES) && (attributes & FILE_ATTRIBUTE_SYSTEM);
}

bool SquirrelDiskPlugin::IsReadOnly(const std::filesystem::path& file_path) {
    DWORD attributes = GetFileAttributesW(file_path.wstring().c_str());
    return (attributes != INVALID_FILE_ATTRIBUTES) && (attributes & FILE_ATTRIBUTE_READONLY);
}

SquirrelDiskPlugin::FileSystemItem SquirrelDiskPlugin::CreateFileSystemItem(
        const std::filesystem::directory_entry& entry) {
    FileSystemItem item;
    std::error_code ec;

    // Используем безопасное преобразование строк
    item.path = WStringToString(entry.path().wstring());
    item.name = WStringToString(entry.path().filename().wstring());
    item.type = DetermineFileType(entry);
    item.extension = WStringToString(entry.path().extension().wstring());
    item.is_hidden = IsHidden(entry.path());
    item.is_system = IsSystem(entry.path());
    item.is_readonly = IsReadOnly(entry.path());

    if (entry.is_regular_file(ec)) {
        auto file_size = entry.file_size(ec);
        if (!ec) {
            item.size = file_size;
        }
    }

    item.modified_time = GetFileTime(entry.path(), false);
    item.created_time = GetFileTime(entry.path(), true);

    return item;
}

SquirrelDiskPlugin::FileSystemItem SquirrelDiskPlugin::CreateFileSystemItemFast(
        const std::filesystem::directory_entry& entry,
        const ScanOptions& options) {

    FileSystemItem item;
    std::error_code ec;

    item.path = WStringToString(entry.path().wstring());
    item.name = WStringToString(entry.path().filename().wstring());
    item.type = DetermineFileType(entry);

    if (options.calculate_directory_sizes || entry.is_regular_file(ec)) {
        auto file_size = entry.file_size(ec);
        if (!ec) {
            item.size = file_size;
        }
    }

    if (!options.file_type_filters.empty()) {
        item.extension = WStringToString(entry.path().extension().wstring());
    }

    return item;
}

flutter::EncodableMap SquirrelDiskPlugin::FileSystemItemToMap(const FileSystemItem& item) {
    flutter::EncodableMap map;
    map[flutter::EncodableValue("name")] = flutter::EncodableValue(item.name);
    map[flutter::EncodableValue("path")] = flutter::EncodableValue(item.path);
    map[flutter::EncodableValue("type")] = flutter::EncodableValue(item.type);
    map[flutter::EncodableValue("size")] = flutter::EncodableValue(static_cast<int64_t>(item.size));
    map[flutter::EncodableValue("extension")] = flutter::EncodableValue(item.extension);
    map[flutter::EncodableValue("modifiedTime")] = flutter::EncodableValue(static_cast<int64_t>(item.modified_time));
    map[flutter::EncodableValue("createdTime")] = flutter::EncodableValue(static_cast<int64_t>(item.created_time));
    map[flutter::EncodableValue("isHidden")] = flutter::EncodableValue(item.is_hidden);
    map[flutter::EncodableValue("isSystem")] = flutter::EncodableValue(item.is_system);
    map[flutter::EncodableValue("isReadonly")] = flutter::EncodableValue(item.is_readonly);
    return map;
}

void SquirrelDiskPlugin::CacheItem(const std::string& path, const FileSystemItem& item) {
    std::lock_guard<std::mutex> lock(cache_mutex_);

    if (item_cache_.size() >= MAX_CACHE_SIZE) {
        item_cache_.clear();
    }

    item_cache_[path] = item;
}

std::optional<SquirrelDiskPlugin::FileSystemItem> SquirrelDiskPlugin::GetCachedItem(const std::string& path) {
    std::lock_guard<std::mutex> lock(cache_mutex_);

    auto it = item_cache_.find(path);
    if (it != item_cache_.end()) {
        return it->second;
    }

    return std::nullopt;
}

void SquirrelDiskPlugin::ClearCache() {
    std::lock_guard<std::mutex> lock(cache_mutex_);
    item_cache_.clear();
}

void SquirrelDiskPlugin::AddToBatch(const flutter::EncodableMap& item, const std::string& current_path) {
    std::lock_guard<std::mutex> lock(batch_mutex_);
    current_batch_.items.push_back(item);
    current_batch_.current_path = current_path;
    current_batch_.processed_count++;
}

void SquirrelDiskPlugin::FlushBatch(const std::function<void(flutter::EncodableMap)>& send) {
    std::lock_guard<std::mutex> lock(batch_mutex_);

    if (!current_batch_.items.empty()) {
        flutter::EncodableMap batch_data;
        batch_data[flutter::EncodableValue("type")] = flutter::EncodableValue("batch");
        batch_data[flutter::EncodableValue("items")] = flutter::EncodableValue(current_batch_.items);
        batch_data[flutter::EncodableValue("path")] = flutter::EncodableValue(current_batch_.current_path);
        batch_data[flutter::EncodableValue("count")] = flutter::EncodableValue(static_cast<int64_t>(current_batch_.processed_count));

        send(batch_data);
        current_batch_.clear();
    }
}

void SquirrelDiskPlugin::SendBatchedProgress(const std::function<void(flutter::EncodableMap)>& send) {
    flutter::EncodableMap progress_data;
    progress_data[flutter::EncodableValue("type")] = flutter::EncodableValue("progress");
    progress_data[flutter::EncodableValue("processedItems")] = flutter::EncodableValue(static_cast<int64_t>(processed_items_.load()));
    progress_data[flutter::EncodableValue("totalFilesFound")] = flutter::EncodableValue(static_cast<int64_t>(total_files_found_.load()));
    progress_data[flutter::EncodableValue("totalDirectoriesFound")] = flutter::EncodableValue(static_cast<int64_t>(total_directories_found_.load()));
    progress_data[flutter::EncodableValue("totalSizeProcessed")] = flutter::EncodableValue(static_cast<int64_t>(total_size_processed_.load()));

    send(progress_data);
}

void SquirrelDiskPlugin::SendError(const std::string& error_code, const std::string& message,
                                   const std::function<void(flutter::EncodableMap)>& send) {
    flutter::EncodableMap error_data;
    error_data[flutter::EncodableValue("type")] = flutter::EncodableValue("error");
    error_data[flutter::EncodableValue("code")] = flutter::EncodableValue(error_code);
    error_data[flutter::EncodableValue("message")] = flutter::EncodableValue(message);

    send(error_data);
}

void SquirrelDiskPlugin::SendProgress(const std::string& current_path,
                                      const std::function<void(flutter::EncodableMap)>& send) {
    flutter::EncodableMap progress_data;
    progress_data[flutter::EncodableValue("type")] = flutter::EncodableValue("progress");
    progress_data[flutter::EncodableValue("currentPath")] = flutter::EncodableValue(current_path);
    progress_data[flutter::EncodableValue("processedItems")] = flutter::EncodableValue(static_cast<int64_t>(processed_items_.load()));

    send(progress_data);
}

void SquirrelDiskPlugin::SendStatistics(const std::function<void(flutter::EncodableMap)>& send) {
    flutter::EncodableMap stats_data;
    stats_data[flutter::EncodableValue("type")] = flutter::EncodableValue("statistics");
    stats_data[flutter::EncodableValue("totalFilesFound")] = flutter::EncodableValue(static_cast<int64_t>(total_files_found_.load()));
    stats_data[flutter::EncodableValue("totalDirectoriesFound")] = flutter::EncodableValue(static_cast<int64_t>(total_directories_found_.load()));
    stats_data[flutter::EncodableValue("totalSizeProcessed")] = flutter::EncodableValue(static_cast<int64_t>(total_size_processed_.load()));

    send(stats_data);
}

void SquirrelDiskPlugin::SendEvent(const std::string& event_type, const flutter::EncodableMap& data,
                                   const std::function<void(flutter::EncodableMap)>& send) {
    flutter::EncodableMap event_data = data;
    event_data[flutter::EncodableValue("type")] = flutter::EncodableValue(event_type);
    send(event_data);
}

void SquirrelDiskPlugin::UpdateScanStatistics(const FileSystemItem& item) {
    processed_items_.fetch_add(1);

    if (item.type == "file") {
        total_files_found_.fetch_add(1);
        total_size_processed_.fetch_add(item.size);
    } else if (item.type == "directory") {
        total_directories_found_.fetch_add(1);
    }
}

bool SquirrelDiskPlugin::ShouldSkipFile(const FileSystemItem& item, const ScanOptions& options) {
    if (!options.include_hidden && item.is_hidden) return true;
    if (!options.include_system && item.is_system) return true;

    if (item.type == "file") {
        if (item.size < options.min_file_size || item.size > options.max_file_size) {
            return true;
        }

        if (!options.file_type_filters.empty()) {
            bool matches_filter = false;
            for (const auto& filter : options.file_type_filters) {
                if (item.extension == filter) {
                    matches_filter = true;
                    break;
                }
            }
            if (!matches_filter) return true;
        }
    }

    return false;
}

flutter::EncodableList SquirrelDiskPlugin::ScanDirectory(const std::string& path, int max_depth, int current_depth,
                                                         const std::function<void(flutter::EncodableMap)>& send) {
    flutter::EncodableList items;

    if (!is_scanning_.load() || (max_depth >= 0 && current_depth >= max_depth)) {
        return items;
    }

    try {
        std::error_code ec;
        for (const auto& entry : std::filesystem::directory_iterator(path, ec)) {
            if (!is_scanning_.load()) break;

            auto item = CreateFileSystemItem(entry);
            UpdateScanStatistics(item);

            auto item_map = FileSystemItemToMap(item);
            items.push_back(flutter::EncodableValue(item_map));

            AddToBatch(item_map, path);

            if (current_batch_.items.size() >= BATCH_SIZE) {
                FlushBatch(send);
            }

            if (entry.is_directory(ec) && max_depth != 0) {
                auto sub_items = ScanDirectory(entry.path().string(), max_depth, current_depth + 1, send);
                items.insert(items.end(), sub_items.begin(), sub_items.end());
            }
        }

        FlushBatch(send);

    } catch (const std::exception& e) {
        SendError("SCAN_ERROR", e.what(), send);
    }

    return items;
}

flutter::EncodableList SquirrelDiskPlugin::ScanDirectoryOptimized(
        const std::string& path, int max_depth, int current_depth, bool include_hidden,
        const std::function<void(flutter::EncodableMap)>& send) {

    flutter::EncodableList items;

    if (!is_scanning_.load() || (max_depth >= 0 && current_depth >= max_depth)) {
        LOG_DEBUG("Scan stopped - scanning: " + std::to_string(is_scanning_.load()) + ", depth: " + std::to_string(current_depth));
        return items;
    }

    LOG_DEBUG("Scanning directory: " + path + " (depth: " + std::to_string(current_depth) + ")");
    LOG_MEMORY("scan_directory_" + std::to_string(current_depth));

    try {
        std::error_code ec;
        
        // Check if path exists and is accessible
        if (!std::filesystem::exists(path, ec) || ec) {
            LOG_WARNING("Path does not exist or is not accessible: " + path + " | Error: " + ec.message());
            return items;
        }

        size_t processed_count = 0;
        
        for (const auto& entry : std::filesystem::directory_iterator(path, ec)) {
            if (!is_scanning_.load()) {
                LOG_DEBUG("Scan cancelled during directory iteration");
                break;
            }

            if (ec) {
                LOG_WARNING("Directory iterator error: " + ec.message());
                ec.clear();
                continue;
            }

            try {
                if (!include_hidden && IsHidden(entry.path())) {
                    continue;
                }

                FileSystemItem item = CreateFileSystemItem(entry);
                UpdateScanStatistics(item);
                AddToBatch(FileSystemItemToMap(item), entry.path().string());
                processed_count++;

                if (current_batch_.items.size() >= BATCH_SIZE) {
                    FlushBatch(send);
                }

                // Check memory usage periodically
                if (processed_count % 100 == 0) {
                    LOG_MEMORY("scan_batch_" + std::to_string(processed_count));
                }

                if (entry.is_directory(ec) && !ec) {
                    try {
                        auto sub_items = ScanDirectoryOptimized(
                            entry.path().string(), max_depth, current_depth + 1, include_hidden, send);
                        
                        // Reserve space to prevent frequent reallocations
                        items.reserve(items.size() + sub_items.size());
                        items.insert(items.end(), sub_items.begin(), sub_items.end());
                    } catch (const std::exception& e) {
                        LOG_ERROR("Error scanning subdirectory " + entry.path().string() + ": " + e.what());
                        // Continue with next item instead of failing entire scan
                    }
                }
                
            } catch (const std::exception& e) {
                LOG_ERROR("Error processing entry " + entry.path().string() + ": " + e.what());
                // Continue with next entry
                continue;
            }
        }

        FlushBatch(send);
        LOG_DEBUG("Completed directory scan: " + path + " (processed " + std::to_string(processed_count) + " items)");

    } catch (const std::exception& e) {
        LOG_ERROR("Exception in ScanDirectoryOptimized for " + path + ": " + e.what());
        SendError("SCAN_ERROR", e.what(), send);
    } catch (...) {
        LOG_ERROR("Unknown exception in ScanDirectoryOptimized for " + path);
        SendError("SCAN_ERROR", "Unknown error occurred during scan", send);
    }

    LOG_MEMORY("scan_directory_complete_" + std::to_string(current_depth));
    return items;
}

flutter::EncodableList SquirrelDiskPlugin::ScanDirectoryFast(
        const std::string& path,
        const ScanOptions& options,
        const std::function<void(flutter::EncodableMap)>& send) {

    flutter::EncodableList items;

    if (!is_scanning_.load()) return items;

    std::error_code ec;
    const auto opts = std::filesystem::directory_options::skip_permission_denied;

    try {
        for (const auto& entry : std::filesystem::directory_iterator(path, opts, ec)) {
            if (!is_scanning_.load()) break;

            auto item = CreateFileSystemItemFast(entry, options);

            if (ShouldSkipFile(item, options)) continue;

            UpdateScanStatistics(item);

            auto item_map = FileSystemItemToMap(item);
            items.push_back(flutter::EncodableValue(item_map));

            AddToBatch(item_map, path);

            if (current_batch_.items.size() >= BATCH_SIZE) {
                FlushBatch(send);
            }

            if (entry.is_directory(ec) &&
                (options.max_depth < 0 || options.max_depth > 0)) {

                ScanOptions sub_options = options;
                if (sub_options.max_depth > 0) {
                    sub_options.max_depth--;
                }

                auto sub_items = ScanDirectoryFast(entry.path().string(), sub_options, send);
                items.insert(items.end(), sub_items.begin(), sub_items.end());
            }
        }

        FlushBatch(send);

    } catch (const std::exception& e) {
        SendError("SCAN_ERROR", e.what(), send);
    }

    return items;
}

void SquirrelDiskPlugin::DeleteFileOrFolder(const flutter::EncodableValue* arguments,
                                          std::unique_ptr<flutter::MethodResult<flutter::EncodableValue>> result) {
    LOG_OPERATION("DeleteFileOrFolder", "Delete operation requested");
    
    if (!arguments) {
        LOG_ERROR("DeleteFileOrFolder called with null arguments");
        result->Error("INVALID_ARGUMENT", "Arguments cannot be null");
        return;
    }

    const auto* args = std::get_if<flutter::EncodableMap>(arguments);
    if (!args) {
        LOG_ERROR("DeleteFileOrFolder called with invalid arguments type");
        result->Error("INVALID_ARGUMENT", "Arguments must be a map");
        return;
    }

    auto path_it = args->find(flutter::EncodableValue("path"));
    if (path_it == args->end()) {
        LOG_ERROR("DeleteFileOrFolder called without path argument");
        result->Error("MISSING_ARGUMENT", "Missing 'path' argument");
        return;
    }

    const std::string* path = std::get_if<std::string>(&path_it->second);
    if (!path || path->empty()) {
        LOG_ERROR("DeleteFileOrFolder called with empty path");
        result->Error("INVALID_ARGUMENT", "'path' must be a non-empty string");
        return;
    }

    // Check if force deletion is requested
    bool force_delete = false;
    auto force_it = args->find(flutter::EncodableValue("force"));
    if (force_it != args->end()) {
        const bool* force_ptr = std::get_if<bool>(&force_it->second);
        if (force_ptr) {
            force_delete = *force_ptr;
        }
    }

    LOG_OPERATION("DeleteFileOrFolder", "Deleting: " + *path + " (force: " + (force_delete ? "true" : "false") + ")");

    try {
        std::filesystem::path fs_path(*path);
        std::error_code ec;

        // Check if path exists
        if (!std::filesystem::exists(fs_path, ec)) {
            LOG_WARNING("DeleteFileOrFolder: Path does not exist: " + *path);
            result->Error("PATH_NOT_FOUND", "Path does not exist: " + *path);
            return;
        }

        // Security check: prevent deletion of system-critical paths
        std::string lower_path = *path;
        std::transform(lower_path.begin(), lower_path.end(), lower_path.begin(), ::tolower);
        if (lower_path.find("c:\\windows") == 0 || lower_path.find("c:\\program files") == 0) {
            LOG_ERROR("DeleteFileOrFolder: Attempted to delete system critical path: " + *path);
            result->Error("SECURITY_ERROR", "Cannot delete system critical paths");
            return;
        }

        // Prepare for deletion
        bool success = false;
        std::string error_message;

        if (force_delete) {
            // Force deletion - remove all files and folders recursively
            if (std::filesystem::is_directory(fs_path, ec)) {
                success = std::filesystem::remove_all(fs_path, ec) > 0;
            } else {
                success = std::filesystem::remove(fs_path, ec);
            }
            
            if (!success && ec) {
                error_message = ec.message();
            }
        } else {
            // Safe deletion - move to recycle bin using Windows API
            std::wstring wide_path = StringToWString(*path);
            
            // Add double null terminator required by SHFileOperation
            wide_path.push_back(L'\0');
            
            SHFILEOPSTRUCTW file_op = {};
            file_op.wFunc = FO_DELETE;
            file_op.pFrom = wide_path.c_str();
            file_op.fFlags = FOF_ALLOWUNDO | FOF_NOCONFIRMATION | FOF_SILENT;
            
            int shell_result = SHFileOperationW(&file_op);
            success = (shell_result == 0 && !file_op.fAnyOperationsAborted);
            
            if (!success) {
                error_message = "Shell operation failed with code: " + std::to_string(shell_result);
            }
        }

        if (success) {
            LOG_OPERATION("DeleteFileOrFolder", "Successfully deleted: " + *path);
            flutter::EncodableMap response;
            response[flutter::EncodableValue("success")] = flutter::EncodableValue(true);
            response[flutter::EncodableValue("path")] = flutter::EncodableValue(*path);
            response[flutter::EncodableValue("method")] = flutter::EncodableValue(force_delete ? "permanent" : "recycle_bin");
            result->Success(flutter::EncodableValue(response));
        } else {
            LOG_ERROR("DeleteFileOrFolder failed: " + *path + " | Error: " + error_message);
            result->Error("DELETE_FAILED", 
                         "Failed to delete path: " + *path + 
                         (error_message.empty() ? "" : " (" + error_message + ")"));
        }

    } catch (const std::exception& e) {
        LOG_ERROR("Exception in DeleteFileOrFolder: " + std::string(e.what()));
        result->Error("DELETE_ERROR", std::string("Delete operation failed: ") + e.what());
    }
}

void SquirrelDiskPlugin::GetFileProperties(const flutter::EncodableValue* arguments,
                                         std::unique_ptr<flutter::MethodResult<flutter::EncodableValue>> result) {
    if (!arguments) {
        result->Error("INVALID_ARGUMENT", "Arguments cannot be null");
        return;
    }

    const auto* args = std::get_if<flutter::EncodableMap>(arguments);
    if (!args) {
        result->Error("INVALID_ARGUMENT", "Arguments must be a map");
        return;
    }

    auto path_it = args->find(flutter::EncodableValue("path"));
    if (path_it == args->end()) {
        result->Error("MISSING_ARGUMENT", "Missing 'path' argument");
        return;
    }

    const std::string* path = std::get_if<std::string>(&path_it->second);
    if (!path || path->empty()) {
        result->Error("INVALID_ARGUMENT", "'path' must be a non-empty string");
        return;
    }

    try {
        std::filesystem::path fs_path(*path);
        std::error_code ec;

        if (!std::filesystem::exists(fs_path, ec)) {
            result->Error("PATH_NOT_FOUND", "Path does not exist: " + *path);
            return;
        }

        flutter::EncodableMap properties;
        properties[flutter::EncodableValue("path")] = flutter::EncodableValue(*path);
        properties[flutter::EncodableValue("name")] = flutter::EncodableValue(fs_path.filename().string());
        properties[flutter::EncodableValue("extension")] = flutter::EncodableValue(fs_path.extension().string());
        
        bool is_directory = std::filesystem::is_directory(fs_path, ec);
        properties[flutter::EncodableValue("isDirectory")] = flutter::EncodableValue(is_directory);
        properties[flutter::EncodableValue("isFile")] = flutter::EncodableValue(!is_directory);
        properties[flutter::EncodableValue("isHidden")] = flutter::EncodableValue(IsHidden(fs_path));
        properties[flutter::EncodableValue("isSystem")] = flutter::EncodableValue(IsSystem(fs_path));
        properties[flutter::EncodableValue("isReadOnly")] = flutter::EncodableValue(IsReadOnly(fs_path));

        // Get file times
        auto write_time = std::filesystem::last_write_time(fs_path, ec);
        if (!ec) {
            auto sctp = std::chrono::time_point_cast<std::chrono::system_clock::duration>(
                write_time - std::filesystem::file_time_type::clock::now() + std::chrono::system_clock::now()
            );
            auto time_t_value = std::chrono::system_clock::to_time_t(sctp);
            properties[flutter::EncodableValue("lastModified")] = flutter::EncodableValue(static_cast<int64_t>(time_t_value) * 1000);
        }

        // Get file size
        if (is_directory) {
            // Calculate directory size
            uint64_t total_size = 0;
            uint64_t file_count = 0;
            uint64_t dir_count = 0;

            for (const auto& entry : std::filesystem::recursive_directory_iterator(fs_path, ec)) {
                if (ec) break;
                
                if (entry.is_regular_file(ec)) {
                    total_size += entry.file_size(ec);
                    file_count++;
                } else if (entry.is_directory(ec)) {
                    dir_count++;
                }
            }

            properties[flutter::EncodableValue("size")] = flutter::EncodableValue(static_cast<int64_t>(total_size));
            properties[flutter::EncodableValue("fileCount")] = flutter::EncodableValue(static_cast<int64_t>(file_count));
            properties[flutter::EncodableValue("directoryCount")] = flutter::EncodableValue(static_cast<int64_t>(dir_count));
        } else {
            auto file_size = std::filesystem::file_size(fs_path, ec);
            if (!ec) {
                properties[flutter::EncodableValue("size")] = flutter::EncodableValue(static_cast<int64_t>(file_size));
            }
        }

        // Get parent directory
        if (fs_path.has_parent_path()) {
            properties[flutter::EncodableValue("parentPath")] = flutter::EncodableValue(fs_path.parent_path().string());
        }

        result->Success(flutter::EncodableValue(properties));

    } catch (const std::exception& e) {
        result->Error("PROPERTIES_ERROR", std::string("Failed to get file properties: ") + e.what());
    }
}

void SquirrelDiskPlugin::OpenFile(const flutter::EncodableValue* arguments,
                                std::unique_ptr<flutter::MethodResult<flutter::EncodableValue>> result) {
    if (!arguments) {
        result->Error("INVALID_ARGUMENT", "Arguments cannot be null");
        return;
    }

    const auto* args = std::get_if<flutter::EncodableMap>(arguments);
    if (!args) {
        result->Error("INVALID_ARGUMENT", "Arguments must be a map");
        return;
    }

    auto path_it = args->find(flutter::EncodableValue("path"));
    if (path_it == args->end()) {
        result->Error("MISSING_ARGUMENT", "Missing 'path' argument");
        return;
    }

    const std::string* path = std::get_if<std::string>(&path_it->second);
    if (!path || path->empty()) {
        result->Error("INVALID_ARGUMENT", "'path' must be a non-empty string");
        return;
    }

    try {
        std::wstring wide_path = StringToWString(*path);
        
        // Use ShellExecute to open the file with the default application
        HINSTANCE hr = ShellExecuteW(nullptr, L"open", wide_path.c_str(), nullptr, nullptr, SW_SHOWNORMAL);
        
        if (reinterpret_cast<intptr_t>(hr) > 32) {
            flutter::EncodableMap response;
            response[flutter::EncodableValue("success")] = flutter::EncodableValue(true);
            response[flutter::EncodableValue("path")] = flutter::EncodableValue(*path);
            result->Success(flutter::EncodableValue(response));
        } else {
            std::string error_message = "Failed to open file. Error code: " + std::to_string(reinterpret_cast<intptr_t>(hr));
            result->Error("OPEN_FILE_ERROR", error_message);
        }

    } catch (const std::exception& e) {
        result->Error("OPEN_FILE_ERROR", std::string("Failed to open file: ") + e.what());
    }
}

} // namespace squirreldisk_windows

// C API for plugin registration
extern "C" __declspec(dllexport) void SquirrelDiskPluginRegisterWithRegistrar(
    FlutterDesktopPluginRegistrarRef registrar) {
    squirreldisk_windows::SquirrelDiskPlugin::RegisterWithRegistrar(
        flutter::PluginRegistrarManager::GetInstance()
            ->GetRegistrar<flutter::PluginRegistrarWindows>(registrar));
}