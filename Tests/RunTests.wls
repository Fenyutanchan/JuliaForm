#!/usr/bin/env wolframscript

$CharacterEncoding = "UTF-8";

testDirectory = DirectoryName[$InputFileName];
pacletDirectory = DirectoryName[testDirectory];

Needs["PacletTools`"];
PacletDirectoryLoad[pacletDirectory];

report = TestReport[FileNameJoin[{testDirectory, "JuliaForm.wlt"}]];
Print[Map[Length, report["ResultsByOutcome"]]];

If[
    TrueQ[report["ReportSucceeded"]],
    Exit[0],
    failed = KeyDrop[report["ResultsByOutcome"], "Success"];
    Print[Cases[
        failed,
        TestObject[data_] :> Lookup[data, "TestID", Missing["NotAvailable"]],
        Infinity
    ]];
    Exit[1]
];
