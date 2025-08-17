#include "logger.h"
#include <filesystem>

// Ensure ERROR macro doesn't conflict with our enum
#ifdef ERROR
#undef ERROR
#endif

#include <windows.h>
#include <psapi.h>
#include <iostream>

namespace fs = std::filesystem;

namespace squirreldisk_windows {

bool Logger::initialize(const std::string& log_dir) {
    std::lock_guard<std::mutex> lock(log_mutex_);
    
    if (initialized_) {
        return true;
    }

    try {
        // Determine log directory
        std::string actual_log_dir = log_dir;
        if (actual_log_dir.empty()) {
            // Use current directory/logs
            actual_log_dir = fs::current_path().string() + "\\logs";
        }

        // Create log directory if it doesn't exist
        if (!fs::exists(actual_log_dir)) {
            fs::create_directories(actual_log_dir);
        }

        // Create log file with timestamp
        auto now = std::chrono::system_clock::now();
        auto time_t = std::chrono::system_clock::to_time_t(now);
        std::stringstream ss;
        ss << std::put_time(std::localtime(&time_t), "%Y%m%d_%H%M%S");
        
        log_file_path_ = actual_log_dir + "\\squirreldisk_plugin_" + ss.str() + ".log";
        
        log_file_ = std::make_unique<std::ofstream>(log_file_path_, std::ios::out | std::ios::app);
        
        if (!log_file_->is_open()) {
            return false;
        }

        initialized_ = true;
        
        // Write initialization header
        writeToFile("=== SQUIRRELDISK WINDOWS PLUGIN LOG ===");
        logSystemInfo();
        writeToFile("========================================");
        
        info("Logger initialized successfully", __FUNCTION__, __LINE__);
        return true;
        
    } catch (const std::exception& e) {
        std::cerr << "Failed to initialize logger: " << e.what() << std::endl;
        return false;
    }
}

void Logger::setLevel(LogLevel level) {
    std::lock_guard<std::mutex> lock(log_mutex_);
    min_level_ = level;
}

void Logger::log(LogLevel level, const std::string& message, const std::string& function, int line) {
    if (level < min_level_ || !initialized_) {
        return;
    }

    std::lock_guard<std::mutex> lock(log_mutex_);
    
    std::stringstream entry;
    entry << "[" << getCurrentTimestamp() << "] "
          << "[" << levelToString(level) << "] ";
    
    if (!function.empty() && line > 0) {
        entry << "[" << function << ":" << line << "] ";
    }
    
    entry << message;
    
    writeToFile(entry.str());
    
    // Also output to debug console for immediate visibility
    OutputDebugStringA((entry.str() + "\n").c_str());
}

void Logger::debug(const std::string& message, const std::string& function, int line) {
    log(LogLevel::DEBUG, message, function, line);
}

void Logger::info(const std::string& message, const std::string& function, int line) {
    log(LogLevel::INFO, message, function, line);
}

void Logger::warning(const std::string& message, const std::string& function, int line) {
    log(LogLevel::WARNING, message, function, line);
}

void Logger::error(const std::string& message, const std::string& function, int line) {
    log(LogLevel::ERROR, message, function, line);
}

void Logger::fatal(const std::string& message, const std::string& function, int line) {
    log(LogLevel::FATAL, message, function, line);
    flush(); // Ensure fatal errors are immediately written
}

void Logger::logOperation(const std::string& operation, const std::string& details) {
    std::string message = "Operation: " + operation;
    if (!details.empty()) {
        message += " | " + details;
    }
    info(message, __FUNCTION__, __LINE__);
}

void Logger::logPluginCall(const std::string& method, const std::string& args) {
    std::string message = "Plugin call: " + method;
    if (!args.empty()) {
        message += " with args: " + args;
    }
    debug(message, __FUNCTION__, __LINE__);
}

void Logger::logScanProgress(const std::string& path, int processed, int total) {
    std::stringstream ss;
    ss << "Scan progress: " << path << " | " << processed << "/" << total;
    if (total > 0) {
        ss << " (" << std::fixed << std::setprecision(1) << (static_cast<double>(processed) / total * 100.0) << "%)";
    }
    debug(ss.str(), __FUNCTION__, __LINE__);
}

void Logger::logFileOperation(const std::string& operation, const std::string& path, bool success, const std::string& error) {
    std::string message = "File operation: " + operation + " on " + path + " - " + (success ? "SUCCESS" : "FAILED");
    if (!success && !error.empty()) {
        message += " | Error: " + error;
    }
    
    if (success) {
        info(message, __FUNCTION__, __LINE__);
    } else {
        error(message, __FUNCTION__, __LINE__);
    }
}

void Logger::logMemoryUsage(const std::string& context) {
    try {
        PROCESS_MEMORY_COUNTERS pmc;
        if (GetProcessMemoryInfo(GetCurrentProcess(), &pmc, sizeof(pmc))) {
            std::stringstream ss;
            ss << "Memory usage in " << context << ": "
               << "WorkingSet=" << (pmc.WorkingSetSize / 1024 / 1024) << "MB, "
               << "PageFile=" << (pmc.PagefileUsage / 1024 / 1024) << "MB, "
               << "PeakWorkingSet=" << (pmc.PeakWorkingSetSize / 1024 / 1024) << "MB";
            debug(ss.str(), __FUNCTION__, __LINE__);
        } else {
            warning("Could not get memory usage for " + context, __FUNCTION__, __LINE__);
        }
    } catch (const std::exception& e) {
        error("Exception getting memory usage: " + std::string(e.what()), __FUNCTION__, __LINE__);
    }
}

void Logger::logSystemInfo() {
    try {
        SYSTEM_INFO si;
        GetSystemInfo(&si);
        
        OSVERSIONINFOEX osvi;
        ZeroMemory(&osvi, sizeof(OSVERSIONINFOEX));
        osvi.dwOSVersionInfoSize = sizeof(OSVERSIONINFOEX);
        
        std::stringstream ss;
        ss << "System Info:";
        ss << "\n  Processor Architecture: " << si.wProcessorArchitecture;
        ss << "\n  Number of Processors: " << si.dwNumberOfProcessors;
        ss << "\n  Page Size: " << si.dwPageSize;
        ss << "\n  Processor Type: " << si.dwProcessorType;
        
        writeToFile(ss.str());
        
        // Log current thread and process info
        std::stringstream thread_info;
        thread_info << "Process/Thread Info:";
        thread_info << "\n  Process ID: " << GetCurrentProcessId();
        thread_info << "\n  Thread ID: " << GetCurrentThreadId();
        
        writeToFile(thread_info.str());
        
    } catch (const std::exception& e) {
        error("Exception logging system info: " + std::string(e.what()), __FUNCTION__, __LINE__);
    }
}

std::string Logger::getCurrentTimestamp() {
    auto now = std::chrono::system_clock::now();
    auto time_t = std::chrono::system_clock::to_time_t(now);
    auto ms = std::chrono::duration_cast<std::chrono::milliseconds>(
        now.time_since_epoch()) % 1000;
    
    std::stringstream ss;
    ss << std::put_time(std::localtime(&time_t), "%Y-%m-%d %H:%M:%S");
    ss << "." << std::setfill('0') << std::setw(3) << ms.count();
    
    return ss.str();
}

std::string Logger::levelToString(LogLevel level) {
    switch (level) {
        case LogLevel::DEBUG: return "DEBUG  ";
        case LogLevel::INFO: return "INFO   ";
        case LogLevel::WARNING: return "WARNING";
        case LogLevel::ERROR: return "ERROR  ";
        case LogLevel::FATAL: return "FATAL  ";
        default: return "UNKNOWN";
    }
}

void Logger::writeToFile(const std::string& entry) {
    if (log_file_ && log_file_->is_open()) {
        *log_file_ << entry << std::endl;
        
        // Check if we need to rotate the log
        static int write_count = 0;
        if (++write_count % 100 == 0) {
            rotateLogIfNeeded();
        }
    }
}

void Logger::rotateLogIfNeeded() {
    try {
        if (!fs::exists(log_file_path_)) {
            return;
        }
        
        auto file_size = fs::file_size(log_file_path_);
        const size_t max_size = 50 * 1024 * 1024; // 50MB
        
        if (file_size > max_size) {
            log_file_->close();
            
            // Create archive name
            auto now = std::chrono::system_clock::now();
            auto time_t = std::chrono::system_clock::to_time_t(now);
            std::stringstream ss;
            ss << log_file_path_ << ".archive_" 
               << std::put_time(std::localtime(&time_t), "%Y%m%d_%H%M%S");
            
            // Move current log to archive
            fs::rename(log_file_path_, ss.str());
            
            // Open new log file
            log_file_ = std::make_unique<std::ofstream>(log_file_path_, std::ios::out | std::ios::app);
            info("Log rotated due to size limit. Archived to: " + ss.str(), __FUNCTION__, __LINE__);
        }
    } catch (const std::exception& e) {
        // Can't log this error as it might cause recursion
        OutputDebugStringA(("Log rotation failed: " + std::string(e.what())).c_str());
    }
}

void Logger::flush() {
    std::lock_guard<std::mutex> lock(log_mutex_);
    if (log_file_ && log_file_->is_open()) {
        log_file_->flush();
    }
}

void Logger::shutdown() {
    std::lock_guard<std::mutex> lock(log_mutex_);
    if (initialized_ && log_file_ && log_file_->is_open()) {
        info("Logger shutting down", __FUNCTION__, __LINE__);
        log_file_->close();
        log_file_.reset();
        initialized_ = false;
    }
}

} // namespace squirreldisk_windows