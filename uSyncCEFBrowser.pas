{
  This is a unit for synchronous use of the basic features of CEF4Delphi Browser.

  Version: 0.1

  https://github.com/wanips7/SyncCEFBrowser
}

unit uSyncCEFBrowser;

interface

uses
  Winapi.Windows, Winapi.Messages, System.SysUtils, System.Classes, System.SyncObjs,
  uCEFChromium, uCEFTypes, uCEFInterfaces, uCEFConstants, uCEFApplication;

type
  TOnLoad = procedure(Sender: TObject; const Url: string) of object;
  TOnLoadEnd = procedure(Sender: TObject; const Url, ResponseBody: string; const StatusCode: Integer) of object;
  TOnLoadError = procedure(Sender: TObject; const Url: string; const ErrorCode: Integer) of object;

type
  TSyncCEFBrowser = class
  private const
    DEFAULT_WAIT_TIME = 10000;
    HTTP_OK = 200;
    EMPTY_HTML_BODY = '<html><head></head><body></body></html>';
  private
    FOnLoad: TOnLoad;
    FOnLoadEnd: TOnLoadEnd;
    FOnLoadError: TOnLoadError;
    FInitializedEvent: TEvent;
    FInitialized: Boolean;
    FEndRequestEvent: TSimpleEvent;
    FHtmlBodyCreatedEvent: TSimpleEvent;
    FScriptExecutedEvent: TSimpleEvent;
    FWaitScriptResult: Boolean;
    FAfterLoadTimeout: Cardinal;
    FResponseText: string;
    FStatusCode: Integer;
    FBrowser: TChromium;
    FScriptResultPrefix: string;
    FScriptResult: string;
    procedure DoLoad(const Url: string);
    procedure DoLoadEnd(const Url, ResponseBody: string; const StatusCode: Integer);
    procedure DoLoadError(const Url: string; const ErrorCode: Integer);
    procedure BrowserConsoleMessage(Sender: TObject; const browser: ICefBrowser; level: TCefLogSeverity;
      const message, source: ustring; line: Integer; out Result: Boolean);
    procedure BrowserLoadEnd(Sender: TObject; const browser: ICefBrowser; const frame: ICefFrame; httpStatusCode: Integer);
    procedure BrowserTextResultAvailable(Sender: TObject; const Text: ustring);
    procedure BrowserLoadingStateChange(Sender: TObject; const Browser: ICefBrowser; isLoading, canGoBack, canGoForward: Boolean);
    procedure BrowserLoadStart(Sender: TObject; const Browser: ICefBrowser; const Frame: ICefFrame; transitionType: Cardinal);
    procedure BrowserLoadError(Sender: TObject; const Browser: ICefBrowser; const Frame: ICefFrame; ErrorCode: Integer; const ErrorText, FailedUrl: ustring);
    procedure BrowserAfterCreated(Sender: TObject; const browser: ICefBrowser);
  public
    property OnLoad: TOnLoad read FOnLoad write FOnLoad;
    property OnLoadEnd: TOnLoadEnd read FOnLoadEnd write FOnLoadEnd;
    property OnLoadError: TOnLoadError read FOnLoadError write FOnLoadError;
    property Initialized: Boolean read FInitialized;
    property Browser: TChromium read FBrowser;
    property AfterLoadTimeout: Cardinal read FAfterLoadTimeout write FAfterLoadTimeout;
    property ResponseText: string read FResponseText;
    property StatusCode: Integer read FStatusCode;
    constructor Create;
    destructor Destroy; override;
    function LoadUrl(const Url: string): Boolean;
    procedure Stop;
    function ExecuteJavaScript(const Script, ResultPrefix: string): string;
    procedure WaitInit;
  end;

procedure CreateGlobalCEFApp;

implementation

procedure CreateGlobalCEFApp;
begin
  GlobalCEFApp := TCefApplication.Create;
  GlobalCEFApp.WindowlessRenderingEnabled := True;
  GlobalCEFApp.TouchEvents := STATE_DISABLED;
  GlobalCEFApp.LogSeverity := LOGSEVERITY_DISABLE;
  GlobalCEFApp.DisableImageLoading := True;
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
  GlobalCEFApp.StartMainProcess;
end;

{ TSyncCEFBrowser }

procedure TSyncCEFBrowser.BrowserAfterCreated(Sender: TObject; const browser: ICefBrowser);
begin
  FInitializedEvent.SetEvent;
  FInitialized := True;
end;

procedure TSyncCEFBrowser.BrowserConsoleMessage(Sender: TObject; const browser: ICefBrowser;
  level: TCefLogSeverity; const message, source: ustring; line: Integer; out Result: Boolean);
var
  Output: string;
begin
  if FWaitScriptResult then
  begin
    Output := message;

    if Output.StartsWith(FScriptResultPrefix) then
    begin
      FScriptResult := Output.Remove(0, FScriptResultPrefix.Length);
      FScriptExecutedEvent.SetEvent;
    end;
  end;
end;

procedure TSyncCEFBrowser.BrowserLoadEnd(Sender: TObject; const browser: ICefBrowser; const frame: ICefFrame;
  httpStatusCode: Integer);
