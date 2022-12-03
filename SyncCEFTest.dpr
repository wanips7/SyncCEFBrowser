{
  This is an example of synchronous use of the basic features of CEF4Delphi Browser.

  https://github.com/wanips7/SyncCEFBrowser
}

program SyncCEFTest;

{$APPTYPE CONSOLE}

{$R *.res}

uses
  System.SysUtils,
  System.SyncObjs,
  Winapi.Windows,
  Winapi.Messages,
  uSyncCEFBrowser,
  uCEFConstants,
  uCEFApplication,
  System.IOUtils,
  uCEFTypes;

const
  URL = 'https://www.wikipedia.org';
  WAIT_TIME = 5000;

var
  Browser: TSyncCEFBrowser;
  GlobalCEFAppInitEvent: TEvent = nil;
  AppPath: string = '';
  SaveFilePath: string = '';

procedure OnContextInitialized;
begin
  GlobalCEFAppInitEvent.SetEvent;
end;

procedure CreateGlobalCEFApp;
begin
  GlobalCEFApp := TCefApplication.Create;
  GlobalCEFApp.WindowlessRenderingEnabled := True;
  GlobalCEFApp.TouchEvents := STATE_DISABLED;
  GlobalCEFApp.LogSeverity := LOGSEVERITY_DISABLE;
  GlobalCEFApp.DisableImageLoading := False;
  GlobalCEFApp.ShowMessageDlg := False;
  GlobalCEFApp.EnableHighDPISupport := False;
  GlobalCEFApp.ShowMessageDlg := False;
  GlobalCEFApp.BlinkSettings := 'hideScrollbars=true,scrollAnimatorEnabled=false';
  GlobalCEFApp.EnableGPU := False;
  GlobalCEFApp.SmoothScrolling := STATE_DISABLED;
  GlobalCEFApp.EnableSpeechInput := False;
  GlobalCEFApp.EnableUsermediaScreenCapturing := False;
  GlobalCEFApp.EnablePrintPreview := False;
  GlobalCEFApp.DisableJavascriptAccessClipboard := True;
  GlobalCEFApp.DisableJavascriptDomPaste := True;
  GlobalCEFApp.DisableSpellChecking := True;
  GlobalCEFApp.MuteAudio := True;
  GlobalCEFApp.AllowFileAccessFromFiles := True;
  GlobalCEFApp.EnableMediaStream := False;
  GlobalCEFApp.IgnoreCertificateErrors := True;
  GlobalCEFApp.NoSandbox := True;
  GlobalCEFApp.DisableBackForwardCache := True;
  GlobalCEFApp.DeleteCache := True;
  GlobalCEFApp.DeleteCookies := True;
  GlobalCEFApp.PersistSessionCookies := False;
  GlobalCEFApp.PersistUserPreferences := False;
  GlobalCEFApp.OnContextInitialized := OnContextInitialized;
  GlobalCEFApp.StartMainProcess;

  GlobalCEFAppInitEvent.WaitFor(WAIT_TIME);
end;

procedure Deinit;
begin
  Browser.Free;
  GlobalCEFAppInitEvent.Free;
  DestroyGlobalCEFApp;
end;

function ConsoleEventProc(CtrlType: DWORD): BOOL; stdcall;
begin
  if (CtrlType = CTRL_CLOSE_EVENT) then
  begin
    Deinit;
  end;

  Result := True;
end;

procedure Print(const Value: string);
begin
  Writeln(FormatDateTime('[hh:nn:ss] ', Now) + Value);
end;

procedure PrintF(const Value: string; const Args: array of const);
begin
  Print(Format(Value, Args));
end;

procedure Init;
begin
  SetConsoleCtrlHandler(@ConsoleEventProc, True);
  AppPath := ExtractFilePath(ParamStr(0));
  SaveFilePath := AppPath + 'Response.txt';

  GlobalCEFAppInitEvent := TEvent.Create;

  CreateGlobalCEFApp;

  Print('Init...');

  Browser := TSyncCEFBrowser.Create;
  Browser.WaitInit;

end;

begin
  Init;

  try
    PrintF('Loading %s...', [URL]);

    if Browser.LoadUrl(URL) then
    begin
      PrintF('Done, saved to: %s', [SaveFilePath]);

      TFile.WriteAllText(SaveFilePath, Browser.ResponseText);
    end
      else
    begin
      Print('Failed.');
    end;

  except
    on E: Exception do
      Writeln(E.ClassName, ': ', E.Message);
  end;

  Readln;
end.
