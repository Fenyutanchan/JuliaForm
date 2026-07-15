BeginPackage["JuliaFormBuildSupport`"];

BuildDocumentationForAllLanguages::usage =
    "BuildDocumentationForAllLanguages[pacletDirectory, buildPacletDirectory, paclet] builds every required documentation language and its indexes.";
CreatePacletIntegrityInventory::usage =
    "CreatePacletIntegrityInventory[directory] writes the independent SHA-256 inventory used to validate every packaged file.";
ValidatePacletBuildDirectory::usage =
    "ValidatePacletBuildDirectory[directory] validates the contents and manifest of an unpacked paclet.";
ValidatePacletArchive::usage =
    "ValidatePacletArchive[archive] extracts and validates a canonical local-build or stable-release paclet archive; a rolling dev asset may be a byte-identical publication alias with a commit-qualified external name.";
$IntegrityInventoryFileName::usage =
    "$IntegrityInventoryFileName is the top-level independent package inventory file.";
$RequiredDocumentationLanguages::usage =
    "$RequiredDocumentationLanguages lists the documentation languages required in every JuliaForm paclet.";

Begin["`Private`"];

$RequiredDocumentationLanguages = {"English", "ChineseSimplified"};
$IntegrityInventoryFileName = "PacletIntegrity.wl";
$ExpectedPacletName = "JuliaForm";
$ExpectedWolframVersion = "15.0+";
$ExpectedKernelFiles = {"Kernel/init.wl", "Kernel/JuliaForm.wl"};

buildFailure[tag_String, message_String, data_: <||>] :=
    Failure[tag, Join[<|"MessageTemplate" -> message|>, data]];

relativeTo[directory_String, file_String] :=
    FileNameDrop[file, Length[FileNameSplit[directory]]];

canonicalRelativeTo[directory_String, file_String] :=
    StringRiffle[FileNameSplit[relativeTo[directory, file]], "/"];

