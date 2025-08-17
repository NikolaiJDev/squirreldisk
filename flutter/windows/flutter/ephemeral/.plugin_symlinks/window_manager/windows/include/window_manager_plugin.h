#ifndef WINDOW_MANAGER_PLUGIN_H_
#define WINDOW_MANAGER_PLUGIN_H_

#include <flutter/plugin_registrar_windows.h>

#ifdef FLUTTER_PLUGIN_IMPL
#define FLUTTER_PLUGIN_EXPORT __declspec(dllexport)
#else
#define FLUTTER_PLUGIN_EXPORT __declspec(dllimport)
#endif

#if defined(__cplusplus)
extern "C" {
#endif

FLUTTER_PLUGIN_EXPORT void WindowManagerPluginRegisterWithRegistrar(
    FlutterDesktopPluginRegistrarRef registrar);

#if defined(__cplusplus)
}
#endif

#endif  // WINDOW_MANAGER_PLUGIN_H_