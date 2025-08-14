#include "flutter/flutter_window_controller.h"

#include <flutter/event_channel.h>
#include <flutter/event_sink.h>
#include <flutter/event_stream_handler_functions.h>
#include <flutter/method_channel.h>
#include <flutter/plugin_registrar_windows.h>
#include <flutter/standard_method_codec.h>

#include <map>
#include <memory>
#include <sstream>

#include "runner.h"

namespace squirreldisk_windows {

class SquirrelDiskPlugin {
 public:
  static void RegisterWithRegistrar(flutter::PluginRegistrarWindows* registrar);

  SquirrelDiskPlugin();
  virtual ~SquirrelDiskPlugin();

 private:
  void HandleMethodCall(
      const flutter::MethodCall<flutter::EncodableValue>& method_call,
      std::unique_ptr<flutter::MethodResult<flutter::EncodableValue>> result);

  void GetDisks(std::unique_ptr<flutter::MethodResult<flutter::EncodableValue>> result);
  void StartScan(const flutter::EncodableValue* arguments,
                 std::unique_ptr<flutter::MethodResult<flutter::EncodableValue>> result);
  void StopScan(std::unique_ptr<flutter::MethodResult<flutter::EncodableValue>> result);
  void ShowInFolder(const flutter::EncodableValue* arguments,
                    std::unique_ptr<flutter::MethodResult<flutter::EncodableValue>> result);

  std::unique_ptr<flutter::EventSink<flutter::EncodableValue>> event_sink_;
  bool is_scanning_ = false;
};

} // namespace squirreldisk_windows