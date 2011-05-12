unit TestBase;

{$mode objfpc}{$H+}

interface

uses
  Classes, SysUtils, FileUtil, fpcunit, testutils, testregistry,
  EnvironmentOpts, LCLProc, CompileHelpers, Dialogs, ExtToolDialog,
  Debugger, GDBMIDebugger;

(*
  fpclist.txt contains lines of format:
    [Name]
    exe=/path/fpc.exe
    symbols=none,gs,gw,gwset,gw3


  gdblist.txt contains lines of format:
    [Name]
    exe=/path/fpc.exe
    version=070201
    symbols=none,gs,gw,gwset,gw3

*)

type
  TSymbolType = (stNone, stStabs, stDwarf, stDwarfSet, stDwarf3);
  TSymbolTypes = set of TSymbolType;

const
  SymbolTypeNames: Array [TSymbolType] of String = ('No_Dbg', 'Stabs', 'Dwarf', 'Dwarf+Sets', 'Dwarf3');
  SymbolTypeSwitches: Array [TSymbolType] of String = ('', '-gs', '-gw', '-gw -godwarfsets', '-gw3');

type

  TGDBMIDebuggerClass = class of TGDBMIDebugger;

  TCompilerInfo = record
        Name: string;
        ExeName: string;
        SymbolTypes: TSymbolTypes;
        ExtraOpts: string;
      end;

  TDebuggerInfo = record
        Name: string;
        ExeName: string;
        SymbolTypes: TSymbolTypes;
        Version: Integer;
      end;

  { TBaseList }

  TBaseList = class
  protected
    function  AddName(const AName: string): Integer; virtual; abstract;
    procedure SetAttribute(AIndex: Integer; const AAttr, AValue: string); virtual; abstract;
  public
    procedure LoadFromFile(const AFileName: string);
  end;

  { TCompilerList }

  TCompilerList = class(TBaseList)
  private
    FList: array of TCompilerInfo;
    function GetCompilerInfo(Index: Integer): TCompilerInfo;
    function GetExeName(Index: Integer): string;
    function GetName(Index: Integer): string;
    function GetSymbolTypes(Index: Integer): TSymbolTypes;
  protected
    function  AddName(const AName: string): Integer; override;
    procedure SetAttribute(AIndex: Integer; const AAttr, AValue: string); override;
  public
    procedure Add(Name, Exe: string; Opts: String = '');
    function Count: Integer;
    property CompilerInfo[Index: Integer]: TCompilerInfo read GetCompilerInfo;
    property Name[Index: Integer]: string read GetName;
    property ExeName[Index: Integer]: string read GetExeName;
    property SymbolTypes[Index: Integer]: TSymbolTypes read GetSymbolTypes;
  end;

  { TDebuggerList }

  TDebuggerList = class(TBaseList)
  private
    FList: array of TDebuggerInfo;
    function GetDebuggerInfo(Index: Integer): TDebuggerInfo;
    function GetExeName(Index: Integer): string;
    function GetName(Index: Integer): string;
    function GetSymbolTypes(Index: Integer): TSymbolTypes;
  protected
    function  AddName(const AName: string): Integer; override;
    procedure SetAttribute(AIndex: Integer; const AAttr, AValue: string); override;
  public
    procedure Add(Name, Exe: string);
    function Count: Integer;
    property DebuggerInfo[Index: Integer]: TDebuggerInfo read GetDebuggerInfo;
    property Name[Index: Integer]: string read GetName;
    property ExeName[Index: Integer]: string read GetExeName;
    property SymbolTypes[Index: Integer]: TSymbolTypes read GetSymbolTypes;
  end;


  { TCompilerSuite }

  TCompilerSuite = class(TTestSuite)
  private
    FCompilerInfo: TCompilerInfo;
    FSymbolSwitch: String;
    FSymbolType: TSymbolType;
    FFileNameExt: String;
    FCompiledList: TStringList;
    FInRun: Boolean;
  protected
    procedure Clear;
  public
    constructor Create(ACompilerInfo: TCompilerInfo; ASymbolType: TSymbolType; ADebuggerList: TDebuggerList);
    destructor Destroy; override;
    procedure Run(AResult: TTestResult); override;
    procedure RunTest(ATest: TTest; AResult: TTestResult); override;
    procedure RegisterDbgTest(ATestClass: TTestCaseClass);
    Procedure TestCompile(const PrgName: string; out ExeName: string; NamePostFix: String=''; ExtraArgs: String='');
  public
    property SymbolType: TSymbolType read FSymbolType;
    property SymbolSwitch: String read FSymbolSwitch;
    property CompilerInfo: TCompilerInfo read FCompilerInfo;
  end;

  { TDebuggerSuite }

  TDebuggerSuite = class(TTestSuite)
  private
    FDebuggerInfo: TDebuggerInfo;
    FParent: TCompilerSuite;
    function GetCompilerInfo: TCompilerInfo;
    function GetSymbolType: TSymbolType;
  public
    constructor Create(AParent: TCompilerSuite; ADebuggerInfo: TDebuggerInfo);
    procedure RegisterDbgTest(ATestClass: TTestCaseClass);
    Procedure TestCompile(const PrgName: string; out ExeName: string; NamePostFix: String=''; ExtraArgs: String='');
  public
    property Parent: TCompilerSuite read FParent;
    property DebuggerInfo: TDebuggerInfo read FDebuggerInfo;
    property SymbolType: TSymbolType read GetSymbolType;
    property CompilerInfo: TCompilerInfo read GetCompilerInfo;
  end;

  { TGDBTestsuite }

  TGDBTestsuite = class(TTestSuite)
  private
    FParent: TDebuggerSuite;
    function GetCompilerInfo: TCompilerInfo;
    function GetDebuggerInfo: TDebuggerInfo;
    function GetSymbolType: TSymbolType;
  public
    constructor Create(AParent: TDebuggerSuite; AClass: TClass);
    procedure AddTest(ATest: TTest); overload; override;
    Procedure TestCompile(const PrgName: string; out ExeName: string; NamePostFix: String=''; ExtraArgs: String='');
  public
    property Parent: TDebuggerSuite read FParent;
    property DebuggerInfo: TDebuggerInfo read GetDebuggerInfo;
    property SymbolType: TSymbolType read GetSymbolType;
    property CompilerInfo: TCompilerInfo read GetCompilerInfo;
  end;

  { TGDBTestCase }

  TGDBTestCase = class(TTestCase)
  private
    // stuff for the debugger
    FCallStack: TCallStackMonitor;
    FDisassembler: TIDEDisassembler;
    FExceptions: TIDEExceptions;
    FSignals: TIDESignals;
    //FBreakPoints: TIDEBreakPoints;
    //FBreakPointGroups: TIDEBreakPointGroups;
    FLocals: TIDELocals;
    FLineInfo: TIDELineInfo;
    FWatches: TWatchesMonitor;
    FThreads: TThreadsMonitor;
    FRegisters: TIDERegisters;
  private
    FParent: TGDBTestsuite;
    FTestErrors, FIgnoredErrors, FUnexpectedSuccess: String;
    FCurrentPrgName, FCurrentExename: String;
    FLogFile: TextFile;
    function GetCompilerInfo: TCompilerInfo;
    function GetDebuggerInfo: TDebuggerInfo;
    function GetSymbolType: TSymbolType;
  protected
    function GetLogActive: Boolean;
    procedure SetUp; override;
    procedure TearDown; override;
    procedure DoDbgOutPut(Sender: TObject; const AText: String); virtual;
    procedure InternalDbgOutPut(Sender: TObject; const AText: String);
    function GdbClass: TGDBMIDebuggerClass; virtual;
    function StartGDB(AppDir, TestExeName: String): TGDBMIDebugger;
    procedure CleanGdb;
    procedure ClearTestErrors;
    procedure AddTestError(s: string; MinGdbVers: Integer = 0);
    procedure AddTestSuccess(s: string; MinGdbVers: Integer = 0);
    function TestEquals(Expected, Got: string): Boolean;
    function TestEquals(Name: string; Expected, Got: string; MinGdbVers: Integer = 0): Boolean;
    function TestEquals(Expected, Got: integer): Boolean;
    function TestEquals(Name: string; Expected, Got: integer; MinGdbVers: Integer = 0): Boolean;
    function TestTrue(Name: string; Got: Boolean; MinGdbVers: Integer = 0): Boolean;
    function TestFalse(Name: string; Got: Boolean; MinGdbVers: Integer = 0): Boolean;
    procedure AssertTestErrors;
    property TestErrors: string read FTestErrors;
  public
    Procedure TestCompile(const PrgName: string; out ExeName: string; NamePostFix: String=''; ExtraArgs: String='');
  public
    property Parent: TGDBTestsuite read FParent write FParent;
    property DebuggerInfo: TDebuggerInfo read GetDebuggerInfo;
    property SymbolType: TSymbolType read GetSymbolType;
    property CompilerInfo: TCompilerInfo read GetCompilerInfo;
  public
    //property BreakPoints: TIDEBreakPoints read FBreakpoints;   // A list of breakpoints for the current project
    //property BreakPointGroups: TIDEBreakPointGroups read FBreakPointGroups;
    property Exceptions: TIDEExceptions read FExceptions;      // A list of exceptions we should ignore
    property CallStack: TCallStackMonitor read FCallStack;
    property Disassembler: TIDEDisassembler read FDisassembler;
    property Locals: TIDELocals read FLocals;
    property LineInfo: TIDELineInfo read FLineInfo;
    property Registers: TIDERegisters read FRegisters;
    property Signals: TIDESignals read FSignals;               // A list of actions for signals we know of
    property Watches: TWatchesMonitor read FWatches;
    property Threads: TThreadsMonitor read FThreads;
  end;


