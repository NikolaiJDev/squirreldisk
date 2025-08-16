// windows/runner/thread_safe_scan_event_sink.h
#include <flutter/encodable_value.h>
#include <flutter/event_sink.h>
#include <queue>
#include <mutex>
#include <memory>

class ThreadSafeScanEventSink {
public:
    ThreadSafeScanEventSink();

    ~ThreadSafeScanEventSink();

    void SetEventSink(std::unique_ptr<flutter::EventSink<flutter::EncodableValue>> sink);

    void SendEventSafe(const flutter::EncodableValue &event);

    void Flush();

    // Add method to safely check if sink is available
    bool HasEventSink() const {
        std::lock_guard<std::mutex> lock(queue_mutex_);
        return event_sink_ != nullptr;
    }

    // Add method to get queue size for monitoring
    size_t GetQueueSize() const {
        std::lock_guard<std::mutex> lock(queue_mutex_);
        return event_queue_.size();
    }

private:
    void ProcessQueuedEvents();

    std::unique_ptr<flutter::EventSink<flutter::EncodableValue>> event_sink_;
    std::queue<flutter::EncodableValue> event_queue_;
    mutable std::mutex queue_mutex_;
};