begin
  if Frame.IsMain then
  begin
    FStatusCode := httpStatusCode;
    FEndRequestEvent.SetEvent;
  end;
end;

procedure TSyncCEFBrowser.BrowserLoadError(Sender: TObject; const browser: ICefBrowser; const frame: ICefFrame; errorCode: Integer;
  const errorText, failedUrl: ustring);
begin
  if Frame.IsMain then
  begin
    FStatusCode := 0;
    FEndRequestEvent.SetEvent;
    DoLoadError(failedUrl, errorCode);
  end;
end;

procedure TSyncCEFBrowser.BrowserLoadingStateChange(Sender: TObject; const browser: ICefBrowser;
  isLoading, canGoBack, canGoForward: Boolean);
begin
  //
end;

procedure TSyncCEFBrowser.BrowserLoadStart(Sender: TObject; const browser: ICefBrowser; const frame: ICefFrame;
  transitionType: Cardinal);
begin
  //
end;

procedure TSyncCEFBrowser.BrowserTextResultAvailable(Sender: TObject; const Text: ustring);
begin
  if Text <> EMPTY_HTML_BODY then
  begin
    FResponseText := Text;
  end;

  FHtmlBodyCreatedEvent.SetEvent;
end;

constructor TSyncCEFBrowser.Create;
begin
  FOnLoad := nil;
  FOnLoadEnd := nil;
  FOnLoadError := nil;

  FInitializedEvent := TEvent.Create;
  FInitialized := False;
  FStatusCode := 0;
  FResponseText := '';
  FWaitScriptResult := False;

  FEndRequestEvent := TSimpleEvent.Create;
  FHtmlBodyCreatedEvent := TSimpleEvent.Create;
  FScriptExecutedEvent := TSimpleEvent.Create;

  FAfterLoadTimeout := 1000;

  FBrowser := TChromium.Create(nil);
  FBrowser.OnTextResultAvailable := BrowserTextResultAvailable;
  FBrowser.OnLoadingStateChange := BrowserLoadingStateChange;
  FBrowser.OnLoadStart := BrowserLoadStart;
  FBrowser.OnLoadEnd := BrowserLoadEnd;
  FBrowser.OnLoadError := BrowserLoadError;
  FBrowser.OnAfterCreated := BrowserAfterCreated;
  FBrowser.OnConsoleMessage := BrowserConsoleMessage;
  FBrowser.Options.ImageLoading := STATE_DISABLED;
  FBrowser.CreateBrowser;

end;

destructor TSyncCEFBrowser.Destroy;
begin
  FInitializedEvent.Free;
  FScriptExecutedEvent.Free;
  FHtmlBodyCreatedEvent.Free;
  FEndRequestEvent.Free;
  FBrowser.Free;

  inherited;
end;

procedure TSyncCEFBrowser.DoLoad(const Url: string);
begin
  if Assigned(FOnLoad) then
    FOnLoad(Self, Url);
end;

procedure TSyncCEFBrowser.DoLoadEnd(const Url, ResponseBody: string; const StatusCode: Integer);
begin
  if Assigned(FOnLoadEnd) then
    FOnLoadEnd(Self, Url, ResponseBody, StatusCode);
end;

procedure TSyncCEFBrowser.DoLoadError(const Url: string; const ErrorCode: Integer);
begin
  if Assigned(FOnLoadError) then
    FOnLoadError(Self, Url, ErrorCode);
end;

function TSyncCEFBrowser.ExecuteJavaScript(const Script, ResultPrefix: string): string;
begin
  FScriptExecutedEvent.ResetEvent;
  FScriptResult := '';
  FScriptResultPrefix := ResultPrefix;
  FWaitScriptResult := True;

  FBrowser.ExecuteJavaScript(Script, FBrowser.Browser.MainFrame.Url);

  FScriptExecutedEvent.WaitFor(DEFAULT_WAIT_TIME);

  Result := FScriptResult;
  FWaitScriptResult := False;
end;

function TSyncCEFBrowser.LoadUrl(const Url: string): Boolean;
begin
  if not FInitialized then
  begin
    Exit(False);
  end;

  DoLoad(Url);

  FResponseText := '';
  FStatusCode := 0;
  FEndRequestEvent.ResetEvent;
  FHtmlBodyCreatedEvent.ResetEvent;

  FBrowser.LoadURL(Url);
  FEndRequestEvent.WaitFor(DEFAULT_WAIT_TIME);

  Sleep(FAfterLoadTimeout);

  FBrowser.StopLoad;
  FBrowser.RetrieveHTML;
  FHtmlBodyCreatedEvent.WaitFor(DEFAULT_WAIT_TIME);

  Result := not FResponseText.IsEmpty;

  DoLoadEnd(Url, FResponseText, FStatusCode);
end;

procedure TSyncCEFBrowser.Stop;
begin
  FEndRequestEvent.SetEvent;
  FHtmlBodyCreatedEvent.SetEvent;
end;

procedure TSyncCEFBrowser.WaitInit;
begin
  FInitializedEvent.WaitFor(DEFAULT_WAIT_TIME);
end;

end.
