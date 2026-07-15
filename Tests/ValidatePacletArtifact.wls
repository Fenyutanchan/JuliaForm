#!/usr/bin/env wolframscript

testDirectory = DirectoryName[ExpandFileName[$InputFileName]];
pacletDirectory = DirectoryName[testDirectory];
supportFile = FileNameJoin[{
    pacletDirectory,
    "Scripts",
    "PacletBuildSupport.wl"
}];

supportLoadResult = Quiet[Check[Get[supportFile], $Failed]];
requiredSupportFunctions = {
    JuliaFormBuildSupport`CreatePacletIntegrityInventory,
    JuliaFormBuildSupport`ValidatePacletBuildDirectory,
    JuliaFormBuildSupport`ValidatePacletArchive
};
If[
    supportLoadResult === $Failed ||
        !AllTrue[requiredSupportFunctions, Length[DownValues[#]] > 0 &] ||
        !StringQ[JuliaFormBuildSupport`$IntegrityInventoryFileName],
    Print["Paclet validation support failed to load completely from ", supportFile];
    Exit[1]
];

negativeTestFailure[tag_String, message_String, data_: <||>] :=
    Failure[tag, Join[<|"MessageTemplate" -> message|>, data]];

failureTag[result_] := Replace[
    result,
    Failure[tag_, _Association] :> tag,
    {0}
];

writeTextFile[path_String, contents_String] := Module[{exportResult},
    exportResult = Quiet[Check[
        Export[path, contents, "String"],
        $Failed
    ]];
    exportResult =!= $Failed && FileExistsQ[path]
];

injectEscapingManifestPath[pacletRoot_String] := Module[
    {manifestPath, manifest, entries},

    manifestPath = FileNameJoin[{pacletRoot, "PacletManifest.wl"}];
    manifest = Quiet[Check[Get[manifestPath], $Failed]];
    If[!AssociationQ[manifest],
        Return[False, Module]
    ];
    entries = Lookup[manifest, "Files", Missing["NotAvailable"]];
    If[!ListQ[entries],
        Return[False, Module]
    ];

    AssociateTo[
        manifest,
        "Files" -> Append[
            entries,
            <|
                "File" -> File["../escape.wl"],
                "Hash" -> StringRepeat["0", 64]
            |>
        ]
    ];
    writeTextFile[manifestPath, ToString[InputForm[manifest]]]
];

rewritePacletInfo[pacletRoot_String, rewrite_] := Module[
    {pacletInfoPath, paclet, metadata, rewrittenMetadata, rewrittenPaclet},

    pacletInfoPath = FileNameJoin[{pacletRoot, "PacletInfo.wl"}];
    paclet = Quiet[Check[Get[pacletInfoPath], $Failed]];
    If[!MatchQ[paclet, _PacletObject],
        Return[False, Module]
    ];
    metadata = paclet[[1]];
    rewrittenMetadata = Quiet[Check[rewrite[metadata], $Failed]];
    If[!AssociationQ[rewrittenMetadata],
        Return[False, Module]
    ];
    rewrittenPaclet = Quiet[Check[
        PacletObject[rewrittenMetadata],
        $Failed
    ]];
    If[!MatchQ[rewrittenPaclet, _PacletObject],
        Return[False, Module]
    ];

    writeTextFile[pacletInfoPath, ToString[InputForm[rewrittenPaclet]]]
];

injectNonCanonicalVersion[pacletRoot_String] := rewritePacletInfo[
    pacletRoot,
    Function[metadata,
        Join[metadata, <|"Version" -> "01.2.3"|>]
    ]
];

removeKernelExtension[pacletRoot_String] := rewritePacletInfo[
    pacletRoot,
    Function[metadata,
        Module[{extensions, kernelPosition},
            extensions = Lookup[
                metadata,
                "Extensions",
                Missing["NotAvailable"]
            ];
            If[!ListQ[extensions],
                Return[$Failed, Module]
            ];
            kernelPosition = FirstPosition[extensions, {"Kernel", ___}];
            If[MissingQ[kernelPosition],
                Return[$Failed, Module]
            ];
            (* Preserve the extension count so validation reaches the specific
               missing-Kernel contract check. *)
            Join[
                metadata,
                <|"Extensions" -> ReplacePart[
                    extensions,
                    kernelPosition -> {"Documentation", Language -> All}
                ]|>
            ]
        ]
    ]
];

