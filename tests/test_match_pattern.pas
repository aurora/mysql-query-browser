{ SPDX-License-Identifier: GPL-2.0-or-later }
unit test_match_pattern;

{ myx_match_pattern decides which nodes the search fields above the Schemata, Bookmarks and History trees keep.
  It matches whole names, * and ? are wildcards, case is ignored (ADR-0029 discusses that). No server needed. }

{$mode objfpc}{$H+}

interface

uses
  Classes, SysUtils, fpcunit, testregistry, myx_public_interface;

type
  TMatchPatternTest = class(TTestCase)
  published
    procedure TestWholeNameWithWildcards;
    procedure TestIgnoresCase;
    procedure TestStrict;
    procedure TestNonAscii;
  end;

implementation

function Match(const Text, Search: String; Strict: Integer = 0): Integer;
begin
  Result := myx_match_pattern(UTF8Decode(Text), UTF8Decode(Search), 0, Strict);
end;

procedure TMatchPatternTest.TestWholeNameWithWildcards;
begin
  // behaviour of the original, unchanged
  AssertEquals('a part of a name does not match', 0, Match('shop', 's'));
  AssertEquals('the whole name matches', 1, Match('shop', 'shop'));
  AssertEquals('prefix with *', 1, Match('shop', 's*'));
  AssertEquals('prefix with * on another name', 0, Match('mysql', 's*'));
  AssertEquals('infix with *', 1, Match('information_schema', '*s*'));
  AssertEquals('one character with ?', 1, Match('shop', 'sh?p'));
  AssertEquals('empty search', -1, Match('shop', ''));
end;

procedure TMatchPatternTest.TestIgnoresCase;
begin
  AssertEquals(1, Match('Kunden', 'KUNDEN'));
  AssertEquals(1, Match('kunden', 'KuN*'));
end;

procedure TMatchPatternTest.TestStrict;
begin
  // the bookmark and history filters call it strict
  AssertEquals(1, Match('select 1', 'select*', 1));
  AssertEquals(0, Match('select 1', 'select', 1));
end;

procedure TMatchPatternTest.TestNonAscii;
begin
  // the original matched no name with non-ASCII characters, not even the name itself
  AssertEquals('the name itself', 1, Match('bär', 'bär'));
  AssertEquals('ignoring case', 1, Match('bär', 'BÄR'));
  AssertEquals('wildcard before a non-ASCII character', 1, Match('größe', '*öß*'));
  AssertEquals('wildcard after a non-ASCII character', 1, Match('größe', 'grö*'));
  AssertEquals('? for a non-ASCII character', 1, Match('bär', 'b?r'));
  AssertEquals('another name', 0, Match('bar', 'bär'));
end;

initialization
  RegisterTest(TMatchPatternTest);

end.
