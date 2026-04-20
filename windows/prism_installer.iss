#define ToolName "Discover PRISM"
#define ToolVersion "1.0.0"
#define ToolPublisher "Fait Marcus Lacatan"
#define ToolExeName "prism.exe"

[Setup]
AppId={{C6D0A9F1-E0B1-4A2D-A9E2-B1B601015C71}
AppName={#ToolName}
AppVersion={#ToolVersion}
AppPublisher={#ToolPublisher}
DefaultDirName={autopf}\{#ToolName}
DisableProgramGroupPage=yes
PrivilegesRequired=lowest
OutputDir=..\build\windows\installer
OutputBaseFilename=Discover_PRISM_Setup
Compression=lzma
SolidCompression=yes
WizardStyle=modern

[Languages]
Name: "english"; MessagesFile: "compiler:Default.isl"

[Tasks]
Name: "desktopicon"; Description: "{cm:CreateDesktopIcon}"; GroupDescription: "{cm:AdditionalIcons}"; Flags: unchecked

[Files]
Source: "..\build\windows\x64\runner\Release\{#ToolExeName}"; DestDir: "{app}"; Flags: ignoreversion
Source: "..\build\windows\x64\runner\Release\*.dll"; DestDir: "{app}"; Flags: ignoreversion
Source: "..\build\windows\x64\runner\Release\data\*"; DestDir: "{app}\data"; Flags: ignoreversion recursesubdirs createallsubdirs

[Icons]
Name: "{autoprograms}\{#ToolName}"; Filename: "{app}\{#ToolExeName}"
Name: "{autodesktop}\{#ToolName}"; Filename: "{app}\{#ToolExeName}"; Tasks: desktopicon

[Run]
Filename: "{app}\{#ToolExeName}"; Description: "{cm:LaunchProgram,{#StringChange(ToolName, '&', '&&')}}"; Flags: nowait postinstall skipifsilent