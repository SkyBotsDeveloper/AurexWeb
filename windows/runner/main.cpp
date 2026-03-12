#include <flutter/dart_project.h>
#include <flutter/flutter_view_controller.h>
#include <windows.h>

#include <optional>
#include <regex>
#include <string>
#include <vector>

#include "flutter_window.h"
#include "utils.h"

namespace {

constexpr wchar_t kAppTitle[] = L"Aurex";
constexpr wchar_t kRunnerWindowClass[] = L"FLUTTER_RUNNER_WIN32_WINDOW";
constexpr wchar_t kSingleInstanceMutexName[] =
    L"Local\\SkyBotsDeveloper.Aurex.SingleInstance";
constexpr ULONG_PTR kAppLinkMessageId = WM_USER + 2;

std::optional<std::string> ExtractDeepLink(
    const std::vector<std::string>& arguments) {
  if (arguments.size() != 1) {
    return std::nullopt;
  }

  const std::regex scheme_regex(
      R"(^([a-z][a-z0-9+.-]+):)",
      std::regex_constants::icase);
  if (!std::regex_search(arguments.front(), scheme_regex)) {
    return std::nullopt;
  }

  return arguments.front();
}

HWND FindExistingAurexWindow() {
  HWND window = ::FindWindow(kRunnerWindowClass, kAppTitle);
  if (window != nullptr) {
    return window;
  }
  return ::FindWindow(nullptr, kAppTitle);
}

void FocusExistingWindow(HWND window) {
  if (window == nullptr) {
    return;
  }
  if (::IsIconic(window)) {
    ::ShowWindow(window, SW_RESTORE);
  } else {
    ::ShowWindow(window, SW_SHOW);
  }
  ::SetForegroundWindow(window);
}

void ForwardDeepLinkToWindow(HWND window, const std::string& link) {
  if (window == nullptr || link.empty()) {
    return;
  }

  COPYDATASTRUCT data{};
  data.dwData = kAppLinkMessageId;
  data.cbData = static_cast<DWORD>(link.size() + 1);
  data.lpData = const_cast<char*>(link.c_str());

  ::SendMessage(window, WM_COPYDATA, 0, reinterpret_cast<LPARAM>(&data));
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

  HANDLE single_instance_mutex = ::CreateMutex(
      nullptr, TRUE, kSingleInstanceMutexName);
  const bool already_running =
      single_instance_mutex != nullptr &&
      ::GetLastError() == ERROR_ALREADY_EXISTS;

  std::vector<std::string> command_line_arguments =
      GetCommandLineArguments();
  const auto deep_link = ExtractDeepLink(command_line_arguments);

  if (already_running) {
    HWND existing_window = FindExistingAurexWindow();
    if (existing_window != nullptr) {
      if (deep_link) {
        ForwardDeepLinkToWindow(existing_window, *deep_link);
      }
      FocusExistingWindow(existing_window);
    }

    if (single_instance_mutex != nullptr) {
      ::CloseHandle(single_instance_mutex);
    }
    ::CoUninitialize();
    return EXIT_SUCCESS;
  }

  flutter::DartProject project(L"data");

  project.set_dart_entrypoint_arguments(std::move(command_line_arguments));

  FlutterWindow window(project);
  Win32Window::Point origin(10, 10);
  Win32Window::Size size(1280, 720);
  if (!window.Create(L"Aurex", origin, size)) {
    return EXIT_FAILURE;
  }
  window.SetQuitOnClose(true);

  ::MSG msg;
  while (::GetMessage(&msg, nullptr, 0, 0)) {
    ::TranslateMessage(&msg);
    ::DispatchMessage(&msg);
  }

  ::CoUninitialize();
  if (single_instance_mutex != nullptr) {
    ::ReleaseMutex(single_instance_mutex);
    ::CloseHandle(single_instance_mutex);
  }
  return EXIT_SUCCESS;
}