truncateClassicIndex[pacletRoot_String] := Module[{indexFiles, indexFile},
    indexFiles = Sort[FileNames[
        "*.cfs",
        FileNameJoin[{
            pacletRoot,
            "Documentation",
            "English",
            "Index"
        }],
        1
    ]];
    If[indexFiles === {},
        Return[False, Module]
    ];
    indexFile = First[indexFiles];
    writeTextFile[indexFile, ""] && FileByteCount[indexFile] === 0
];

runBuildDirectoryFailureScenario[
    scenarioName_String,
    baselineRoot_String,
    workspace_String,
    mutator_,
    expectedTag_String
] := Module[
    {
        scenarioDirectory,
        scenarioRoot,
        copyResult,
        mutationResult,
        validationResult
    },

    scenarioDirectory = Quiet[Check[
        CreateDirectory[FileNameJoin[{
            workspace,
            scenarioName <> "-" <> CreateUUID[]
        }]],
        $Failed
    ]];
    If[!StringQ[scenarioDirectory] || !DirectoryQ[scenarioDirectory],
        Return[negativeTestFailure[
            "NegativeRegressionSetupFailed",
            "A negative artifact regression workspace could not be created.",
            <|"Scenario" -> scenarioName|>
        ], Module]
    ];

    scenarioRoot = FileNameJoin[{
        scenarioDirectory,
        FileNameTake[baselineRoot]
    }];
    Internal`WithLocalSettings[
        Null,
        copyResult = Quiet[Check[
            CopyDirectory[baselineRoot, scenarioRoot],
            $Failed
        ]];
        If[copyResult === $Failed || !DirectoryQ[scenarioRoot],
            validationResult = negativeTestFailure[
                "NegativeRegressionSetupFailed",
                "The baseline paclet could not be copied for fault injection.",
                <|"Scenario" -> scenarioName|>
            ],
            mutationResult = Quiet[Check[mutator[scenarioRoot], $Failed]];
            If[!TrueQ[mutationResult],
                validationResult = negativeTestFailure[
                    "NegativeRegressionMutationFailed",
                    "The requested paclet fault could not be injected.",
                    <|"Scenario" -> scenarioName|>
                ],
                validationResult =
                    JuliaFormBuildSupport`ValidatePacletBuildDirectory[
                        scenarioRoot
                    ];
                validationResult = If[
                    failureTag[validationResult] === expectedTag,
                    Print[
                        "Negative artifact regression passed: ",
                        scenarioName,
                        " -> ",
                        expectedTag
                    ];
                    Success[
                        "NegativeArtifactRegression",
                        <|
                            "Scenario" -> scenarioName,
                            "FailureTag" -> expectedTag
                        |>
                    ],
                    negativeTestFailure[
                        "NegativeRegressionDidNotFailClosed",
                        "A corrupted unpacked paclet did not fail with the expected validation result.",
                        <|
                            "Scenario" -> scenarioName,
                            "ExpectedFailureTag" -> expectedTag,
                            "ActualResult" -> validationResult
                        |>
                    ]
                ]
            ]
        ];
        validationResult,
        If[DirectoryQ[scenarioDirectory],
            DeleteDirectory[
                scenarioDirectory,
                DeleteContents -> True
            ]
        ]
    ]
];