filesBelow[directory_String] :=
    If[
        DirectoryQ[directory],
        Select[FileNames[All, directory, Infinity], FileType[#] === File &],
        {}
    ];

canonicalRelativePathQ[path_String] := Module[{parts},
    If[
        path === "" || StringStartsQ[path, "/"] ||
            StringContainsQ[path, "\\"],
        Return[False, Module]
    ];

    parts = StringSplit[path, "/"];
    parts =!= {} &&
        AllTrue[
            parts,
            # =!= "" && # =!= "." && # =!= ".." &&
                !StringContainsQ[#, ":"] &
        ] &&
        path === StringRiffle[parts, "/"]
];

containedFilePath[pacletRoot_String, path_String] := Module[
    {rootParts, candidate, candidateParts},

    If[!canonicalRelativePathQ[path],
        Return[$Failed, Module]
    ];

    rootParts = FileNameSplit[ExpandFileName[pacletRoot]];
    candidate = ExpandFileName[
        FileNameJoin[Join[{ExpandFileName[pacletRoot]}, StringSplit[path, "/"]]]
    ];
    candidateParts = FileNameSplit[candidate];
    If[
        Length[candidateParts] <= Length[rootParts] ||
            Take[candidateParts, Length[rootParts]] =!= rootParts,
        $Failed,
        candidate
    ]
];

canonicalFileEntries[entries_List] := Module[{rawPaths, paths},
    rawPaths = Lookup[entries, "File", Missing["NotAvailable"]];
    If[!AllTrue[rawPaths, MatchQ[#, File[_String]] &],
        Return[$Failed, Module]
    ];

    paths = Replace[rawPaths, File[path_String] :> path, {1}];
    If[
        !AllTrue[paths, canonicalRelativePathQ] ||
            !DuplicateFreeQ[paths],
        $Failed,
        paths
    ]
];

nonEmptyFileQ[path_String] :=
    FileExistsQ[path] && FileType[path] === File && FileByteCount[path] > 0;

canonicalVersionQ[version_] :=
    StringQ[version] && StringMatchQ[
        version,
        RegularExpression[
            "^(0|[1-9][0-9]*)\\.(0|[1-9][0-9]*)\\.(0|[1-9][0-9]*)$"
        ]
    ];

targetWolframVersion[paclet_?PacletObjectQ] := Module[
    {specification, match, number},

    specification = paclet["WolframVersion"];
    If[!StringQ[specification],
        Return[$VersionNumber, Module]
    ];

    match = StringCases[
        specification,
        RegularExpression["^[0-9]+(?:\\.[0-9]+)?"]
    ];
    If[match === {},
        Return[$VersionNumber, Module]
    ];

    number = Quiet[Check[ToExpression[First[match]], $Failed]];
    If[NumberQ[number], number, $VersionNumber]
];

successfulDocumentationBuildQ[result_] := MatchQ[
    result,
    Success[
        _String,
        data_?AssociationQ /;
            Lookup[data, "FailedFilesCount", 1] === 0 &&
            Lookup[data, "SuccessfulFilesCount", 0] > 0
    ]
];

buildModernSearchIndex[
    languageDirectory_String,
    pacletName_String
] := Module[
    {notebooks, searchRoot, indexVersion, result, queryResult, queryData},

    Needs["DocumentationSearch`"];
    If[!NameQ["DocumentationSearch`CreateDocumentationIndex"],
        Return[buildFailure[
            "UnsupportedDocumentationSearch",
            "DocumentationSearch`CreateDocumentationIndex is unavailable; cannot build the required SearchIndex."
        ], Module]
    ];

    notebooks = FileNames["*.nb", languageDirectory, Infinity];
    If[notebooks === {},
        Return[buildFailure[
            "MissingBuiltDocumentation",
            "No built documentation notebooks were available for SearchIndex generation.",
            <|"LanguageDirectory" -> languageDirectory|>
        ], Module]
    ];

    indexVersion = StringTrim[
        ToString[TextSearch`PackageScope`$CurrentVersion],
        "."
    ];
    If[!StringMatchQ[indexVersion, DigitCharacter ..],
        Return[buildFailure[
            "UnsupportedSearchIndexVersion",
            "The TextSearch index version was not a numeric string.",
            <|"IndexVersion" -> indexVersion|>
        ], Module]
    ];

    searchRoot = FileNameJoin[{languageDirectory, "SearchIndex"}];
    If[DirectoryQ[searchRoot],
        DeleteDirectory[searchRoot, DeleteContents -> True]
    ];
    CreateDirectory[searchRoot, CreateIntermediateDirectories -> True];

    result = Quiet[Check[
        Quiet[
            DocumentationSearch`CreateDocumentationIndex[
                notebooks,
                searchRoot,
                indexVersion,
                OverwriteTarget -> True
            ],
            {CreateSearchIndex::uf}
        ],
        $Failed
    ]];
    If[!MatchQ[result, _SearchIndexObject],
        Return[buildFailure[
            "SearchIndexBuildFailed",
            "DocumentationSearch did not return a SearchIndexObject.",
            <|"LanguageDirectory" -> languageDirectory, "Result" -> result|>
        ], Module]
    ];

    queryResult = Quiet[Check[TextSearch[result, pacletName], $Failed]];
    queryData = Quiet[Check[Normal[queryResult], $Failed]];
    If[
        !MatchQ[queryResult, _SearchResultObject] ||
            !ListQ[queryData] || queryData === {},
        Return[buildFailure[
            "SearchIndexValidationFailed",
            "The generated SearchIndex could not be queried or did not return the paclet documentation.",
            <|"LanguageDirectory" -> languageDirectory|>
        ], Module]
    ];

    Success["SearchIndexBuild", <|"SearchIndex" -> result|>]
];

BuildDocumentationForAllLanguages[
    pacletDirectory_String,
    buildPacletDirectory_String,
    paclet_?PacletObjectQ
] := Module[
    {
        sourceDocumentationDirectory,
        buildDocumentationDirectory,
        pacletToolsVersion,
        targetVersion,
        sourceNotebooks,
        builtNotebooks,
        result,
        searchResult
    },

    Needs["DocumentationBuild`"];
    If[!NameQ["DocumentationBuild`DocumentationBuildNotebooks"],
        Return[buildFailure[
            "UnsupportedDocumentationBuild",
            "DocumentationBuild`DocumentationBuildNotebooks is unavailable."
        ], Module]
    ];
    If[
        FreeQ[
            Options[DocumentationBuild`DocumentationBuildNotebooks],
            HoldPattern[Language -> _] | HoldPattern[Language :> _]
        ],
        Return[buildFailure[
            "UnsupportedDocumentationBuild",
            "DocumentationBuildNotebooks does not provide the required Language option."
        ], Module]
    ];

    pacletToolsVersion = Quiet[Check[
        PacletObject["PacletTools"]["Version"],
        Missing["NotAvailable"]
    ]];
    Print[
        "Building documentation explicitly for all languages ",
        $RequiredDocumentationLanguages,
        " (PacletTools ", pacletToolsVersion, ")."
    ];
    If[pacletToolsVersion === "14.0.1.0",
        Print[
            "Applying the PacletTools 14.0.1.0 workaround for the missing ",
            "Language propagation in PacletBuild."
        ]
    ];

    sourceDocumentationDirectory =
        FileNameJoin[{pacletDirectory, "Documentation"}];
    buildDocumentationDirectory =
        FileNameJoin[{buildPacletDirectory, "Documentation"}];
    If[!DirectoryQ[sourceDocumentationDirectory],
        Return[buildFailure[
            "MissingDocumentationDirectory",
            "The paclet source does not contain a Documentation directory."
        ], Module]
    ];

    CreateDirectory[
        buildDocumentationDirectory,
        CreateIntermediateDirectories -> True
    ];
    targetVersion = targetWolframVersion[paclet];

    Do[
        sourceNotebooks = FileNames[
            "*.nb",
            FileNameJoin[{sourceDocumentationDirectory, language}],
            Infinity
        ];
        If[sourceNotebooks === {},
            Return[buildFailure[
                "MissingDocumentationLanguage",
                "A required documentation language has no source notebooks.",
                <|"Language" -> language|>
            ], Module]
        ];

        result = DocumentationBuild`DocumentationBuildNotebooks[
            sourceDocumentationDirectory,
            buildDocumentationDirectory,
            Language -> language,
            "LinkBase" -> paclet["Name"],
            "ProgressDescription" ->
                "Building " <> language <> " documentation",
            "SuccessThreshold" -> 1.0,
            "TargetWolframVersionNumber" -> targetVersion
        ];
        If[!successfulDocumentationBuildQ[result],
            Return[buildFailure[
                "DocumentationBuildFailed",
                "A required documentation language did not build successfully.",
                <|"Language" -> language, "Result" -> result|>
            ], Module]
        ];

        builtNotebooks = FileNames[
            "*.nb",
            FileNameJoin[{buildDocumentationDirectory, language}],
            Infinity
        ];
        If[
            Sort[relativeTo[sourceDocumentationDirectory, #] & /@ sourceNotebooks] =!=
                Sort[relativeTo[buildDocumentationDirectory, #] & /@ builtNotebooks],
            Return[buildFailure[
                "IncompleteDocumentationBuild",
                "The built notebooks do not exactly match the source notebooks.",
                <|"Language" -> language|>
            ], Module]
        ];

        (* DocumentationBuild 14.0.1.0 intentionally skips the modern index for
           non-English documentation. Build it explicitly for every language so
           the archive has the same complete index layout in both languages. *)
        searchResult = buildModernSearchIndex[
            FileNameJoin[{buildDocumentationDirectory, language}],
            paclet["Name"]
        ];
        If[!MatchQ[searchResult, _Success],
            Return[searchResult, Module]
        ];
        ,
        {language, $RequiredDocumentationLanguages}
    ];

    Success[
        "DocumentationBuild",
        <|
            "Languages" -> $RequiredDocumentationLanguages,
            "TargetWolframVersionNumber" -> targetVersion
        |>
    ]
];

extensionOptions[extension_List] := Association[Rest[extension]];

matchingExtensions[extensions_List, name_String] := Select[
    extensions,
    ListQ[#] && Length[#] >= 1 && First[#] === name &&
        AllTrue[Rest[#], MatchQ[#, _Rule | _RuleDelayed] &] &
];

validatePacletContract[paclet_?PacletObjectQ] := Module[
    {
        name,
        version,
        wolframVersion,
        extensions,
        kernelExtensions,
        documentationExtensions,
        assetExtensions,
        options
    },

    name = paclet["Name"];
    version = paclet["Version"];
    wolframVersion = paclet["WolframVersion"];
    extensions = paclet["Extensions"];

    If[name =!= $ExpectedPacletName,
        Return[buildFailure[
            "UnexpectedPacletName",
            "The paclet name must be JuliaForm.",
            <|"Name" -> name|>
        ], Module]
    ];
    If[!canonicalVersionQ[version],
        Return[buildFailure[
            "InvalidPacletVersion",
            "The paclet version must be canonical MAJOR.MINOR.PATCH SemVer without leading zeros.",
            <|"Version" -> version|>
        ], Module]
    ];
    If[wolframVersion =!= $ExpectedWolframVersion,
        Return[buildFailure[
            "UnexpectedWolframVersion",
            "The paclet must target Wolfram Language 15.0+.",
            <|"WolframVersion" -> wolframVersion|>
        ], Module]
    ];
    If[!ListQ[extensions] || Length[extensions] =!= 3,
        Return[buildFailure[
            "InvalidPacletExtensions",
            "The paclet must declare exactly the Kernel, Documentation, and Asset extensions."
        ], Module]
    ];

    kernelExtensions = matchingExtensions[extensions, "Kernel"];
    If[Length[kernelExtensions] =!= 1,
        Return[buildFailure[
            "InvalidKernelExtension",
            "The paclet must contain exactly one Kernel extension."
        ], Module]
    ];
    options = extensionOptions[First[kernelExtensions]];
    If[
        Length[First[kernelExtensions]] =!= 3 ||
            options =!= <|"Root" -> "Kernel", "Context" -> "JuliaForm`"|>,
        Return[buildFailure[
            "InvalidKernelExtension",
            "The Kernel extension must contain only Root Kernel and Context JuliaForm`."
        ], Module]
    ];

    documentationExtensions =
        matchingExtensions[extensions, "Documentation"];
    If[Length[documentationExtensions] =!= 1,
        Return[buildFailure[
            "InvalidDocumentationExtension",
            "The paclet must contain exactly one Documentation extension."
        ], Module]
    ];
    options = extensionOptions[First[documentationExtensions]];
    If[
        Length[First[documentationExtensions]] =!= 2 ||
            options =!= <|Language -> All|>,
        Return[buildFailure[
            "InvalidDocumentationExtension",
            "The Documentation extension must contain only Language -> All."
        ], Module]
    ];

    assetExtensions = matchingExtensions[extensions, "Asset"];
    If[Length[assetExtensions] =!= 1,
        Return[buildFailure[
            "InvalidAssetExtension",
            "The paclet must contain exactly one Asset extension."
        ], Module]
    ];
    options = extensionOptions[First[assetExtensions]];
    If[
        Length[First[assetExtensions]] =!= 2 ||
            options =!= <|"Assets" -> {{"License", "LICENSE"}}|>,
        Return[buildFailure[
            "InvalidAssetExtension",
            "The Asset extension must expose only the top-level LICENSE file."
        ], Module]
    ];

    Success[
        "PacletContractValidation",
        <|"Name" -> name, "Version" -> version|>
    ]
];

validateClassicDocumentationIndex[
    indexDirectory_String,
    language_String,
    indexName_String
] := Module[{entries, files, names, allowedNames},
    If[!DirectoryQ[indexDirectory],
        Return[buildFailure[
            "MissingDocumentationIndex",
            "A required documentation index is missing.",
            <|"Language" -> language, "Index" -> indexName|>
        ], Module]
    ];

    entries = FileNames[All, indexDirectory, 1];
    files = Select[entries, FileType[#] === File &];
    If[Length[entries] =!= Length[files] || files === {},
        Return[buildFailure[
            "InvalidDocumentationIndex",
            "A classic documentation index must contain only its expected files.",
            <|"Language" -> language, "Index" -> indexName|>
        ], Module]
    ];

    names = FileNameTake /@ files;
    allowedNames = AllTrue[
        names,
        # === "segments.gen" ||
            StringMatchQ[#, RegularExpression["segments_[0-9]+"]] ||
            StringMatchQ[#, RegularExpression[".+\\.cfs"]] &
    ];
    If[
        !allowedNames ||
            Count[names, "segments.gen"] =!= 1 ||
            Count[names, _?(StringMatchQ[#, RegularExpression["segments_[0-9]+"]] &)] < 1 ||
            Count[names, _?(StringMatchQ[#, RegularExpression[".+\\.cfs"]] &)] < 1 ||
            !AllTrue[files, nonEmptyFileQ],
        Return[buildFailure[
            "InvalidDocumentationIndex",
            "A classic documentation index has an incomplete or invalid file set.",
            <|"Language" -> language, "Index" -> indexName|>
        ], Module]
    ];

    Success[
        "ClassicDocumentationIndexValidation",
        <|"Language" -> language, "Index" -> indexName|>
    ]
];

validateSearchDocumentationIndex[
    indexDirectory_String,
    language_String
] := Module[
    {
        entries,
        versionDirectories,
        versionDirectory,
        version,
        files,
        names,
        requiredNames,
        allowedNames,
        metadata,
        searchIndex
    },

    If[!DirectoryQ[indexDirectory],
        Return[buildFailure[
            "MissingDocumentationIndex",
            "The SearchIndex directory is missing.",
            <|"Language" -> language, "Index" -> "SearchIndex"|>
        ], Module]
    ];

    entries = FileNames[All, indexDirectory, 1];
    versionDirectories = Select[entries, DirectoryQ];
    If[
        Length[entries] =!= 1 || Length[versionDirectories] =!= 1 ||
            !StringMatchQ[FileNameTake[First[versionDirectories]], DigitCharacter ..],
        Return[buildFailure[
            "InvalidDocumentationIndex",
            "SearchIndex must contain exactly one numeric version directory.",
            <|"Language" -> language, "Index" -> "SearchIndex"|>
        ], Module]
    ];

    versionDirectory = First[versionDirectories];
    version = FromDigits[FileNameTake[versionDirectory]];
    entries = FileNames[All, versionDirectory, 1];
    files = Select[entries, FileType[#] === File &];
    If[Length[entries] =!= Length[files] || files === {},
        Return[buildFailure[
            "InvalidDocumentationIndex",
            "SearchIndex contains a nested directory or no files.",
            <|"Language" -> language, "Index" -> "SearchIndex"|>
        ], Module]
    ];

    names = FileNameTake /@ files;
    requiredNames = {"fields.wl", "indexMetadata.wl"};
    allowedNames = AllTrue[
        names,
        MemberQ[Join[requiredNames, {"write.lock"}], #] ||
            StringMatchQ[#, RegularExpression[".+\\.(cfe|cfs|si)"]] ||
            StringMatchQ[#, RegularExpression["segments_[0-9]+"]] &
    ];
    If[
        !allowedNames || !ContainsAll[names, requiredNames] ||
            Count[names, _?(StringMatchQ[#, RegularExpression[".+\\.cfe"]] &)] < 1 ||
            Count[names, _?(StringMatchQ[#, RegularExpression[".+\\.cfs"]] &)] < 1 ||
            Count[names, _?(StringMatchQ[#, RegularExpression[".+\\.si"]] &)] < 1 ||
            Count[names, _?(StringMatchQ[#, RegularExpression["segments_[0-9]+"]] &)] < 1 ||
            !AllTrue[
                Select[files, FileNameTake[#] =!= "write.lock" &],
                nonEmptyFileQ
            ],
        Return[buildFailure[
            "InvalidDocumentationIndex",
            "SearchIndex has an incomplete or invalid file set.",
            <|"Language" -> language, "Index" -> "SearchIndex"|>
        ], Module]
    ];

    metadata = Quiet[Check[
        Get[FileNameJoin[{versionDirectory, "indexMetadata.wl"}]],
        $Failed
    ]];
    If[
        !AssociationQ[metadata] || Lookup[metadata, "Version", Missing[]] =!= version,
        Return[buildFailure[
            "InvalidDocumentationIndex",
            "SearchIndex metadata is missing or has the wrong version.",
            <|"Language" -> language, "Index" -> "SearchIndex"|>
        ], Module]
    ];

    Needs["DocumentationSearch`"];
    searchIndex = SearchIndexObject[File[versionDirectory]];
    If[
        !NameQ["TextSearch`ValidSearchIndexObjectQ"] ||
            !TrueQ[TextSearch`ValidSearchIndexObjectQ[searchIndex]],
        Return[buildFailure[
            "InvalidDocumentationIndex",
            "SearchIndex cannot be opened as a valid search index.",
            <|"Language" -> language, "Index" -> "SearchIndex"|>
        ], Module]
    ];

    Success[
        "SearchDocumentationIndexValidation",
        <|"Language" -> language, "Version" -> version|>
    ]
];

CreatePacletIntegrityInventory[pacletRoot_String] := Module[
    {inventoryPath, deleteResult, files, entries, inventory, exportResult},

    If[!DirectoryQ[pacletRoot],
        Return[buildFailure[
            "MissingPacletDirectory",
            "The paclet directory does not exist.",
            <|"PacletRoot" -> pacletRoot|>
        ], Module]
    ];

    inventoryPath = FileNameJoin[{pacletRoot, $IntegrityInventoryFileName}];
    If[FileExistsQ[inventoryPath],
        deleteResult = Quiet[Check[DeleteFile[inventoryPath], $Failed]];
        If[deleteResult === $Failed || FileExistsQ[inventoryPath],
            Return[buildFailure[
                "IntegrityInventoryWriteFailed",
                "The previous integrity inventory could not be removed."
            ], Module]
        ]
    ];

    files = SortBy[filesBelow[pacletRoot], canonicalRelativeTo[pacletRoot, #] &];
    entries = Function[file,
        <|
            "File" -> File[canonicalRelativeTo[pacletRoot, file]],
            "ByteCount" -> FileByteCount[file],
            "Hash" -> FileHash[file, "SHA256", "HexString"]
        |>
    ] /@ files;
    If[
        !AllTrue[
            entries,
            IntegerQ[#["ByteCount"]] && #["ByteCount"] >= 0 &&
                StringQ[#["Hash"]] &&
                StringMatchQ[#["Hash"], RegularExpression["[0-9a-f]{64}"]] &
        ],
        Return[buildFailure[
            "IntegrityInventoryWriteFailed",
            "A package file could not be sized or hashed for the integrity inventory."
        ], Module]
    ];
    (* A file cannot contain its own SHA-256. The inventory records every
       other regular file, while archive validation requires this exact,
       single exclusion and rejects any unlisted file. *)
    inventory = <|
        "FormatVersion" -> 1,
        "HashAlgorithm" -> "SHA256",
        "ExcludedFiles" -> {File[$IntegrityInventoryFileName]},
        "Files" -> entries
    |>;

    exportResult = Quiet[Check[
        Export[inventoryPath, ToString[InputForm[inventory]], "String"],
        $Failed
    ]];
    If[
        exportResult === $Failed || !nonEmptyFileQ[inventoryPath],
        Return[buildFailure[
            "IntegrityInventoryWriteFailed",
            "The independent package integrity inventory could not be written."
        ], Module]
    ];

    Success[
        "PacletIntegrityInventory",
        <|"File" -> inventoryPath, "FilesCount" -> Length[entries]|>
    ]
];

validateIntegrityInventory[pacletRoot_String] := Module[
    {
        inventoryPath,
        inventory,
        entries,
        paths,
        resolvedPaths,
        byteCounts,
        hashes,
        actualPaths,
        actualByteCounts,
        actualHashes
    },

    inventoryPath = FileNameJoin[{pacletRoot, $IntegrityInventoryFileName}];
    If[!nonEmptyFileQ[inventoryPath],
        Return[buildFailure[
            "MissingIntegrityInventory",
            "The independent package integrity inventory is missing or empty."
        ], Module]
    ];

    inventory = Quiet[Check[Get[inventoryPath], $Failed]];
    If[
        !AssociationQ[inventory] ||
            Lookup[inventory, "FormatVersion", Missing[]] =!= 1 ||
            Lookup[inventory, "HashAlgorithm", Missing[]] =!= "SHA256" ||
            Lookup[inventory, "ExcludedFiles", Missing[]] =!=
                {File[$IntegrityInventoryFileName]},
        Return[buildFailure[
            "InvalidIntegrityInventory",
            "The independent package integrity inventory has an invalid header."
        ], Module]
    ];

    entries = Lookup[inventory, "Files", Missing["NotAvailable"]];
    If[!ListQ[entries] || entries === {} || !AllTrue[entries, AssociationQ],
        Return[buildFailure[
            "InvalidIntegrityInventory",
            "The independent package integrity inventory has no valid file list."
        ], Module]
    ];

    paths = canonicalFileEntries[entries];
    byteCounts = Lookup[entries, "ByteCount", Missing["NotAvailable"]];
    hashes = Lookup[entries, "Hash", Missing["NotAvailable"]];
    If[
        paths === $Failed ||
            !AllTrue[byteCounts, IntegerQ[#] && # >= 0 &] ||
            !AllTrue[
                hashes,
                StringQ[#] && StringMatchQ[#, RegularExpression["[0-9a-f]{64}"]] &
            ],
        Return[buildFailure[
            "InvalidIntegrityInventory",
            "The independent package integrity inventory contains an invalid path, size, or hash."
        ], Module]
    ];

    resolvedPaths = containedFilePath[pacletRoot, #] & /@ paths;
    If[MemberQ[resolvedPaths, $Failed] || !AllTrue[resolvedPaths, FileExistsQ],
        Return[buildFailure[
            "InvalidIntegrityInventory",
            "The independent package integrity inventory references an absent or escaping file."
        ], Module]
    ];

    actualPaths = Sort[
        canonicalRelativeTo[pacletRoot, #] & /@
            Select[
                filesBelow[pacletRoot],
                canonicalRelativeTo[pacletRoot, #] =!=
                    $IntegrityInventoryFileName &
            ]
    ];
    If[Sort[paths] =!= actualPaths,
        Return[buildFailure[
            "IntegrityInventoryFileSetMismatch",
            "The archive file set does not exactly match the independent integrity inventory.",
            <|
                "Missing" -> Complement[paths, actualPaths],
                "Unexpected" -> Complement[actualPaths, paths]
            |>
        ], Module]
    ];

    actualByteCounts = FileByteCount /@ resolvedPaths;
    actualHashes = FileHash[#, "SHA256", "HexString"] & /@ resolvedPaths;
    If[actualByteCounts =!= byteCounts || actualHashes =!= hashes,
        Return[buildFailure[
            "IntegrityInventoryHashMismatch",
            "A packaged file does not match its independent size or SHA-256 record."
        ], Module]
    ];

    Success[
        "PacletIntegrityInventoryValidation",
        <|"Files" -> paths|>
    ]
];

validateManifest[pacletRoot_String] := Module[
    {
        manifestPath,
        manifest,
        entries,
        paths,
        resolvedPaths,
        hashes,
        actualHashes,
        requiredPaths
    },

    manifestPath = FileNameJoin[{pacletRoot, "PacletManifest.wl"}];
    If[!FileExistsQ[manifestPath],
        Return[buildFailure[
            "MissingPacletManifest",
            "PacletManifest.wl is missing."
        ], Module]
    ];

    manifest = Quiet[Check[Get[manifestPath], $Failed]];
    If[
        manifest === $Failed || !AssociationQ[manifest] ||
            !FreeQ[manifest, _Failure] || !FreeQ[manifest, $Failed],
        Return[buildFailure[
            "InvalidPacletManifest",
            "PacletManifest.wl is invalid or contains $Failed/Failure."
        ], Module]
    ];

    entries = Lookup[manifest, "Files", Missing["NotAvailable"]];
    If[!ListQ[entries] || entries === {} || !AllTrue[entries, AssociationQ],
        Return[buildFailure[
            "InvalidPacletManifest",
            "PacletManifest.wl does not contain a non-empty file list."
        ], Module]
    ];

    paths = canonicalFileEntries[entries];
    hashes = Lookup[entries, "Hash", Missing["NotAvailable"]];
    If[paths === $Failed || !AllTrue[
            hashes,
            StringQ[#] && StringMatchQ[#, RegularExpression["[0-9a-f]{64}"]] &
        ],
        Return[buildFailure[
            "InvalidPacletManifest",
            "PacletManifest.wl contains a non-canonical, escaping, duplicate file path or an invalid SHA-256 hash."
        ], Module]
    ];

    resolvedPaths = containedFilePath[pacletRoot, #] & /@ paths;
    If[
        MemberQ[resolvedPaths, $Failed] ||
            !AllTrue[resolvedPaths, FileExistsQ],
        Return[buildFailure[
            "InvalidPacletManifest",
            "PacletManifest.wl references a file that is absent from or outside the paclet."
        ], Module]
    ];

    actualHashes = FileHash[
        #,
        "SHA256",
        "HexString"
    ] & /@ resolvedPaths;
    If[actualHashes =!= hashes,
        Return[buildFailure[
            "InvalidPacletManifest",
            "A manifest SHA-256 hash does not match the packaged file."
        ], Module]
    ];

    requiredPaths = Join[
        $ExpectedKernelFiles,
        {"LICENSE"},
        (
            "Documentation/" <> # <>
                "/ReferencePages/Symbols/JuliaForm.nb"
        ) & /@ $RequiredDocumentationLanguages
    ];
    If[!ContainsAll[paths, requiredPaths],
        Return[buildFailure[
            "IncompletePacletManifest",
            "PacletManifest.wl omits a required kernel, license, or documentation source file.",
            <|"Missing" -> Complement[requiredPaths, paths]|>
        ], Module]
    ];

    Success["PacletManifestValidation", <|"Files" -> paths|>]
];

ValidatePacletBuildDirectory[pacletRoot_String] := Module[
    {
        pacletInfoPath,
        licensePath,
        paclet,
        contractResult,
        kernelFiles,
        requiredFile,
        languageDirectory,
        notebooks,
        indexDirectory,
        indexResult,
        manifestResult,
        inventoryResult
    },

    If[!DirectoryQ[pacletRoot],
        Return[buildFailure[
            "MissingPacletDirectory",
            "The unpacked paclet directory does not exist.",
            <|"PacletRoot" -> pacletRoot|>
        ], Module]
    ];

    pacletInfoPath = FileNameJoin[{pacletRoot, "PacletInfo.wl"}];
    paclet = Quiet[Check[Get[pacletInfoPath], $Failed]];
    If[!MatchQ[paclet, _PacletObject],
        Return[buildFailure[
            "InvalidPacletInfo",
            "PacletInfo.wl is missing or invalid."
        ], Module]
    ];

    contractResult = validatePacletContract[paclet];
    If[!MatchQ[contractResult, _Success],
        Return[contractResult, Module]
    ];

    kernelFiles = Sort[
        canonicalRelativeTo[pacletRoot, #] & /@
            filesBelow[FileNameJoin[{pacletRoot, "Kernel"}]]
    ];
    If[kernelFiles =!= Sort[$ExpectedKernelFiles],
        Return[buildFailure[
            "UnexpectedKernelFileSet",
            "The built paclet Kernel directory must contain exactly the declared loader and implementation files.",
            <|
                "Missing" -> Complement[$ExpectedKernelFiles, kernelFiles],
                "Unexpected" -> Complement[kernelFiles, $ExpectedKernelFiles]
            |>
        ], Module]
    ];

    Do[
        requiredFile = containedFilePath[pacletRoot, relativePath];
        If[!StringQ[requiredFile] || !nonEmptyFileQ[requiredFile],
            Return[buildFailure[
                "MissingKernelFile",
                "The built paclet is missing a required non-empty kernel file.",
                <|"File" -> relativePath|>
            ], Module]
        ];
        ,
        {relativePath, $ExpectedKernelFiles}
    ];

    licensePath = FileNameJoin[{pacletRoot, "LICENSE"}];
    If[!nonEmptyFileQ[licensePath],
        Return[buildFailure[
            "MissingLicense",
            "The built paclet must contain a non-empty top-level LICENSE file."
        ], Module]
    ];

    Do[
        languageDirectory =
            FileNameJoin[{pacletRoot, "Documentation", language}];
        notebooks = FileNames[
            "JuliaForm.nb",
            FileNameJoin[{languageDirectory, "ReferencePages", "Symbols"}],
            1
        ];
        If[Length[notebooks] =!= 1 || !nonEmptyFileQ[First[notebooks]],
            Return[buildFailure[
                "MissingDocumentationLanguage",
                "The built paclet is missing a required documentation language.",
                <|"Language" -> language|>
            ], Module]
        ];

        Do[
            indexDirectory = FileNameJoin[{languageDirectory, indexName}];
            indexResult = If[
                indexName === "SearchIndex",
                validateSearchDocumentationIndex[indexDirectory, language],
                validateClassicDocumentationIndex[
                    indexDirectory,
                    language,
                    indexName
                ]
            ];
            If[!MatchQ[indexResult, _Success],
                Return[indexResult, Module]
            ];
            ,
            {indexName, {"Index", "SearchIndex", "SpellIndex"}}
        ];
        ,
        {language, $RequiredDocumentationLanguages}
    ];

    manifestResult = validateManifest[pacletRoot];
    If[!MatchQ[manifestResult, _Success],
        Return[manifestResult, Module]
    ];

    inventoryResult = validateIntegrityInventory[pacletRoot];
    If[!MatchQ[inventoryResult, _Success],
        Return[inventoryResult, Module]
    ];

    Success[
        "PacletBuildDirectoryValidation",
        <|
            "Paclet" -> paclet,
            "Name" -> paclet["Name"],
            "Version" -> paclet["Version"],
            "Languages" -> $RequiredDocumentationLanguages
        |>
    ]
];

ValidatePacletArchive[archive_String] := Module[
    {
        temporaryDirectory,
        extractionResult,
        topLevelEntries,
        pacletRoots,
        pacletRoot,
        paclet,
        expectedBaseName,
        result
    },

    If[!FileExistsQ[archive],
        Return[buildFailure[
            "MissingPacletArchive",
            "The paclet archive does not exist.",
            <|"Archive" -> archive|>
        ], Module]
    ];

    temporaryDirectory = CreateDirectory[
        FileNameJoin[{
            $TemporaryDirectory,
            "JuliaForm-paclet-validation-" <> CreateUUID[]
        }]
    ];

    result = Internal`WithLocalSettings[
        Null,
        extractionResult = Quiet[Check[
            ExtractArchive[archive, temporaryDirectory],
            $Failed
        ]];
        If[extractionResult === $Failed,
            buildFailure[
                "InvalidPacletArchive",
                "The paclet archive could not be extracted.",
                <|"Archive" -> archive|>
            ],
            topLevelEntries = FileNames[All, temporaryDirectory, 1];
            pacletRoots = Select[topLevelEntries, DirectoryQ];
            If[
                Length[pacletRoots] =!= 1 ||
                    Length[topLevelEntries] =!= 1,
                buildFailure[
                    "InvalidPacletArchive",
                    "The paclet archive must contain exactly one top-level directory."
                ],
                pacletRoot = First[pacletRoots];
                result = ValidatePacletBuildDirectory[pacletRoot];
                If[!MatchQ[result, _Success],
                    result,
                    paclet = result["Paclet"];
                    expectedBaseName =
                        paclet["Name"] <> "-" <> paclet["Version"];
                    If[
                        FileNameTake[pacletRoot] =!= expectedBaseName ||
                            FileNameTake[archive] =!=
                                expectedBaseName <> ".paclet",
                        buildFailure[
                            "InvalidPacletArchiveName",
                            "A local-build or stable-release archive file and its top-level directory must match Name-Version; rolling dev assets are publication-layer aliases and are not canonical validator inputs.",
                            <|
                                "Expected" -> expectedBaseName,
                                "Archive" -> FileNameTake[archive],
                                "Root" -> FileNameTake[pacletRoot]
                            |>
                        ],
                        result
                    ]
                ]
            ]
        ],
        If[DirectoryQ[temporaryDirectory],
            DeleteDirectory[temporaryDirectory, DeleteContents -> True]
        ]
    ];

    result
];

End[];
EndPackage[];
