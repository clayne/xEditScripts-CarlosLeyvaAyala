#r "nuget: TextCopy"

open System.IO
open System.Text.RegularExpressions
open System

type OutFilePrompt =
    | WantsVanilla = 1
    | WantsSummermyst = 2

let getOutFile () =
    printfn "Select the destination file:"
    printfn "\t1) Vanilla WAED"
    printfn "\t2) Summermyst WAED"

    match Console.ReadLine()
          |> Int32.Parse
          |> enum<OutFilePrompt>
        with
    | OutFilePrompt.WantsVanilla -> "WAED Enchantments.esp"
    | OutFilePrompt.WantsSummermyst -> "WAED Enchantments - Summermyst.esp"
    | x -> failwith $"({x}) is not a valid option"

type EnchFX =
    { name: string
      magnitude: float
      area: int
      duration: int }

let getEffects text =
    let ms = Regex(@"(?ms)\*\*\*S(.*?)\*\*\*E").Matches(text)

    let effects =
        [| for m in ms do
               m.Groups[1].Value |]
        |> Array.map (fun s ->
            s.Trim().Split("\n")
            |> Array.map (fun s2 -> s2.Trim()))
        |> Array.map (fun a ->
            let v n = a[n][a[ n ].IndexOf(": ") + 2 ..]

            { name = a[0]
              magnitude = v 1 |> Double.Parse
              area = v 2 |> Int32.Parse
              duration = v 3 |> Int32.Parse })
        |> Array.map (fun fx ->
            """
    fx := ElementAssign(fxs, HighInteger, nil, false);
    SetElementEditValues(fx, 'EFID', '___name___');
    SetElementEditValues(fx, 'EFIT\Magnitude', ___magnitude___);
    SetElementEditValues(fx, 'EFIT\Area', ___area___);
    SetElementEditValues(fx, 'EFIT\Duration', ___duration___);"""
                .Replace("___name___", fx.name)
                .Replace("___magnitude___", fx.magnitude.ToString())
                .Replace("___area___", fx.area.ToString())
                .Replace("___duration___", fx.duration.ToString()))
        |> Array.fold (fun acc s -> acc + "\n" + s) ""

    effects.Trim()

let effects = TextCopy.ClipboardService.GetText() |> getEffects
printfn "%s\n%s\n" effects ("".PadRight(50, '*'))

let outFile = getOutFile ()

let getEnchantName () =
    printfn "What is the enchant name (FULL)?"

    Console.ReadLine()
    |> Globalization
        .CultureInfo(
            "en-US",
            false
        )
        .TextInfo
        .ToTitleCase

let generateEdid enchName =
    "DM_Ench_"
    + Regex(@"\s+").Replace(enchName, "")
    + "_Var"

let full = getEnchantName ()
let edid = generateEdid full

let contents =
    """
unit DM_WAED_AddEnchantments;
{
    *** Autogenerated ***

    Hotkey: Shift+F3
}
interface

uses xEditApi;

implementation

function FileByName(s: string): IInterface;
var
  i: integer;
begin
  Result := nil;

  for i := 0 to FileCount - 1 do 
    if GetFileName(FileByIndex(i)) = s then begin
      Result := FileByIndex(i);
      Exit;
    end;
end;

procedure CopyToWaed(e: IInterface);
var
    newRecord, fxs, fx: IInterface;
begin
    newRecord := wbCopyElementToFile(e, FileByName('___outFile___'), true, true);

    // Clear base enchanment so this can't be learned
    SetElementEditValues(newRecord, 'ENIT\Base Enchantment', '');
    SetElementEditValues(newRecord, 'ENIT\Worn Restrictions', '');

    // Rename
    SetElementEditValues(newRecord, 'EDID', '___edid___');
    SetElementEditValues(newRecord, 'FULL', '___full___');

    // Add new effects
    fxs := ElementByPath(newRecord, 'Effects');

    ___fxs___
end;

function Process(e: IInterface): Integer;
begin
    if Signature(e) = 'ENCH' then CopyToWaed(e);
end;

end.
"""
        .Replace("___fxs___", effects)
        .Replace("___outFile___", outFile)
        .Replace("___edid___", edid)
        .Replace("___full___", full)


File.WriteAllText(Path.Combine(__SOURCE_DIRECTORY__, "DM_WAED_AddEnchantments.pas"), contents)