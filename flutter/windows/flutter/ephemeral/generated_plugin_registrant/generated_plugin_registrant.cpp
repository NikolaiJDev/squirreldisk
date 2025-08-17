//
//  Generated file. Do not edit.
//

#include "generated_plugin_registrant.h"

#include <file_picker/file_picker_plugin.h>
#include <path_provider_windows/path_provider_windows_plugin.h>
#include <window_manager/window_manager_plugin.h>

void RegisterPlugins(flutter::PluginRegistry* registry) {
  FilePickerPluginRegisterWithRegistrar(
      registry->GetRegistrarForPlugin("FilePickerPlugin"));
  PathProviderWindowsPluginRegisterWithRegistrar(
      registry->GetRegistrarForPlugin("PathProviderWindowsPlugin"));
  WindowManagerPluginRegisterWithRegistrar(
      registry->GetRegistrarForPlugin("WindowManagerPlugin"));
}