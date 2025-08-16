#pragma once

#include <string>
#include <fstream>
#include <mutex>
#include <memory>
#include <chrono>
#include <iomanip>
#include <sstream>

namespace squirreldisk_windows {

enum class LogLevel {
    DEBUG = 0,
    INFO = 1,
    WARNING = 2,
    ERROR = 3,
    FATAL = 4
};

class Logger {
private:
    std::unique_ptr<std::ofstream> log_file_;
    std::mutex log_mutex_;
    LogLevel min_level_;
    bool initialized_;
    std::string log_file_path_;

    Logger() : min_level_(LogLevel::DEBUG), initialized_(false) {}

public:
    static Logger& getInstance() {
        static Logger instance;
        return instance;
    }

    bool initialize(const std::string& log_dir = "");
    void setLevel(LogLevel level);
    void log(LogLevel level, const std::string& message, const std::string& function = "", int line = 0);
    void flush();
    void shutdown();
    std::string getLogFilePath() const { return log_file_path_; }

    // Convenience methods
    void debug(const std::string& message, const std::string& function = "", int line = 0);
    void info(const std::string& message, const std::string& function = "", int line = 0);
    void warning(const std::string& message, const std::string& function = "", int line = 0);
    void error(const std::string& message, const std::string& function = "", int line = 0);
    void fatal(const std::string& message, const std::string& function = "", int line = 0);

    // Specialized logging methods
    void logOperation(const std::string& operation, const std::string& details = "");
    void logPluginCall(const std::string& method, const std::string& args = "");
    void logScanProgress(const std::string& path, int processed, int total);
    void logFileOperation(const std::string& operation, const std::string& path, bool success, const std::string& error = "");
    void logMemoryUsage(const std::string& context);
    void logSystemInfo();

private:
    std::string getCurrentTimestamp();
    std::string levelToString(LogLevel level);
    void writeToFile(const std::string& entry);
    void rotateLogIfNeeded();
};

// Macros for easier logging with automatic function name and line number
#define LOG_DEBUG(msg) Logger::getInstance().debug(msg, __FUNCTION__, __LINE__)
#define LOG_INFO(msg) Logger::getInstance().info(msg, __FUNCTION__, __LINE__)
#define LOG_WARNING(msg) Logger::getInstance().warning(msg, __FUNCTION__, __LINE__)
#define LOG_ERROR(msg) Logger::getInstance().error(msg, __FUNCTION__, __LINE__)
#define LOG_FATAL(msg) Logger::getInstance().fatal(msg, __FUNCTION__, __LINE__)

#define LOG_OPERATION(op, details) Logger::getInstance().logOperation(op, details)
#define LOG_PLUGIN_CALL(method, args) Logger::getInstance().logPluginCall(method, args)
#define LOG_FILE_OP(op, path, success, error) Logger::getInstance().logFileOperation(op, path, success, error)
#define LOG_MEMORY(context) Logger::getInstance().logMemoryUsage(context)

} // namespace squirreldisk_windows