runArchiveNameFailureScenario[archive_String, workspace_String] := Module[
    {wrongNameArchive, copyResult, validationResult, expectedTag},

    wrongNameArchive = FileNameJoin[{
        workspace,
        "Wrong-External-Name.paclet"
    }];
    copyResult = Quiet[Check[
        CopyFile[archive, wrongNameArchive, OverwriteTarget -> True],
        $Failed
    ]];
    If[copyResult === $Failed || !FileExistsQ[wrongNameArchive],
        Return[negativeTestFailure[
            "NegativeRegressionSetupFailed",
            "The canonical archive could not be copied under an invalid external name."
        ], Module]
    ];

    expectedTag = "InvalidPacletArchiveName";
    validationResult =
        JuliaFormBuildSupport`ValidatePacletArchive[wrongNameArchive];
    If[failureTag[validationResult] === expectedTag,
        Print[
            "Negative artifact regression passed: wrong-external-archive-name -> ",
            expectedTag
        ];
        Success[
            "NegativeArtifactRegression",
            <|
                "Scenario" -> "wrong-external-archive-name",
                "FailureTag" -> expectedTag
            |>
        ],
        negativeTestFailure[
            "NegativeRegressionDidNotFailClosed",
            "An archive with an invalid external name did not fail with the expected validation result.",
            <|
                "Scenario" -> "wrong-external-archive-name",
                "ExpectedFailureTag" -> expectedTag,
                "ActualResult" -> validationResult
            |>
        ]
    ]
];

runNegativeArtifactRegressions[archive_String] := Module[
    {
        workspace,
        baselineDirectory,
        extractionResult,
        topLevelEntries,
        baselineRoot,
        scenarioResults,
        result
    },

    workspace = Quiet[Check[
        CreateDirectory[FileNameJoin[{
            $TemporaryDirectory,
            "JuliaForm-paclet-negative-regressions-" <> CreateUUID[]
        }]],
        $Failed
    ]];
    If[!StringQ[workspace] || !DirectoryQ[workspace],
        Return[negativeTestFailure[
            "NegativeRegressionSetupFailed",
            "The paclet negative-regression workspace could not be created."
        ], Module]
    ];

    result = Internal`WithLocalSettings[
        Null,
        baselineDirectory = FileNameJoin[{workspace, "baseline"}];
        CreateDirectory[baselineDirectory];
        extractionResult = Quiet[Check[
            ExtractArchive[archive, baselineDirectory],
            $Failed
        ]];
        topLevelEntries = If[
            extractionResult === $Failed,
            {},
            FileNames[All, baselineDirectory, 1]
        ];
        If[
            Length[topLevelEntries] =!= 1 ||
                !DirectoryQ[First[topLevelEntries]],
            negativeTestFailure[
                "NegativeRegressionSetupFailed",
                "The validated archive could not be extracted as a single paclet root."
            ],
            baselineRoot = First[topLevelEntries];
            scenarioResults = {
                runBuildDirectoryFailureScenario[
                    "unregistered-extra-file",
                    baselineRoot,
                    workspace,
                    Function[pacletRoot,
                        writeTextFile[
                            FileNameJoin[{
                                pacletRoot,
                                "UNREGISTERED-FAULT.txt"
                            }],
                            "fault injection\n"
                        ]
                    ],
                    "IntegrityInventoryFileSetMismatch"
                ],
                runBuildDirectoryFailureScenario[
                    "truncated-registered-kernel-file",
                    baselineRoot,
                    workspace,
                    Function[pacletRoot,
                        writeTextFile[
                            FileNameJoin[{
                                pacletRoot,
                                "Kernel",
                                "JuliaForm.wl"
                            }],
                            "(* truncated fault injection *)\n"
                        ]
                    ],
                    "InvalidPacletManifest"
                ],
                runBuildDirectoryFailureScenario[
                    "truncated-documentation-index",
                    baselineRoot,
                    workspace,
                    truncateClassicIndex,
                    "InvalidDocumentationIndex"
                ],
                runBuildDirectoryFailureScenario[
                    "escaping-manifest-path",
                    baselineRoot,
                    workspace,
                    injectEscapingManifestPath,
                    "InvalidPacletManifest"
                ],
                runBuildDirectoryFailureScenario[
                    "noncanonical-paclet-version",
                    baselineRoot,
                    workspace,
                    injectNonCanonicalVersion,
                    "InvalidPacletVersion"
                ],
                runBuildDirectoryFailureScenario[
                    "missing-kernel-extension",
                    baselineRoot,
                    workspace,
                    removeKernelExtension,
                    "InvalidKernelExtension"
                ],
                runArchiveNameFailureScenario[archive, workspace]
            };
            If[AllTrue[scenarioResults, MatchQ[#, _Success] &],
                Success[
                    "PacletNegativeArtifactRegressions",
                    <|"Scenarios" -> Length[scenarioResults]|>
                ],
                negativeTestFailure[
                    "PacletNegativeArtifactRegressionsFailed",
                    "At least one paclet negative artifact regression failed.",
                    <|"Results" -> scenarioResults|>
                ]
            ]
        ],
        If[DirectoryQ[workspace],
            DeleteDirectory[workspace, DeleteContents -> True]
        ]
    ];

    result
];

archives = FileNames[
    "*.paclet",
    FileNameJoin[{pacletDirectory, "dist"}]
];
If[Length[archives] =!= 1,
    Print["Expected exactly one paclet archive, found ", Length[archives], "."];
    Exit[1]
];

result = JuliaFormBuildSupport`ValidatePacletArchive[First[archives]];
If[!MatchQ[result, _Success],
    Print["Paclet artifact validation failed: ", result];
    Exit[1]
];

negativeResult = runNegativeArtifactRegressions[First[archives]];
If[!MatchQ[negativeResult, _Success],
    Print[
        "Paclet negative artifact regression failed: ",
        ToString[InputForm[negativeResult]]
    ];
    Exit[1]
];

Print["Validated paclet artifact: ", First[archives]];
Print["Validated fail-closed artifact regressions: ", negativeResult];
Exit[0];
