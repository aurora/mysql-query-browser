{ Replaces dxgettext's gnugettext unit for the ported sources.

  The sources call _('English text') everywhere. This unit reads GNU .po files
  directly (no msgfmt/.mo step) from

      <dir>/<language>/LC_MESSAGES/<domain>.po         e.g. locale/de/LC_MESSAGES/query-browser.po

  with <dir> from bindtextdomain(). Several domains can be bound; the lookup tries
  the domains in the order they were bound. Fuzzy entries are ignored, plural forms
  use msgstr[0]. Without a translation the English text is returned. }
unit gnugettext;

{$mode delphi}

interface

uses
  Classes, SysUtils;

function _(const MsgId: String): String;

procedure bindtextdomain(const Domain, Directory: String);
procedure textdomain(const Domain: String);
procedure AddDomainForResourceString(const Domain: String);

{ Language code like 'de' or 'pt_BR'; '' selects the system language }
procedure UseLanguage(const LanguageCode: String);
function GetCurrentLanguage: String;

{ Not needed: the LCL forms are translated explicitly. Kept so ported code compiles. }
procedure TP_GlobalIgnoreClass(AClass: TClass);
{ Translate Caption and Hint of a component tree }
procedure TranslateComponent(AnObject: TComponent; const TextDomain: String = '');

implementation

uses
  gettext, Generics.Collections, TypInfo;

type
  TDomain = class
    Name, Dir: String;
    Loaded: Boolean;
    Table: TDictionary<String, String>;
    constructor Create(const AName, ADir: String);
    destructor Destroy; override;
    procedure Load(const Lang: String);
  end;

var
  Domains: TObjectList<TDomain>;
  CurrentLanguage: String;
  LanguageResolved: Boolean;

{ ---- .po parsing ---------------------------------------------------------- }

function Unquote(const S: String): String;
var
  I: Integer;
  T: String;
