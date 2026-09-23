; Inno Setup script for SelliX - Flutter Desktop
; Requires Inno Setup 6.x — https://jrsoftware.org/isinfo.php
;
; BEFORE building this installer:
;   1. Run: .\scripts\sync_windows_app_icon.ps1
;   2. Run: flutter build windows --release --no-tree-shake-icons
;   3. Copy release\app_config.example.json to release\app_config.json
;   4. Run: .\scripts\prepare_windows_release.ps1
;   5. Open this file in Inno Setup Compiler and click Build → Compile

#define AppName      "SelliX"
#define AppVersion   "1.0.0"
#define AppPublisher "Sellix Software Inc."
#define AppExeName   "SelliX.exe"
#define ReleaseDir   "..\..\build\windows\x64\runner\Release"
#define ConfigDir    "..\..\release"
#define AppIcon      "..\..\assets\images\app_icon.ico"

[Setup]
AppName={#AppName}
AppVersion={#AppVersion}
AppPublisher={#AppPublisher}
SetupIconFile={#AppIcon}
UninstallDisplayIcon={app}\{#AppExeName}
AppId={{A1B2C3D4-E5F6-7890-ABCD-EF1234567890}
DefaultDirName={autopf}\{#AppName}
DefaultGroupName={#AppName}
UsePreviousAppDir=no
OutputDir={#ConfigDir}\installer_output
OutputBaseFilename=SelliXSetup_{#AppVersion}
Compression=lzma2/ultra64
SolidCompression=yes
ArchitecturesInstallIn64BitMode=x64compatible
ArchitecturesAllowed=x64compatible
DisableProgramGroupPage=yes
ShowLanguageDialog=no
WizardStyle=modern
MinVersion=10.0.17763

[Languages]
Name: "english"; MessagesFile: "compiler:Default.isl"

[Files]
; Flutter release bundle (executable + DLLs + data/)
Source: "{#ReleaseDir}\*"; DestDir: "{app}"; \
  Flags: ignoreversion recursesubdirs createallsubdirs

; Production API config pranë exe (app_config.json ose shembulli)
#ifnexist "..\..\release\app_config.json"
Source: "{#ConfigDir}\app_config.example.json"; DestDir: "{app}"; DestName: "app_config.json"; Flags: ignoreversion
#else
Source: "{#ConfigDir}\app_config.json"; DestDir: "{app}"; Flags: ignoreversion
#endif

[Icons]
; Start Menu shortcut
Name: "{group}\{#AppName}"; Filename: "{app}\{#AppExeName}"; WorkingDir: "{app}"
Name: "{group}\Uninstall {#AppName}"; Filename: "{uninstallexe}"

; Desktop shortcut
Name: "{autodesktop}\{#AppName}"; Filename: "{app}\{#AppExeName}"; WorkingDir: "{app}"

[Run]
; Hapet si përdoruesi, jo si Administrator i wizard-it — përndryshe Flutter
; shpesh nuk shfaqet pas Finish.
Filename: "{app}\{#AppExeName}"; \
  Description: "Launch {#AppName}"; \
  WorkingDir: "{app}"; \
  Flags: nowait postinstall skipifsilent runasoriginaluser

[UninstallDelete]
; Clean up app_config.json written by operator (not tracked by uninstaller otherwise)
Type: files; Name: "{app}\app_config.json"
