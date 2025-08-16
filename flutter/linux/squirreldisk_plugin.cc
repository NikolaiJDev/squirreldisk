#include <flutter_linux/flutter_linux.h>
#include <gtk/gtk.h>
#include <sys/statvfs.h>
#include <mntent.h>
#include <unistd.h>
#include <cstring>
#include <vector>
#include <thread>
#include <filesystem>

namespace fs = std::filesystem;

struct _SquirrelDiskPlugin {
  GObject parent_instance;
  FlutterMethodChannel* channel;
  FlutterEventChannel* event_channel;
  gboolean is_scanning;
};

G_DEFINE_TYPE(SquirrelDiskPlugin, squirreldisk_plugin, G_TYPE_OBJECT)

static void squirreldisk_plugin_handle_method_call(
    SquirrelDiskPlugin* self,
    FlMethodCall* method_call) {
  g_autoptr(FlMethodResponse) response = nullptr;
  
  const gchar* method = fl_method_call_get_name(method_call);
  
  if (strcmp(method, "getDrives") == 0) {
    g_autoptr(FlValue) drives = fl_value_new_list();
    
    FILE* mounts = setmntent("/proc/mounts", "r");
    if (mounts) {
      struct mntent* mount;
      while ((mount = getmntent(mounts)) != nullptr) {
        // Skip non-physical filesystems
        if (strncmp(mount->mnt_fsname, "/dev/", 5) != 0) continue;
        
        struct statvfs stats;
        if (statvfs(mount->mnt_dir, &stats) == 0) {
          g_autoptr(FlValue) drive = fl_value_new_map();
          
          fl_value_set_string_take(drive, "name", fl_value_new_string(mount->mnt_dir));
          fl_value_set_string_take(drive, "sMountPoint", fl_value_new_string(mount->mnt_dir));
          
          unsigned long long total = stats.f_blocks * stats.f_frsize;
          unsigned long long available = stats.f_bavail * stats.f_frsize;
          
          fl_value_set_string_take(drive, "totalSpace", fl_value_new_int(total));
          fl_value_set_string_take(drive, "availableSpace", fl_value_new_int(available));
          fl_value_set_string_take(drive, "isRemovable", fl_value_new_bool(false));
          
          fl_value_append_take(drives, drive);
        }
      }
      endmntent(mounts);
    }
    
    response = FL_METHOD_RESPONSE(fl_method_success_response_new(drives));
  }
  else if (strcmp(method, "startScan") == 0) {
    FlValue* args = fl_method_call_get_args(method_call);
    FlValue* path_value = fl_value_lookup_string(args, "path");
    
    if (fl_value_get_type(path_value) == FL_VALUE_TYPE_STRING) {
      const gchar* path = fl_value_get_string(path_value);
      self->is_scanning = TRUE;
      
      // In a real implementation, start scanning in a separate thread
      std::thread([=]() {
        // Mock scan completion after delay
        g_usleep(2000000); // 2 seconds
        
        if (self->is_scanning) {
          // Send completion event
          g_autoptr(FlValue) event = fl_value_new_map();
          fl_value_set_string_take(event, "type", fl_value_new_string("completed"));
          fl_value_set_string_take(event, "data", fl_value_new_string("[]"));
          
          // In real implementation, emit this through event channel
        }
        self->is_scanning = FALSE;
      }).detach();
      
      response = FL_METHOD_RESPONSE(fl_method_success_response_new(nullptr));
    } else {
      response = FL_METHOD_RESPONSE(fl_method_error_response_new("INVALID_ARGUMENTS", "Path must be a string", nullptr));
    }
  }
  else if (strcmp(method, "stopScan") == 0) {
    self->is_scanning = FALSE;
    response = FL_METHOD_RESPONSE(fl_method_success_response_new(nullptr));
  }
  else if (strcmp(method, "showInFolder") == 0) {
    FlValue* args = fl_method_call_get_args(method_call);
    FlValue* path_value = fl_value_lookup_string(args, "path");
    
    if (fl_value_get_type(path_value) == FL_VALUE_TYPE_STRING) {
      const gchar* path = fl_value_get_string(path_value);
      
      // Use xdg-open to show folder
      gchar* command = g_strdup_printf("xdg-open \"%s\"", path);
      g_spawn_command_line_async(command, nullptr);
      g_free(command);
      
      response = FL_METHOD_RESPONSE(fl_method_success_response_new(nullptr));
    } else {
      response = FL_METHOD_RESPONSE(fl_method_error_response_new("INVALID_ARGUMENTS", "Path must be a string", nullptr));
    }
  }
  else {
    response = FL_METHOD_RESPONSE(fl_method_not_implemented_response_new());
  }
  
  fl_method_call_respond(method_call, response, nullptr);
}

static void squirreldisk_plugin_dispose(GObject* object) {
  G_OBJECT_CLASS(squirreldisk_plugin_parent_class)->dispose(object);
}

static void squirreldisk_plugin_class_init(SquirrelDiskPluginClass* klass) {
  G_OBJECT_CLASS(klass)->dispose = squirreldisk_plugin_dispose;
}

static void squirreldisk_plugin_init(SquirrelDiskPlugin* self) {
  self->is_scanning = FALSE;
}

void squirreldisk_plugin_register_with_registrar(FlPluginRegistrar* registrar) {
  SquirrelDiskPlugin* plugin = SQUIRRELDISK_PLUGIN(
      g_object_new(squirreldisk_plugin_get_type(), nullptr));

  g_autoptr(FlStandardMethodCodec) codec = fl_standard_method_codec_new();
  plugin->channel = fl_method_channel_new(fl_plugin_registrar_get_messenger(registrar),
                                          "squirreldisk/disk",
                                          FL_METHOD_CODEC(codec));
  fl_method_channel_set_method_call_handler(plugin->channel,
                                            (FlMethodCallHandler)squirreldisk_plugin_handle_method_call,
                                            g_object_ref(plugin),
                                            g_object_unref);

  g_object_unref(plugin);
}