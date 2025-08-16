#pragma once

#include <flutter/event_channel.h>
#include <flutter/event_sink.h>
#include <flutter/method_channel.h>
#include <flutter/plugin_registrar_windows.h>
#include <flutter/standard_method_codec.h>
#include <flutter/event_stream_handler_functions.h>

#include "thread_safe_scan_event_sink.h"

#include <map>
#include <memory>
#include <sstream>
#include <windows.h>
#include <filesystem>
#include <functional>
#include <atomic>
#include <algorithm>
#include <unordered_map>
#include <queue>
#include <mutex>
#include <condition_variable>
#include <optional>
#include <thread>

namespace squirreldisk_windows {

    // Структура опций сканирования - объявляем в начале
    struct ScanOptions {
        int max_depth = -1;
        bool include_hidden = false;
        bool include_system = false;
        bool calculate_directory_sizes = true;
        bool use_cache = true;
        std::vector<std::string> file_type_filters;
        uint64_t min_file_size = 0;
        uint64_t max_file_size = UINT64_MAX;
    };

    class SquirrelDiskPlugin : public flutter::Plugin {
    public:
        static void RegisterWithRegistrar(flutter::PluginRegistrarWindows *registrar);
        static void RegisterWithMessenger(flutter::BinaryMessenger *messenger);

        SquirrelDiskPlugin();
        ~SquirrelDiskPlugin() override;

    private:
        // Оптимизированная структура для файловой системы
        struct FileSystemItem {
            std::string name;
            std::string path;
            std::string type;
            uint64_t size = 0;
            std::string extension;
            uint64_t modified_time = 0;
            uint64_t created_time = 0;
            bool is_hidden = false;
            bool is_system = false;
            bool is_readonly = false;

            // Статистика для директорий
            uint64_t total_size = 0;
            uint64_t file_count = 0;
            uint64_t dir_count = 0;

            // Конструктор по умолчанию
            FileSystemItem() = default;

            // Конструктор копирования и оператор присваивания
            FileSystemItem(const FileSystemItem&) = default;
            FileSystemItem& operator=(const FileSystemItem&) = default;

            // Конструктор перемещения для оптимизации
            FileSystemItem(FileSystemItem&&) = default;
            FileSystemItem& operator=(FileSystemItem&&) = default;
        };

        // Структура для батчинга данных
        struct ScanBatch {
            flutter::EncodableList items;  // Изменено с std::vector<flutter::EncodableMap>
            std::string current_path;
            uint64_t processed_count = 0;
            uint64_t total_size = 0;

            void clear() {
                items.clear();
                current_path.clear();
                processed_count = 0;
                total_size = 0;
            }
        };

        // Каналы связи
        std::unique_ptr<flutter::MethodChannel<flutter::EncodableValue>> method_channel_;
        std::unique_ptr<flutter::EventChannel<flutter::EncodableValue>> event_channel_;
        std::unique_ptr<ThreadSafeScanEventSink> thread_safe_event_sink_;

        // Окно для сообщений
        HWND msg_hwnd_ = nullptr;
        static constexpr UINT kMsgFlush = WM_USER + 1;

        // Флаги состояния и счетчики
        std::atomic<bool> is_scanning_{false};
        std::atomic<uint64_t> processed_items_{0};
        std::atomic<uint64_t> total_files_found_{0};
        std::atomic<uint64_t> total_directories_found_{0};
        std::atomic<uint64_t> total_size_processed_{0};

        // Конфигурация для оптимизации
        static constexpr size_t BATCH_SIZE = 50;           // Размер батча для UI
        static constexpr size_t MAX_CACHE_SIZE = 10000;    // Максимальный размер кэша
        static constexpr int PROGRESS_UPDATE_INTERVAL = 25; // Интервал обновления прогресса

        // Кэш для ускорения работы
        std::unordered_map<std::string, FileSystemItem> item_cache_;
        std::mutex cache_mutex_;

        // Батчинг для UI обновлений
        ScanBatch current_batch_;
        std::mutex batch_mutex_;

        // Методы для работы с окном сообщений
        void EnsureMessageWindow();
        void PostFlush() const;
        static LRESULT CALLBACK MsgWndProc(HWND hwnd, UINT msg, WPARAM wparam, LPARAM lparam);

        // Обработчики методов
        void HandleMethodCall(
                const flutter::MethodCall<flutter::EncodableValue> &method_call,
                std::unique_ptr<flutter::MethodResult<flutter::EncodableValue>> result);

