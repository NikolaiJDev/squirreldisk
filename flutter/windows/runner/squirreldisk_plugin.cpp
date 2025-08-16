#include "squirreldisk_plugin.h"

#include <filesystem>
#include <shellapi.h>
#include <thread>
#include <vector>
#include <windows.h>
#include <shlwapi.h>
#include <iostream>
#include <chrono>
#include <ctime>
#include <optional>

#include <flutter/event_stream_handler_functions.h>

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

    SquirrelDiskPlugin::SquirrelDiskPlugin() = default;

    SquirrelDiskPlugin::~SquirrelDiskPlugin() = default;

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
    } else {
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
    flutter::EncodableList disk_list;

    DWORD drives = GetLogicalDrives();
    for (char drive = 'A'; drive <= 'Z'; ++drive) {
        if (drives & (1 << (drive - 'A'))) {
            std::string drive_path = std::string(1, drive) + ":\\";

            UINT drive_type = GetDriveTypeA(drive_path.c_str());
            std::string type_name;

            switch (drive_type) {
                case DRIVE_FIXED: type_name = "fixed"; break;
                case DRIVE_REMOVABLE: type_name = "removable"; break;
                case DRIVE_REMOTE: type_name = "network"; break;
                case DRIVE_CDROM: type_name = "cdrom"; break;
                case DRIVE_RAMDISK: type_name = "ramdisk"; break;
                default: type_name = "unknown"; break;
            }

            // Получение метки диска и файловой системы
            std::string disk_label;
            std::string file_system;
            wchar_t volume_name[MAX_PATH + 1] = {0};
            wchar_t file_system_name[MAX_PATH + 1] = {0};
            std::wstring wide_drive_path = StringToWString(drive_path);

            if (GetVolumeInformationW(wide_drive_path.c_str(), volume_name, MAX_PATH + 1,
                                      nullptr, nullptr, nullptr, file_system_name, MAX_PATH + 1)) {
                disk_label = WStringToString(std::wstring(volume_name));
                file_system = WStringToString(std::wstring(file_system_name));
            }

            if (disk_label.empty()) {
                disk_label = "Local Disk (" + std::string(1, drive) + ":)";
            }

            if (file_system.empty()) {
                file_system = "Unknown";
            }

            flutter::EncodableMap disk_info;
            disk_info[flutter::EncodableValue("name")] = flutter::EncodableValue(disk_label);
            disk_info[flutter::EncodableValue("mountPoint")] = flutter::EncodableValue(drive_path);
            disk_info[flutter::EncodableValue("type")] = flutter::EncodableValue(type_name);
            disk_info[flutter::EncodableValue("fileSystem")] = flutter::EncodableValue(file_system);

            ULARGE_INTEGER free_bytes, total_bytes;
            if (GetDiskFreeSpaceExA(drive_path.c_str(), &free_bytes, &total_bytes, nullptr)) {
                int64_t total_space = static_cast<int64_t>(total_bytes.QuadPart);
                int64_t free_space = static_cast<int64_t>(free_bytes.QuadPart);
                int64_t used_space = total_space - free_space;

                disk_info[flutter::EncodableValue("totalSpace")] = flutter::EncodableValue(total_space);
                disk_info[flutter::EncodableValue("freeSpace")] = flutter::EncodableValue(free_space);
                disk_info[flutter::EncodableValue("usedSpace")] = flutter::EncodableValue(used_space);
            } else {
                disk_info[flutter::EncodableValue("totalSpace")] = flutter::EncodableValue(static_cast<int64_t>(0));
                disk_info[flutter::EncodableValue("freeSpace")] = flutter::EncodableValue(static_cast<int64_t>(0));
                disk_info[flutter::EncodableValue("usedSpace")] = flutter::EncodableValue(static_cast<int64_t>(0));
            }

            disk_list.push_back(flutter::EncodableValue(disk_info));
        }
    }

    result->Success(flutter::EncodableValue(disk_list));
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

    if (is_scanning_.load()) {
        result->Error("SCAN_IN_PROGRESS", "A scan is already in progress");
        return;
    }

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
                auto send_func = [this](const flutter::EncodableMap& event) {
                    thread_safe_event_sink_->SendEventSafe(flutter::EncodableValue(event));
                    PostFlush();
                };

                auto items = ScanDirectoryOptimized(scan_path, max_depth, 0, include_hidden, send_func);

                flutter::EncodableMap completion_event;
                completion_event[flutter::EncodableValue("type")] = flutter::EncodableValue("completed");
                completion_event[flutter::EncodableValue("totalItems")] = flutter::EncodableValue(static_cast<int64_t>(items.size()));

                send_func(completion_event);

            } catch (const std::exception& e) {
                flutter::EncodableMap error_event;
                error_event[flutter::EncodableValue("type")] = flutter::EncodableValue("error");
                error_event[flutter::EncodableValue("message")] = flutter::EncodableValue(e.what());

                thread_safe_event_sink_->SendEventSafe(flutter::EncodableValue(error_event));
                PostFlush();
            }

            is_scanning_.store(false);
        }).detach();
    }

    result->Success();
}

void SquirrelDiskPlugin::StopScan(std::unique_ptr<flutter::MethodResult<flutter::EncodableValue>> result) {
    is_scanning_.store(false);
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
        return items;
    }

    try {
        std::error_code ec;
        for (const auto& entry : std::filesystem::directory_iterator(path, ec)) {
            if (!is_scanning_.load()) break;

            if (!include_hidden && IsHidden(entry.path())) {
                continue;
            }

            FileSystemItem item = CreateFileSystemItem(entry);
            UpdateScanStatistics(item);
            AddToBatch(FileSystemItemToMap(item), entry.path().string());

            if (current_batch_.items.size() >= BATCH_SIZE) {
                FlushBatch(send);
            }

            if (entry.is_directory(ec)) {
                auto sub_items = ScanDirectoryOptimized(
                        entry.path().string(), max_depth, current_depth + 1, include_hidden, send);
                items.insert(items.end(), sub_items.begin(), sub_items.end());
            }
        }

        FlushBatch(send);

    } catch (const std::exception& e) {
        SendError("SCAN_ERROR", e.what(), send);
    }

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

} // namespace squirreldisk_windows