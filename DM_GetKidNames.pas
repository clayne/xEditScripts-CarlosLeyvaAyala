unit GetKidNames;
{
  Hotkey: Ctrl+K

  Gets editor IDs separated by comma for adding to a KID list.
}
interface

uses xEditApi;

implementation

var
  items, outfits, keywords, spidStrings, spidForms: TStringList;

procedure CreateObjects;
begin
    items := TStringList.Create;
    outfits := TStringList.Create;
    keywords := TStringList.Create;
    spidStrings := TStringList.Create;
    spidForms := TStringList.Create;
end;

procedure FreeObjects;
begin
    items.Free;
    outfits.Free;
    keywords.Free;
    spidStrings.Free;
    spidForms.Free;
end;

function IsESL(f: IInterface): Boolean;
begin
  Result := GetElementEditValues(ElementByIndex(f, 0), 'Record Header\Record Flags\ESL') = 1;
end;

function ActualFixedFormId(e: IInterface): string;
var
  fID, ffID: Cardinal;
begin
  fID := FormID(e);
  if(IsESL(GetFile(e))) then ffID := fID and $FFF
  else ffID := fID and $FFFFFF;
  Result := Lowercase(IntToHex(ffID, 1));
end;

function KeywordIndex(e: IInterface; edid: string): Integer;
var
  kwda: IInterface;
  n: integer;
begin
  Result := -1;
  kwda := ElementByPath(e, 'KWDA');
  for n := 0 to ElementCount(kwda) - 1 do
    if GetElementEditValues(LinksTo(ElementByIndex(kwda, n)), 'EDID') = edid then begin
      Result := n;
      Exit;
    end;
end;

function HasKeyword(e: IInterface; edid: string): boolean;
begin
  Result := KeywordIndex(e, edid) <> -1;
end;

function RecordToStr(e: IInterface): string;
begin
  e := MasterOrSelf(e);
  Result := Format('%s|%s', [
    GetFileName(GetFile(e)),
    ActualFixedFormId(e)
  ]);
end;

procedure AddSeparator;
begin
    AddMessage(#13#10);
end;

function Initialize: Integer;
begin
    CreateObjects;
    AddSeparator;
    AddSeparator;
end;

///////////////////////////////////////////////////////////////////////
// Item
///////////////////////////////////////////////////////////////////////
procedure AddItem(e: IInterface);
var
    ed, f, n, kidLine, s: string;
begin
    ed := EditorID(e);
    f := RecordToStr(e);
    s := Signature(e);
    n := DisplayName(e);
    kidLine := Format('%s|%s|%s|%s', [ed, f, s, n]);
    AddMessage(kidLine);
    items.Add(kidLine);
end;

///////////////////////////////////////////////////////////////////////
// Outfit
///////////////////////////////////////////////////////////////////////
function GetOutfitItems(e: IInterface): string;
var
    i: Integer;
    lst: TStringList;
    items, li, piece: IInterface;
begin
    items := ElementBySignature(e, 'INAM');
    if not Assigned(items) then Exit;
    Result := '***Error***';

    lst := TStringList.Create;
    try
        for i := 0 to ElementCount(items) - 1 do begin
            li := ElementByIndex(items, i);
            piece := LinksTo(li);
            lst.add(RecordToStr(piece));
        end;
        Result := lst.commaText;
    finally
        lst.Free;
    end;

    Result := StringReplace(Result, '"', '', [rfReplaceAll]);
    Result := StringReplace(Result, '|', '~', [rfReplaceAll]);
end;

procedure AddOutfit(e: IInterface);
var
    ed, f, kidLine: string;
begin
    ed := EditorID(e);
    f := RecordToStr(e);
    kidLine := Format('%s|%s|OTFT|%s', [ed, f, GetOutfitItems(e)]);
    AddMessage(kidLine);
    outfits.Add(kidLine);
end;

///////////////////////////////////////////////////////////////////////
// Keyword
///////////////////////////////////////////////////////////////////////
procedure AddKeyword(e: IInterface);
var 
    output: string;
begin
    output := EditorID(e);
    AddMessage(output);
    keywords.Add(output);
end;

///////////////////////////////////////////////////////////////////////
// NPC
///////////////////////////////////////////////////////////////////////
procedure AddNPC(e: IInterface);
var 
    full, short: string;
    iRace: IInterface;
begin
    iRace := LinksTo(ElementByPath(e, 'RNAM'));

    if not HasKeyword(iRace, 'ActorTypeNPC') 
        or ElementExists(e, 'ACBS - Configuration\Flags\Is CharGen Face Preset') then Exit;

    AddMessage(EditorID(e));
    spidStrings.Add(EditorID(e));

    full := GetElementEditValues(e, 'FULL');
    if full <> ''then spidStrings.Add(full);

    short := GetElementEditValues(e, 'SHRT');
    if short <> '' then spidStrings.Add(short);
end;

///////////////////////////////////////////////////////////////////////
// Base processing
///////////////////////////////////////////////////////////////////////

function Process(e: IInterface): Integer;
var
    s: string;
begin
    s := Signature(e);
    if ((s = 'ARMO') or (s = 'WEAP') or (s = 'AMMO')) then AddItem(e)
    else if s= 'OTFT' then AddOutfit(e)
    else if s= 'NPC_' then AddNPC(e)
    else if s= 'KYWD' then AddKeyword(e);
end;

procedure SaveFile(const contents: TStringList; filename: string);
begin
    if contents.Count > 0 then contents.SaveToFile('Edit Scripts\' + filename);
end;

function Finalize: Integer;
begin
    AddSeparator;
    AddSeparator;
    SaveFile(items, '___.items');
    SaveFile(outfits, '___.outfits');
    SaveFile(keywords, '___.keywords');
    SaveFile(spidStrings, '___.spidstrs');
    SaveFile(spidForms, '___.spidfrms');
    // if items.Count > 0 then items.SaveToFile('Edit Scripts\___.items');
    // if outfits.Count > 0 then outfits.SaveToFile('Edit Scripts\___.outfits');
    FreeObjects;
end;

end.
