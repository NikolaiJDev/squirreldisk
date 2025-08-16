#include "thread_safe_scan_event_sink.h"

ThreadSafeScanEventSink::ThreadSafeScanEventSink() = default;

ThreadSafeScanEventSink::~ThreadSafeScanEventSink() = default;

void ThreadSafeScanEventSink::SetEventSink(
        std::unique_ptr <flutter::EventSink<flutter::EncodableValue>> sink) {
    std::lock_guard <std::mutex> lock(queue_mutex_);
    event_sink_ = std::move(sink);
}

void ThreadSafeScanEventSink::SendEventSafe(const flutter::EncodableValue &event) {
    std::lock_guard <std::mutex> lock(queue_mutex_);
    event_queue_.push(event);
}

void ThreadSafeScanEventSink::Flush() {
    ProcessQueuedEvents();
}

void ThreadSafeScanEventSink::ProcessQueuedEvents() {
    std::queue <flutter::EncodableValue> local;

    std::lock_guard <std::mutex> lock(queue_mutex_);

    if (!event_sink_) return;

    std::swap(local, event_queue_);

    while (!local.empty()) {
        if (event_sink_) {
            event_sink_->Success(local.front());
        }
        local.pop();
    }
}