        // Основные методы API
        void GetDisks(std::unique_ptr<flutter::MethodResult<flutter::EncodableValue>> result);
        void GetDiskInfo(const flutter::EncodableValue *arguments,
                         std::unique_ptr<flutter::MethodResult<flutter::EncodableValue>> result);
        void StartScan(const flutter::EncodableValue *arguments,
                       std::unique_ptr<flutter::MethodResult<flutter::EncodableValue>> result);
        void StopScan(std::unique_ptr<flutter::MethodResult<flutter::EncodableValue>> result);
        void PauseScan(std::unique_ptr<flutter::MethodResult<flutter::EncodableValue>> result);
        void ResumeScan(std::unique_ptr<flutter::MethodResult<flutter::EncodableValue>> result);
        void ShowInFolder(const flutter::EncodableValue *arguments,
                          std::unique_ptr<flutter::MethodResult<flutter::EncodableValue>> result);
        void GetScanStatistics(std::unique_ptr<flutter::MethodResult<flutter::EncodableValue>> result);
        void DeleteFileOrFolder(const flutter::EncodableValue *arguments,
                               std::unique_ptr<flutter::MethodResult<flutter::EncodableValue>> result);
        void GetFileProperties(const flutter::EncodableValue *arguments,
                              std::unique_ptr<flutter::MethodResult<flutter::EncodableValue>> result);
        void OpenFile(const flutter::EncodableValue *arguments,
                     std::unique_ptr<flutter::MethodResult<flutter::EncodableValue>> result);

        // Оптимизированные методы сканирования
        flutter::EncodableList ScanDirectory(const std::string& path, int max_depth, int current_depth,
                                             const std::function<void(flutter::EncodableMap)>& send);
        flutter::EncodableList ScanDirectoryOptimized(const std::string& path, int max_depth,
                                                      int current_depth, bool include_hidden,
                                                      const std::function<void(flutter::EncodableMap)>& send);
        flutter::EncodableList ScanDirectoryFast(const std::string& path,
                                                 const ScanOptions& options,
                                                 const std::function<void(flutter::EncodableMap)>& send);

        // Методы для работы с файловой системой
        flutter::EncodableMap FileSystemItemToMap(const FileSystemItem& item);
        FileSystemItem CreateFileSystemItem(const std::filesystem::directory_entry& entry);
        FileSystemItem CreateFileSystemItemFast(const std::filesystem::directory_entry& entry,
                                                const ScanOptions& options);

        // Утилиты для файлов
        std::string GetFileExtension(const std::filesystem::path& file_path);
        std::string DetermineFileType(const std::filesystem::directory_entry& entry);
        std::string GetFileCategory(const std::string& extension);
        uint64_t GetFileTime(const std::filesystem::path& file_path, bool creation_time = false);
        bool IsHidden(const std::filesystem::path& file_path);
        bool IsSystem(const std::filesystem::path& file_path);
        bool IsReadOnly(const std::filesystem::path& file_path);

        // Методы для работы с кэшем
        void CacheItem(const std::string& path, const FileSystemItem& item);
        std::optional<FileSystemItem> GetCachedItem(const std::string& path);
        void ClearCache();

        // Методы для батчинга
        void AddToBatch(const flutter::EncodableMap& item, const std::string& current_path);
        void FlushBatch(const std::function<void(flutter::EncodableMap)>& send);
        void SendBatchedProgress(const std::function<void(flutter::EncodableMap)>& send);

        // Обработка событий и ошибок
        void SendError(const std::string& error_code, const std::string& message,
                       const std::function<void(flutter::EncodableMap)>& send);
        void SendProgress(const std::string& current_path,
                          const std::function<void(flutter::EncodableMap)>& send);
        void SendStatistics(const std::function<void(flutter::EncodableMap)>& send);
        void SendEvent(const std::string& event_type, const flutter::EncodableMap& data,
                       const std::function<void(flutter::EncodableMap)>& send);

        // Методы для анализа дискового пространства
        flutter::EncodableMap AnalyzeDiskUsage(const std::string& path);
        flutter::EncodableList GetLargestFiles(const std::string& path, int limit = 10);
        flutter::EncodableList GetLargestDirectories(const std::string& path, int limit = 10);
        flutter::EncodableMap GetFileTypeDistribution(const std::string& path);

        // Дополнительные утилиты
        std::string FormatSize(uint64_t size);
        double CalculateProgress(uint64_t processed, uint64_t total);
        bool ShouldSkipFile(const FileSystemItem& item, const ScanOptions& options);
        void UpdateScanStatistics(const FileSystemItem& item);
    };

} // namespace squirreldisk_windows