function GetCompilers: TCompilerList;
function GetDebuggers: TDebuggerList;

procedure RegisterDbgTest(ATestClass: TTestCaseClass);

var
  AppDir: String;
  ConfDir: String;
  Logdir: String;
  WriteLog: Boolean;

implementation

var
  Compilers: TCompilerList = nil;
  Debuggers: TDebuggerList = nil;

function StrToSymbolTypes(s: string): TSymbolTypes;
var
  s2: string;
begin
  Result := [];
  while (s <> '') do begin
    while (s <> '') and (s[1] in [' ', ',', #9, #10, #13]) do delete(s,1, 1);
    s2 := '';
    while (s <> '') and not (s[1] in [' ', ',', #9, #10, #13]) do begin
      s2 := s2 + s[1];
      delete(s,1, 1);
    end;
    if s2 = 'none' then Result := Result + [stNone];
    if s2 = 'gs' then Result := Result + [stStabs];
    if s2 = 'gw' then Result := Result + [stDwarf];
    if s2 = 'gwset' then Result := Result + [stDwarfSet];
    if s2 = 'gw3' then Result := Result + [stDwarf3];
  end;
end;


function GetCompilers: TCompilerList;
begin
  if Compilers <> nil then exit(Compilers);

  Result := TCompilerList.Create;
  if FileExists(ConfDir + 'fpclist.txt') then
    Result.LoadFromFile(ConfDir + 'fpclist.txt');
  if (Result.Count = 0) and (EnvironmentOptions.CompilerFilename <> '') then begin
    Result.Add('fpc from conf', EnvironmentOptions.CompilerFilename);
    Result.Add('fpc from conf -Xe', EnvironmentOptions.CompilerFilename, '-Xe');
  end;
  Compilers := Result;
end;

function GetDebuggers: TDebuggerList;
begin
  if Debuggers <> nil then exit(Debuggers);

  Result := TDebuggerList.Create;
  if FileExists(ConfDir + 'gdblist.txt') then
    Result.LoadFromFile(ConfDir + 'gdblist.txt');
  if (Result.Count = 0) and (EnvironmentOptions.DebuggerFilename <> '') then
    Result.Add('gdb from conf', EnvironmentOptions.DebuggerFilename);
  Debuggers := Result;
end;

{ TGDBTestCase }

procedure TGDBTestCase.DoDbgOutPut(Sender: TObject; const AText: String);
begin
  //
end;

procedure TGDBTestCase.InternalDbgOutPut(Sender: TObject; const AText: String);
begin
  if GetLogActive then begin
    writeln(FLogFile, AText);
  end;
  DoDbgOutPut(Sender, AText);
end;

function TGDBTestCase.GdbClass: TGDBMIDebuggerClass;
begin
  Result := TGDBMIDebugger;
end;

function TGDBTestCase.GetCompilerInfo: TCompilerInfo;
begin
  Result := Parent.CompilerInfo;
end;

function TGDBTestCase.GetDebuggerInfo: TDebuggerInfo;
begin
  Result := Parent.DebuggerInfo;
end;

function TGDBTestCase.GetSymbolType: TSymbolType;
begin
  Result := Parent.SymbolType;
end;

function TGDBTestCase.GetLogActive: Boolean;
begin
  Result := WriteLog;
end;

procedure TGDBTestCase.SetUp;
var
  name: String;
  i: Integer;
  dir: String;
begin
  if GetLogActive then begin
    name := TestName
      + '_' + GetCompilerInfo.Name
      + '_' + SymbolTypeNames[GetSymbolType]
      + '_' + GetDebuggerInfo.Name
      + '.log';
    dir := ConfDir;
    if DirectoryExistsUTF8(Logdir) then
      dir := Logdir;

    for i := 1 to length(name) do
      if name[i] in ['/', '\', '*', '?', ':'] then
        name[i] := '_';
    AssignFile(FLogFile, Dir +  name);
    Rewrite(FLogFile);
  end;
  inherited SetUp;
end;

procedure TGDBTestCase.TearDown;
begin
  inherited TearDown;
  if GetLogActive then begin
    CloseFile(FLogFile);
  end;
end;

function TGDBTestCase.StartGDB(AppDir, TestExeName: String): TGDBMIDebugger;
begin
  //FBreakPoints := TManagedBreakPoints.Create(Self);
  //FBreakPointGroups := TIDEBreakPointGroups.Create;
  FWatches := TWatchesMonitor.Create;
  FThreads := TThreadsMonitor.Create;
  FExceptions := TIDEExceptions.Create;
  FSignals := TIDESignals.Create;
  FLocals := TIDELocals.Create;
  FLineInfo := TIDELineInfo.Create;
  FCallStack := TCallStackMonitor.Create;
  FDisassembler := TIDEDisassembler.Create;
  FRegisters := TIDERegisters.Create;

  Result := GdbClass.Create(DebuggerInfo.ExeName);

  //TManagedBreakpoints(FBreakpoints).Master := FDebugger.BreakPoints;
  FWatches.Supplier := Result.Watches;
  FThreads.Supplier := Result.Threads;
  FLocals.Master := Result.Locals;
  FLineInfo.Master := Result.LineInfo;
  FCallStack.Supplier := Result.CallStack;
  FDisassembler.Master := Result.Disassembler;
  FExceptions.Master := Result.Exceptions;
  FSignals.Master := Result.Signals;
  FRegisters.Master := Result.Registers;

  Result.Init;
  if Result.State = dsError then
    Fail(' Failed Init');
  Result.WorkingDir := AppDir;
  Result.FileName   := TestExeName;
  Result.Arguments := '';
  Result.ShowConsole := True;
  Result.OnDbgOutput  := @InternalDbgOutPut;

end;

procedure TGDBTestCase.CleanGdb;
begin
  //TManagedBreakpoints(FBreakpoints).Master := nil;
  FWatches.Supplier := nil;
  FThreads.Supplier := nil;
  FLocals.Master := nil;
  FLineInfo.Master := nil;
  FCallStack.Supplier := nil;
  FDisassembler.Master := nil;
  FExceptions.Master := nil;
  FSignals.Master := nil;
  FRegisters.Master := nil;

  FreeAndNil(FWatches);
  FreeAndNil(FThreads);
  //FreeAndNil(FBreakPoints);
  //FreeAndNil(FBreakPointGroups);
  FreeAndNil(FCallStack);
  FreeAndNil(FDisassembler);
  FreeAndNil(FExceptions);
  FreeAndNil(FSignals);
  FreeAndNil(FLocals);
  FreeAndNil(FLineInfo);
  FreeAndNil(FRegisters);
end;

procedure TGDBTestCase.ClearTestErrors;
begin
  FTestErrors := '';
end;

procedure TGDBTestCase.AddTestError(s: string; MinGdbVers: Integer = 0);
var
  IgnoreReason: String;
  i: Integer;
begin
  IgnoreReason := '';
  if MinGdbVers > 0 then begin
    i := GetDebuggerInfo.Version;
    if (i > 0) and (i < MinGdbVers) then
      IgnoreReason := 'GDB ('+IntToStr(i)+') to old, required:'+IntToStr(MinGdbVers);
  end;
  if IgnoreReason <> '' then
    FIgnoredErrors := FIgnoredErrors + '### '+IgnoreReason +' >>> '+s+LineEnding
  else
    FTestErrors := FTestErrors + s + LineEnding;
end;

procedure TGDBTestCase.AddTestSuccess(s: string; MinGdbVers: Integer);
var
  i: Integer;
begin
  if MinGdbVers > 0 then begin
    i := GetDebuggerInfo.Version;
    if (i > 0) and (i < MinGdbVers) then
      FUnexpectedSuccess := FUnexpectedSuccess + s
        + 'GDB ('+IntToStr(i)+') to old, required:'+IntToStr(MinGdbVers)
        + LineEnding;
  end;
end;

function TGDBTestCase.TestEquals(Expected, Got: string): Boolean;
begin
  Result := TestEquals('', Expected, Got);
end;

function TGDBTestCase.TestEquals(Name: string; Expected, Got: string; MinGdbVers: Integer = 0): Boolean;
begin
  Result :=  Got = Expected;
  if Result
  then AddTestSuccess(Name + ': Expected to fail with, but succeded, Got "'+Got+'"', MinGdbVers)
  else AddTestError(Name + ': Expected "'+Expected+'", Got "'+Got+'"', MinGdbVers);
end;

function TGDBTestCase.TestEquals(Expected, Got: integer): Boolean;
begin
  Result := TestEquals('', Expected, Got);
end;

function TGDBTestCase.TestEquals(Name: string; Expected, Got: integer; MinGdbVers: Integer = 0): Boolean;
begin
  Result :=  Got = Expected;
  if Result
  then AddTestSuccess(Name + ': Expected to fail with, but succeded, Got "'+IntToStr(Got)+'"', MinGdbVers)
  else AddTestError(Name + ': Expected "'+IntToStr(Expected)+'", Got "'+IntToStr(Got)+'"', MinGdbVers);
end;

function TGDBTestCase.TestTrue(Name: string; Got: Boolean; MinGdbVers: Integer): Boolean;
begin
  Result := Got;
  if Result
  then AddTestSuccess(Name + ': Expected to fail with, but succeded, Got "True"', MinGdbVers)
  else AddTestError(Name + ': Expected "True", Got "False"', MinGdbVers);
end;

function TGDBTestCase.TestFalse(Name: string; Got: Boolean; MinGdbVers: Integer): Boolean;
begin
  Result := not Got;
  if Result
  then AddTestSuccess(Name + ': Expected to fail with, but succeded, Got "False"', MinGdbVers)
  else AddTestError(Name + ': Expected "False", Got "True"', MinGdbVers);
end;

procedure TGDBTestCase.AssertTestErrors;
var
  s: String;
begin
  s := FTestErrors;
  FTestErrors := '';
  if GetLogActive then begin
    writeln(FLogFile, '================= Failed:'+LineEnding);
    writeln(FLogFile, s);
    writeln(FLogFile, '================= Ignored'+LineEnding);
    writeln(FLogFile, FIgnoredErrors);
    writeln(FLogFile, '================= Unexpected Success'+LineEnding);
    writeln(FLogFile, FUnexpectedSuccess);
    writeln(FLogFile, '================='+LineEnding);
  end;
  if s <> '' then begin
    Fail(s);
  end;
end;

procedure TGDBTestCase.TestCompile(const PrgName: string; out ExeName: string;
  NamePostFix: String=''; ExtraArgs: String='');
begin
  if GetLogActive then begin
    writeln(FLogFile, LineEnding+LineEnding+'******************* compile '+PrgName + ' ' + ExtraArgs +LineEnding);
  end;
  Parent.TestCompile(PrgName, ExeName, NamePostFix, ExtraArgs);
  FCurrentPrgName := PrgName;
  FCurrentExename := ExeName;
end;

{ TBaseList }

procedure TBaseList.LoadFromFile(const AFileName: string);
var
  txt: TStringList;
  s: string;
  i, j, k: Integer;
begin
  txt := TStringList.Create;
  txt.LoadFromFile(AFileName);
  j := -1;
  for i := 0 to txt.Count - 1 do begin
    s := txt[i];
    if Trim(s) = '' then continue;
    if copy(s, 1, 1) = '[' then begin
      j  := AddName(GetPart(['['], [']'], s));
      continue;
    end;
    if j < 0 then continue;
    k := pos('=', s);
    SetAttribute(j, copy(s, 1, k-1), copy(s, k + 1, length(s)));
  end;
  txt.Free;
end;

{ TCompilerList }

function TCompilerList.GetExeName(Index: Integer): string;
begin
  Result := FList[Index].ExeName;
end;

function TCompilerList.GetCompilerInfo(Index: Integer): TCompilerInfo;
begin
  Result := FList[Index];
end;

function TCompilerList.GetName(Index: Integer): string;
begin
  Result := FList[Index].Name;
end;

function TCompilerList.GetSymbolTypes(Index: Integer): TSymbolTypes;
begin
  Result := FList[Index].SymbolTypes;
end;

function TCompilerList.AddName(const AName: string): Integer;
begin
  Result := length(FList);
  SetLength(FList, Result + 1);
  FList[Result].Name := AName;
  FList[Result].SymbolTypes := [];
  FList[Result].ExtraOpts := '';
end;

procedure TCompilerList.SetAttribute(AIndex: Integer; const AAttr, AValue: string);
begin
  case StringCase(AAttr, ['exe', 'symbols', 'opts'], True, False) of
    0: begin // exe
        FList[AIndex].ExeName := AValue;
      end;
    1: begin // symbols
        FList[AIndex].SymbolTypes := StrToSymbolTypes(AValue);
      end;
    2: begin //opts
        FList[AIndex].ExtraOpts := AValue;
      end;
  end;
end;

procedure TCompilerList.Add(Name, Exe: string; Opts: String = '');
var
  i: LongInt;
begin
  i := AddName(Name);
  FList[i].ExeName := Exe;
  FList[i].SymbolTypes := [stStabs, stDwarf, stDwarfSet];
  FList[i].ExtraOpts := Opts;
end;

function TCompilerList.Count: Integer;
begin
  Result := length(FList);
end;

{ TDebuggerList }

function TDebuggerList.GetExeName(Index: Integer): string;
begin
  Result := FList[Index].ExeName;
end;

function TDebuggerList.GetDebuggerInfo(Index: Integer): TDebuggerInfo;
begin
  Result := FList[Index];
end;

function TDebuggerList.GetName(Index: Integer): string;
begin
  Result := FList[Index].Name;
end;

function TDebuggerList.GetSymbolTypes(Index: Integer): TSymbolTypes;
begin
  Result := FList[Index].SymbolTypes;
end;

function TDebuggerList.AddName(const AName: string): Integer;
begin
  Result := length(FList);
  SetLength(FList, Result + 1);
  FList[Result].Name := AName;
  FList[Result].SymbolTypes := [];
end;

procedure TDebuggerList.SetAttribute(AIndex: Integer; const AAttr, AValue: string);
begin
  case StringCase(AAttr, ['exe', 'symbols', 'vers', 'version'], True, False) of
    0: begin // exe
        FList[AIndex].ExeName := AValue;
      end;
    1: begin // symbols
        FList[AIndex].SymbolTypes := StrToSymbolTypes(AValue);
      end;
    2,3: begin
        FList[AIndex].Version := StrToIntDef(AValue,-1);
      end;
  end;
end;

procedure TDebuggerList.Add(Name, Exe: string);
var
  i: LongInt;
begin
  i := AddName(Name);
  FList[i].ExeName := Exe;
  FList[i].SymbolTypes := [stStabs, stDwarf, stDwarfSet];
end;

function TDebuggerList.Count: Integer;
begin
  Result := length(FList);
end;

{ TCompilerSuite }

procedure TCompilerSuite.Clear;
var
  i: Integer;
begin
  for i := 0 to FCompiledList.Count - 1 do
    DeleteFile(FCompiledList[i]);
  FCompiledList.Clear;
end;

constructor TCompilerSuite.Create(ACompilerInfo: TCompilerInfo; ASymbolType: TSymbolType;
  ADebuggerList: TDebuggerList);
var
  i: Integer;
  SubSuite: TDebuggerSuite;
begin
  inherited Create(ACompilerInfo.Name + ' / ' + SymbolTypeNames[ASymbolType]);
  FCompilerInfo := ACompilerInfo;
  FSymbolType := ASymbolType;

  FCompiledList := TStringList.Create;
  FSymbolSwitch := SymbolTypeSwitches[FSymbolType];
  FInRun := False;

  FFileNameExt := SymbolTypeNames[FSymbolType] + '_';
  for i := 1 to length(CompilerInfo.Name) do begin
    if CompilerInfo.Name[i] in ['a'..'z', 'A'..'Z', '0'..'9', '.', '-'] then
      FFileNameExt := FFileNameExt + CompilerInfo.Name[i]
    else if CompilerInfo.Name[i] = ' ' then
      FFileNameExt := FFileNameExt +  '__'
    else
      FFileNameExt := FFileNameExt + '_' + IntToHex(ord(CompilerInfo.Name[i]), 2);
  end;

  for i := 0 to ADebuggerList.Count - 1 do begin
    if not (FSymbolType in ADebuggerList.SymbolTypes[i]) then
      continue;
    SubSuite := TDebuggerSuite.Create(Self, ADebuggerList.DebuggerInfo[i]);
    Self.AddTest(SubSuite);
  end;
end;

destructor TCompilerSuite.Destroy;
begin
  inherited Destroy;
  Clear;
  FreeAndNil(FCompiledList);
end;

procedure TCompilerSuite.Run(AResult: TTestResult);
begin
  FInRun := True;
  try
    inherited Run(AResult);
  finally
    FInRun := False;
    Clear;
  end;
end;

procedure TCompilerSuite.RunTest(ATest: TTest; AResult: TTestResult);
begin
  try
    inherited RunTest(ATest, AResult);
  finally
    if not FInRun then Clear;
  end;
end;

procedure TCompilerSuite.RegisterDbgTest(ATestClass: TTestCaseClass);
var
  i: Integer;
begin
  for i := 0 to Tests.Count - 1 do
    if Test[i] is TDebuggerSuite then
      TDebuggerSuite(Test[i]).RegisterDbgTest(ATestClass);
end;

procedure TCompilerSuite.TestCompile(const PrgName: string; out ExeName: string;
  NamePostFix: String=''; ExtraArgs: String='');
var
  ExePath, ErrMsg: String;
begin
  ExePath := ExtractFileNameWithoutExt(PrgName);
  ExeName := ExtractFileNameOnly(ExePath);
  ExePath := AppendPathDelim(copy(ExePath, 1, length(ExePath) - length(ExeName)));
  if DirectoryExistsUTF8(ExePath + 'lib') then
    ExePath := AppendPathDelim(ExePath + 'lib');
  ExeName := ExePath + ExeName + FFileNameExt + NamePostFix + GetExeExt;

  if ExtraArgs <> '' then
    ExtraArgs := ' '+ExtraArgs;
  if FCompiledList.IndexOf(ExeName) < 0 then begin
    if FileExists(ExeName) then
      raise EAssertionFailedError.Create('Found existing file before compiling: ' + ExeName);
    FCompiledList.Add(ExeName);
    ErrMsg := CompileHelpers.TestCompile(PrgName, FSymbolSwitch + ' ' + FCompilerInfo.ExtraOpts + ExtraArgs, ExeName, CompilerInfo.ExeName);
    if ErrMsg <> '' then begin
      debugln(ErrMsg);
      raise EAssertionFailedError.Create('Compilation Failed: ' + ExeName + LineEnding + ErrMsg);
    end;
  end;

  if not FileExists(ExeName) then
    raise EAssertionFailedError.Create('Missing compiled exe ' + ExeName);
end;

{ TDebuggerSuite }

function TDebuggerSuite.GetCompilerInfo: TCompilerInfo;
begin
  Result := Parent.CompilerInfo;
end;

function TDebuggerSuite.GetSymbolType: TSymbolType;
begin
  Result := Parent.SymbolType;
end;

constructor TDebuggerSuite.Create(AParent: TCompilerSuite;
  ADebuggerInfo: TDebuggerInfo);
begin
  inherited Create(ADebuggerInfo.Name + '   ('+AParent.TestName+')');
  FParent := AParent;
  FDebuggerInfo := ADebuggerInfo;
end;

procedure TDebuggerSuite.RegisterDbgTest(ATestClass: TTestCaseClass);
var
  NewTest: TGDBTestsuite;
begin
  NewTest := TGDBTestsuite.Create(Self, ATestClass);
  AddTest(NewTest);
end;

procedure TDebuggerSuite.TestCompile(const PrgName: string; out ExeName: string;
  NamePostFix: String=''; ExtraArgs: String='');
begin
  Parent.TestCompile(PrgName, ExeName, NamePostFix, ExtraArgs);
end;

{ TGDBTestsuite }

function TGDBTestsuite.GetCompilerInfo: TCompilerInfo;
begin
  Result := Parent.CompilerInfo;
end;

function TGDBTestsuite.GetDebuggerInfo: TDebuggerInfo;
begin
  Result := Parent.DebuggerInfo;
end;

function TGDBTestsuite.GetSymbolType: TSymbolType;
begin
  Result := Parent.SymbolType;
end;

constructor TGDBTestsuite.Create(AParent: TDebuggerSuite; AClass: TClass);
begin
  inherited Create(AClass);
  FParent := AParent;
end;

procedure TGDBTestsuite.AddTest(ATest: TTest);
begin
  inherited AddTest(ATest);
  if ATest is TGDBTestCase then
    TGDBTestCase(ATest).Parent := Self;
end;

procedure TGDBTestsuite.TestCompile(const PrgName: string; out ExeName: string;
  NamePostFix: String=''; ExtraArgs: String='');
begin
  Parent.TestCompile(PrgName, ExeName, NamePostFix, ExtraArgs);
end;

{ --- }

procedure RegisterDbgTest(ATestClass: TTestCaseClass);
var
  Suite: TTestSuite;
  i: Integer;
begin
  Suite := GetTestRegistry;
  for i := 0 to Suite.Tests.Count - 1 do
    if Suite.Test[i] is TCompilerSuite then
      TCompilerSuite(Suite.Test[i]).RegisterDbgTest(ATestClass);
end;


procedure BuildTestSuites;
var
  FpcList: TCompilerList;
  GdbList: TDebuggerList;
  CompilerSuite: TCompilerSuite;
  i: Integer;
  st: TSymbolType;
begin
  FpcList := GetCompilers;
  GdbList := GetDebuggers;

  for i := 0 to FpcList.Count - 1 do begin
    for st := low(TSymbolType) to high(TSymbolType) do begin
      if not (st in FpcList.CompilerInfo[i].SymbolTypes) then
        continue;

      CompilerSuite := TCompilerSuite.Create(FpcList.CompilerInfo[i], st, GdbList);
      if CompilerSuite.Tests.Count >0 then
        GetTestRegistry.AddTest(CompilerSuite)
      else
        CompilerSuite.Free;
    end;
  end;
end;

function CheckAppDir(var AppDir: string): Boolean;
begin
  Result := DirectoryExistsUTF8(AppDir + 'TestApps');
end;

function CheckAppDirLib(var AppDir: string): Boolean;
var
  s: string;
begin
  Result := False;
  if RightStr(AppDir, length('lib' + DirectorySeparator)) = 'lib' + DirectorySeparator
  then begin
    s := copy(AppDir, 1, length(AppDir) - length('lib' + DirectorySeparator));
    Result :=  DirectoryExistsUTF8(s + 'TestApps');
    if Result then
      AppDir := s;
  end;
end;

function AppDirStripAppBundle(AppDir: string): String;
var
  p: LongInt;
begin
  Result := AppDir;
  p := pos('.app' + DirectorySeparator, AppDir);
  while (p > 1) and (AppDir[p-1] <> DirectorySeparator) do
    dec(p);
  if p > 1 then
    Result := Copy(AppDir, 1, p - 1);
end;

initialization
  AppDir := AppendPathDelim(ExtractFilePath(Paramstr(0)));
  if  not(CheckAppDir(AppDir))
  and not(CheckAppDirLib(AppDir))
  then begin
    AppDir := AppDirStripAppBundle(AppDir);
    if  not(CheckAppDir(AppDir))
    and not(CheckAppDirLib(AppDir))
    then
      with TSelectDirectoryDialog.Create(nil) do begin
        if Execute then AppDir := AppendPathDelim(FileName);
        Free;
      end;
  end;
  ConfDir := AppDir;
  AppDir := AppendPathDelim(AppDir + 'TestApps');


  EnvironmentOptions := TEnvironmentOptions.Create;
  with EnvironmentOptions do
  begin
    SetLazarusDefaultFilename;
    Load(false);
  end;

  BuildTestSuites;

finalization
  FreeAndNil(Compilers);
  FreeAndNil(Debuggers);
  FreeAndNil(EnvironmentOptions);

end.