begin
  T := Trim(S);
  if (Length(T) >= 2) and (T[1] = '"') then
    T := Copy(T, 2, Length(T) - 2);
  Result := '';
  I := 1;
  while I <= Length(T) do
  begin
    if (T[I] = '\') and (I < Length(T)) then
    begin
      Inc(I);
      case T[I] of
        'n': Result := Result + #10;
        't': Result := Result + #9;
        'r': Result := Result + #13;
        '"': Result := Result + '"';
        '\': Result := Result + '\';
      else
        Result := Result + '\' + T[I];
      end;
    end
    else
      Result := Result + T[I];
    Inc(I);
  end;
end;

constructor TDomain.Create(const AName, ADir: String);
begin
  inherited Create;
  Name := AName;
  Dir := ADir;
  Table := TDictionary<String, String>.Create;
end;

destructor TDomain.Destroy;
begin
  Table.Free;
  inherited Destroy;
end;

procedure TDomain.Load(const Lang: String);
var
  Candidates: array of String;
  Lines: TStringList;
  I, N: Integer;
  Line, Id, Str: String;
  Target: Integer;       // 0 none, 1 msgid, 2 msgstr
  Fuzzy: Boolean;
  FileName: String;

  procedure Flush;
  begin
    if (Id <> '') and (Str <> '') and not Fuzzy then
      Table.AddOrSetValue(Id, Str);
    Id := '';
    Str := '';
    Fuzzy := False;
    Target := 0;
  end;

begin
  Table.Clear;
  Loaded := True;
  if Lang = '' then
    Exit;
  // 'pt_BR' -> try pt_BR, then pt
  SetLength(Candidates, 2);
  Candidates[0] := Lang;
  Candidates[1] := Copy(Lang, 1, Pos('_', Lang + '_') - 1);
  FileName := '';
  for I := 0 to High(Candidates) do
    if FileExists(IncludeTrailingPathDelimiter(Dir) + Candidates[I] + PathDelim + 'LC_MESSAGES' + PathDelim + Name + '.po') then
    begin
      FileName := IncludeTrailingPathDelimiter(Dir) + Candidates[I] + PathDelim + 'LC_MESSAGES' + PathDelim + Name + '.po';
      Break;
    end;
  if FileName = '' then
    Exit;
  Lines := TStringList.Create;
  try
    Lines.LoadFromFile(FileName);
    Id := '';
    Str := '';
    Fuzzy := False;
    Target := 0;
    for N := 0 to Lines.Count - 1 do
    begin
      Line := Trim(Lines[N]);
      if Line = '' then
        Flush
      else if Copy(Line, 1, 2) = '#,' then
        Fuzzy := Fuzzy or (Pos('fuzzy', Line) > 0)
      else if Line[1] = '#' then
        Continue
      else if Copy(Line, 1, 7) = 'msgctxt' then
        Target := 0
      else if Copy(Line, 1, 12) = 'msgid_plural' then
        Target := 0
      else if Copy(Line, 1, 5) = 'msgid' then
      begin
        if Target = 2 then                 // entry without a separating blank line
          Flush;
        Target := 1;
        Id := Unquote(Copy(Line, 6, MaxInt));
      end
      else if (Copy(Line, 1, 6) = 'msgstr') then
      begin
        if (Pos('[', Line) = 7) and (Pos('[0]', Line) <> 7) then
          Target := 0                      // msgstr[1..]: only the singular form is used
        else
        begin
          Target := 2;
          Str := Unquote(Copy(Line, Pos(' ', Line) + 1, MaxInt));
        end;
      end
      else if Line[1] = '"' then
      begin
        if Target = 1 then
          Id := Id + Unquote(Line)
        else if Target = 2 then
          Str := Str + Unquote(Line);
      end;
    end;
    Flush;
  finally
    Lines.Free;
  end;
end;

{ ---- public API ------------------------------------------------------------ }

procedure ResolveLanguage;
var
  Lang, Fallback: String;
  D: TDomain;
begin
  if CurrentLanguage = '' then
  begin
    GetLanguageIDs(Lang, Fallback);
    CurrentLanguage := Lang;
  end;
  for D in Domains do
    if not D.Loaded then
      D.Load(CurrentLanguage);
  LanguageResolved := True;
end;

function _(const MsgId: String): String;
var
  D: TDomain;
begin
  Result := MsgId;
  if MsgId = '' then
    Exit;
  if not LanguageResolved then
    ResolveLanguage;
  for D in Domains do
    if D.Table.TryGetValue(MsgId, Result) then
      Exit;
  Result := MsgId;
end;

procedure bindtextdomain(const Domain, Directory: String);
var
  D: TDomain;
begin
  for D in Domains do
    if SameText(D.Name, Domain) then
    begin
      D.Dir := Directory;
      D.Loaded := False;
      LanguageResolved := False;
      Exit;
    end;
  Domains.Add(TDomain.Create(Domain, Directory));
  LanguageResolved := False;
end;

procedure textdomain(const Domain: String);
var
  I: Integer;
begin
  // the default domain is looked up first
  for I := 0 to Domains.Count - 1 do
    if SameText(Domains[I].Name, Domain) then
    begin
      Domains.Move(I, 0);
      Exit;
    end;
end;

procedure AddDomainForResourceString(const Domain: String);
begin
  // resourcestrings are not translated through gettext in the ported code
end;

procedure UseLanguage(const LanguageCode: String);
var
  D: TDomain;
begin
  CurrentLanguage := LanguageCode;
  for D in Domains do
    D.Loaded := False;
  LanguageResolved := False;
end;

function GetCurrentLanguage: String;
begin
  if not LanguageResolved then
    ResolveLanguage;
  Result := CurrentLanguage;
end;

procedure TP_GlobalIgnoreClass(AClass: TClass);
begin
end;

procedure TranslateComponent(AnObject: TComponent; const TextDomain: String);
var
  I: Integer;
  Info: PPropInfo;
begin
  if AnObject = nil then
    Exit;
  for I := 0 to 1 do
  begin
    if I = 0 then
      Info := GetPropInfo(AnObject, 'Caption')
    else
      Info := GetPropInfo(AnObject, 'Hint');
    if (Info <> nil) and (Info^.PropType^.Kind in [tkAString, tkSString, tkLString, tkUString, tkWString]) then
      SetStrProp(AnObject, Info, _(GetStrProp(AnObject, Info)));
  end;
  for I := 0 to AnObject.ComponentCount - 1 do
    TranslateComponent(AnObject.Components[I]);
end;

initialization
  Domains := TObjectList<TDomain>.Create(True);

finalization
  Domains.Free;

end.
