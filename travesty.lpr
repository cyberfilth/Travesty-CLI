program travesty;

{$mode objfpc}{$H+}

uses
  Classes,
  resource,
  crt;

const
  ArraySize = 3000;
  MaxPat = 9;
  fileName = 'TEMPalice.txt';

var
  BigArray: packed array [1..ArraySize] of char;
  FreqArray, StartSkip: array[' '..'|'] of integer;
  Pattern: packed array [1..MaxPat] of char;
  SkipArray: array [1..ArraySize] of integer;
  OutChars, PatLength, CharCount, TotalChars, Seed: integer;
  f, deleteMe: TextFile;
  OutputText: string;
  NearEnd: boolean;
  NewChar: char;

  outputString: string;
  ss: TStringStream;
  r: TResourceStream;

  function Random(var RandInt: integer): real;
  begin
    Random := RandInt / 1009;
    RandInt := (31 * RandInt + 11) mod 1009;
  end;

  procedure InParams;
  begin
    WRITELN('Enter a Seed (1..1000) for the randomizer');
    READLN(Seed);
    WRITELN('Number of characters to be output?');
    READLN(OutChars);
    repeat
      WRITELN('What order? <2-', MaxPat, '> (Hint: 5 produces intelligible output)');
      READLN(PatLength)
    until (PatLength in [2..MaxPat]);
    PatLength := PatLength - 1;
    Assign(f, fileName);
    RESET(f);
  end;

  procedure ClearFreq;
  (*  FreqArray is indexed by 93 probable ASCII characters,            *)
  (*  from " " to "|". Its elements are all set to zero.               *)
  var
    ch: char;
  begin
    for ch := ' ' to '|' do
      FreqArray[ch] := 0;
  end; {Procedure ClearFreq}

  procedure NullArrays;
  (* Fill BigArray and Pattern with nulls *)
  var
    j: integer;
  begin
    for j := 1 to ArraySize do
      BigArray[j] := CHR(0);
    for j := 1 to MaxPat do
      Pattern[j] := CHR(0);
  end; {Procedure NullArrays}

  procedure FillArray;
  (*    Moves textfile from disk into BigArray, cleaning it            *)
  (*    up and reducing any run of blanks to one blank.                *)
  (*    Then copies to end of array a string of its opening            *)
  (*    characters as long as the Pattern, in effect wrapping          *)
  (*    the end to the beginning.                                      *)
  var
    Blank: boolean;
    ch: char;
    j: integer;

    procedure Cleanup;
    (* Clears Carriage Returns, Linefeeds, and Tabs out of            *)
    (* input stream. All are changed to blanks.                       *)
    begin
      if ((ch = CHR(13))     {CR} or (ch = CHR(10))   {LF} or (ch = CHR(9)))
      {TAB} then
        ch := ' ';
    end;

  begin {Procedure FillArray}
    j := 1;
    Blank := False;
    while (not EOF(f)) and (j <= (ArraySize - MaxPat)) do
    begin {While Not EOF}
      Read(f, ch);
      Cleanup;
      BigArray[j] := ch;                    {Place character in BigArray}
      if ch = '' then
        Blank := True;
      j := j + 1;
      while (Blank and (not EOF(f)) and (j <= (ArraySize - MaxPat))) do
      begin {While Blank}                    {When a blank has just been}
        Read(f, ch);                            {printed, Blank is true,}
        Cleanup;                      {so succeeding blanks are skipped,}
        if ch <> '' then                            {thus stopping runs.}
        begin {If}
          Blank := False;
          BigArray[j] := ch;                 {To BigArray if not a Blank}
          j := j + 1;
        end; {If}
      end; {While Blank}
    end; {While Not EOF}
    TotalChars := j - 1;
    if BigArray[TotalChars] <> '' then
    begin   {If no Blank at end of text, append one}
      TotalChars := TotalChars + 1;
      BigArray[TotalChars] := ' ';
    end;
    {Copy front of array to back to simulate wraparound.}
    for j := 1 to PatLength do
      BigArray[TotalChars + j] := BigArray[j];
    TotalChars := TotalChars + PatLength;
  end; {Procedure FillArray}

  procedure FirstPattern;
  (* User selects "order" of operation, an integer, n, in the          *)
  (* range 1 .. 9. The input text will henceforth be scanned           *)
  (* in n-sized chunks. The first n-1 characters of the input          *)
  (* file are placed in the "Pattern" Array. The Pattern is            *)
  (* written at the head of output.                                    *)
  var
    j: integer;
  begin
    for j := 1 to PatLength do           {Put opening chars into Pattern}
      Pattern[j] := BigArray[j];
    CharCount := PatLength;
    NearEnd := False;
    for j := 1 to PatLength do
      OutputText := OutputText + Pattern[j];
  end; {Procedure FirstPattern}

  procedure InitSkip;
  (*   The i-th entry of SkipArray contains the smallest index         *)
  (*   j > i such that BigArray[j] = BigArray[i]. Thus SkipArray       *)
  (*   links together all identical characters in BigArray.            *)
  (*   StartSkip contains the index of the first occurrence of         *)
  (*   each character. These two arrays are used to skip the           *)
  (*   matching routine through the text, stopping only at             *)
  (*   locations whose character matches the first character           *)
  (*   in Pattern.                                                     *)
  var
    ch: char;
    j: integer;
  begin
    for ch := ' ' to '|' do
      StartSkip[ch] := TotalChars + 1;
    for j := TotalChars downto 1 do
    begin
      ch := BigArray[j];
      SkipArray[j] := StartSkip[ch];
      StartSkip[ch] := j;
    end;
  end; {Procedure InitSkip}

  procedure Match;
  (*   Checks BigArray for strings that match Pattern; for each        *)
  (*   match found, notes following character and increments its       *)
  (*   count in FreqArray. Position for first trial comes from         *)
  (*   StartSkip; thereafter positions are taken from SkipArray.       *)
  (*   Thus no sequence is checked unless its first character is       *)
  (*   already known to match first character of Pattern.              *)
  var
    i: integer;     {one location before start of the match in BigArray}
    j: integer; {index into Pattern}
    Found: boolean;      {true if there is a match from i+1 to i+j - 1 }
    ch1: char;       {the first character in Pattern; used for skipping}
    NxtCh: char;
  begin {Procedure Match}
    ch1 := Pattern[1];
    i := StartSkip[ch1] - 1;         {is is 1 to left of the Match start}
    while (i <= TotalChars - PatLength - 1) do
    begin {While}
      j := 1;
      Found := True;
      while (Found and (j <= PatLength)) do
        if BigArray[i + j] <> Pattern[j] then
          Found := False   {Go thru Pattern til Match fails}
        else
          j := j + 1;
      if Found then
      begin            {Note next char and increment FreqArray}
        NxtCh := BigArray[i + PatLength + 1];
        FreqArray[NxtCh] := FreqArray[NxtCh] + 1;
      end;
      i := SkipArray[i + 1] - 1;  {Skip to next matching position}
    end; {While}
  end; {Procedure Match}

  procedure WriteCharacter;
  (*   The next character is written. It is chosen at Random           *)
  (*   from characters accumulated in FreqArray during last            *)
  (*   scan of input. Output lines will average 50 character           *)
  (*   in length. If "Verse" option has been selected, a new           *)
  (*   line will commence after any word that ends with "|" in         *)
  (*   input file. Thereafter lines will be indented until             *)
  (*   the 50-character average has been made up.                      *)
  var
    Counter, Total, Toss: integer;
    ch: char;
  begin
    Total := 0;
    for ch := ' ' to '|' do
      Total := Total + FreqArray[ch]; {Sum counts in FreqArray}
    Toss := TRUNC(Total * Random(Seed)) + 1;
    Counter := 31;
    repeat
      Counter := Counter + 1;                         {We begin with ' '}
      Toss := Toss - FreqArray[CHR(Counter)]
    until Toss <= 0;                                   {Char chosen by}
    NewChar := CHR(Counter);                    {successive subtractions}
    if NewChar <> '|' then
      OutputText := OutputText + NewChar;
    CharCount := CharCount + 1;
    if CharCount mod 50 = 0 then
      NearEnd := True;
    if ((NearEnd) and (NewChar = ' ')) then
    begin {If NearEnd}
      NearEnd := False;
    end; {If NearEnd}
  end; {Procedure Write Character}

  procedure NewPattern;
  (*   This removes the first character of the Pattern and             *)
  (*   appends the character just printed. FreqArray is                *)
  (*   zeroed in preparation for a new scan.                           *)
  var
    j: integer;
  begin
    for j := 1 to PatLength - 1 do
      Pattern[j] := Pattern[j + 1];             {Move all chars leftward}
    Pattern[PatLength] := NewChar;                       {Append NewChar}
    ClearFreq;
  end; {Procedure NewPattern}

{$R *.res}

begin {Main Program}
  CharCount := 0;
  OutChars := 0;

  (* Load resource *)
  ss := TStringStream.Create;
  try
    r := TResourceStream.Create(HINSTANCE, 'ALICE', PChar(RT_RCDATA));
    try
      ss.CopyFrom(r, r.Size);
    finally
      r.Free;
    end;
    outputString := ss.DataString;
  finally
    ss.Free;
  end;

  (* Save as file *)
  AssignFile(deleteMe, fileName);
  try
    ReWrite(deleteMe);
    Write(deleteMe, outputString);
  finally
    CloseFile(deleteMe);
  end;

  Randomize;
  OutputText := '';
  ClearFreq;
  NullArrays;
  InParams;
  FillArray;
  //TotalChars := 2999;
  FirstPattern;
  InitSkip;
  repeat
    Match;
    WriteCharacter;
    NewPattern
  until CharCount >= OutChars;
  writeln();
  writeln(OutputText + '...');
  writeln();
  ReadKey;
end.
