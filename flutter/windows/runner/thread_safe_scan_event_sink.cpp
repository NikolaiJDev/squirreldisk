#include "thread_safe_scan_event_sink.h"
#include "logger.h"

using namespace squirreldisk_windows;

ThreadSafeScanEventSink::ThreadSafeScanEventSink() {
    LOG_INFO("ThreadSafeScanEventSink constructor");
}

ThreadSafeScanEventSink::~ThreadSafeScanEventSink() {
    LOG_INFO("ThreadSafeScanEventSink destructor - clearing event queue");
    std::lock_guard<std::mutex> lock(queue_mutex_);
    while (!event_queue_.empty()) {
        event_queue_.pop();
    }
    event_sink_.reset();
    LOG_INFO("ThreadSafeScanEventSink destructor complete");
}

void ThreadSafeScanEventSink::SetEventSink(
        std::unique_ptr<flutter::EventSink<flutter::EncodableValue>> sink) {
    std::lock_guard<std::mutex> lock(queue_mutex_);
    event_sink_ = std::move(sink);
    LOG_INFO("Event sink set");
}

void ThreadSafeScanEventSink::SendEventSafe(const flutter::EncodableValue &event) {
    std::lock_guard<std::mutex> lock(queue_mutex_);
    if (event_queue_.size() > 1000) {  // Prevent unbounded queue growth
        LOG_WARNING("Event queue is getting large, clearing old events");
        std::queue<flutter::EncodableValue> empty;
        std::swap(event_queue_, empty);
    }
    event_queue_.push(event);
    LOG_DEBUG("Event queued, queue size: " + std::to_string(event_queue_.size()));
}

void ThreadSafeScanEventSink::Flush() {
    ProcessQueuedEvents();
}

void ThreadSafeScanEventSink::ProcessQueuedEvents() {
    std::lock_guard<std::mutex> lock(queue_mutex_);

    if (!event_sink_) {
        LOG_WARNING("No event sink available, skipping event processing");
        return;
    }

    size_t processed = 0;
    while (!event_queue_.empty() && event_sink_) {
        try {
            event_sink_->Success(event_queue_.front());
            event_queue_.pop();
            processed++;
        } catch (const std::exception& e) {
            LOG_ERROR("Exception processing event: " + std::string(e.what()));
            event_queue_.pop(); // Remove the problematic event
        } catch (...) {
            LOG_ERROR("Unknown exception processing event");
            event_queue_.pop(); // Remove the problematic event
        }
    }
    
    if (processed > 0) {
        LOG_DEBUG("Processed " + std::to_string(processed) + " events");
    }
}