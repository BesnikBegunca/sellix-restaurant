#include <flutter/dart_project.h>
#include <flutter/flutter_view_controller.h>
#include <windows.h>

#include <string>

#include "flutter_window.h"
#include "utils.h"

namespace {
std::wstring ExecutableDirectory() {
  wchar_t module_path[MAX_PATH];
  const DWORD length =
      GetModuleFileNameW(nullptr, module_path, MAX_PATH);
  if (length == 0 || length >= MAX_PATH) {
    return L".";
  }
  std::wstring path(module_path, length);
  const size_t slash = path.find_last_of(L"\\/");
  if (slash == std::wstring::npos) {
    return L".";
  }
  return path.substr(0, slash);
}
}  // namespace

int APIENTRY wWinMain(_In_ HINSTANCE instance, _In_opt_ HINSTANCE prev,
                      _In_ wchar_t *command_line, _In_ int show_command) {
  // Attach to console when present (e.g., 'flutter run') or create a
  // new console when running with a debugger.
  if (!::AttachConsole(ATTACH_PARENT_PROCESS) && ::IsDebuggerPresent()) {
    CreateAndAttachConsole();
  }

  // Initialize COM, so that it is available for use in the library and/or
  // plugins.
  ::CoInitializeEx(nullptr, COINIT_APARTMENTTHREADED);

  // Absolute path: installer/shortcut cwd is often System32 or Desktop.
  const std::wstring data_dir = ExecutableDirectory() + L"\\data";
  flutter::DartProject project(data_dir);

  std::vector<std::string> command_line_arguments =
      GetCommandLineArguments();

  project.set_dart_entrypoint_arguments(std::move(command_line_arguments));

  FlutterWindow window(project);
  // Borderless fullscreen on the default monitor (covers taskbar); origin/size ignored.
  Win32Window::Point origin(0, 0);
  Win32Window::Size size(1280, 720);
  if (!window.Create(L"SelliX", origin, size)) {
    MessageBoxW(nullptr,
                L"SelliX nuk u hap. Provo ikonen ne desktop, ose instalo "
                L"Visual C++ Redistributable 2015-2022 (x64).",
                L"SelliX", MB_OK | MB_ICONERROR);
    return EXIT_FAILURE;
  }
  window.SetQuitOnClose(true);

  ::MSG msg;
  while (::GetMessage(&msg, nullptr, 0, 0)) {
    ::TranslateMessage(&msg);
    ::DispatchMessage(&msg);
  }

  ::CoUninitialize();
  return EXIT_SUCCESS;
}
