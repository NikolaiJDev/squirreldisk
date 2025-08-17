#pragma once

// Prevent Windows macros from conflicting with our logger - use ifndef guards
#ifndef WIN32_LEAN_AND_MEAN
#define WIN32_LEAN_AND_MEAN
#endif

#ifndef NOMINMAX
#define NOMINMAX
#endif

#ifdef ERROR
#undef ERROR
#endif

#include <string>
#include <fstream>
#include <memory>
#include <mutex>
#include <chrono>
#include <sstream>
#include <iomanip>

namespace squirreldisk_windows {

    enum class LogLevel {
        DEBUG = 0,
        INFO = 1,
        WARNING = 2,
        ERROR = 3,
        FATAL = 4
    };

    class Logger {
    public:
        static Logger& getInstance() {
            static Logger instance;
            return instance;
        }

        bool initialize(const std::string& log_dir = "");
        void setLevel(LogLevel level);
        void log(LogLevel level, const std::string& message, const std::string& function = "", int line = 0);

        void debug(const std::string& message, const std::string& function = "", int line = 0);
        void info(const std::string& message, const std::string& function = "", int line = 0);
        void warning(const std::string& message, const std::string& function = "", int line = 0);
        void error(const std::string& message, const std::string& function = "", int line = 0);
        void fatal(const std::string& message, const std::string& function = "", int line = 0);

        void logOperation(const std::string& operation, const std::string& details = "");
        void logPluginCall(const std::string& method, const std::string& args = "");
        void logScanProgress(const std::string& path, int processed, int total);
        void logFileOperation(const std::string& operation, const std::string& path, bool success, const std::string& error = "");
        void logMemoryUsage(const std::string& context);
        void logSystemInfo();

        void flush();
        void shutdown();

    private:
        Logger() = default;
        ~Logger() { shutdown(); }

        // Delete copy constructor and assignment operator
        Logger(const Logger&) = delete;
        Logger& operator=(const Logger&) = delete;

        std::string getCurrentTimestamp();
        std::string levelToString(LogLevel level);
        void writeToFile(const std::string& entry);
        void rotateLogIfNeeded();

        std::mutex log_mutex_;
        std::unique_ptr<std::ofstream> log_file_;
        std::string log_file_path_;
        bool initialized_ = false;
        LogLevel min_level_ = LogLevel::DEBUG;
    };

// Convenience macros for logging with automatic function and line info
#define LOG_DEBUG(msg) Logger::getInstance().debug(msg, __FUNCTION__, __LINE__)
#define LOG_INFO(msg) Logger::getInstance().info(msg, __FUNCTION__, __LINE__)
#define LOG_WARNING(msg) Logger::getInstance().warning(msg, __FUNCTION__, __LINE__)
#define LOG_ERROR(msg) Logger::getInstance().error(msg, __FUNCTION__, __LINE__)
#define LOG_FATAL(msg) Logger::getInstance().fatal(msg, __FUNCTION__, __LINE__)
#define LOG_OPERATION(op, details) Logger::getInstance().logOperation(op, details)
#define LOG_PLUGIN_CALL(method, args) Logger::getInstance().logPluginCall(method, args)
#define LOG_MEMORY(context) Logger::getInstance().logMemoryUsage(context)

} // namespace squirreldisk_windows