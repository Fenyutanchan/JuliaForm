#!/usr/bin/env wolframscript

$CharacterEncoding = "UTF-8";

scriptDirectory = DirectoryName[ExpandFileName[$InputFileName]];
pacletDirectory = DirectoryName[scriptDirectory];
outputDirectory = FileNameJoin[{pacletDirectory, "dist"}];
supportFile = FileNameJoin[{scriptDirectory, "PacletBuildSupport.wl"}];

Needs["PacletTools`"];
Needs["PacletTools`Utils`"];
supportLoadResult = Quiet[Check[Get[supportFile], $Failed]];
requiredSupportFunctions = {
    JuliaFormBuildSupport`BuildDocumentationForAllLanguages,
    JuliaFormBuildSupport`CreatePacletIntegrityInventory,
    JuliaFormBuildSupport`ValidatePacletBuildDirectory,
    JuliaFormBuildSupport`ValidatePacletArchive
};
If[
    supportLoadResult === $Failed ||
        !AllTrue[requiredSupportFunctions, Length[DownValues[#]] > 0 &] ||
        !ListQ[JuliaFormBuildSupport`$RequiredDocumentationLanguages] ||
        !StringQ[JuliaFormBuildSupport`$IntegrityInventoryFileName],
    Print["Paclet build support failed to load completely from ", supportFile];
    Exit[1]
];

paclet = Quiet[Check[
    Get[FileNameJoin[{pacletDirectory, "PacletInfo.wl"}]],
    $Failed
]];
If[!MatchQ[paclet, _PacletObject],
    Print["PacletInfo.wl is missing or invalid: ", paclet];
    Exit[1]
];

(* dist is an ignored, build-only directory. Removing it prevents a stale
   language tree or archive from turning an incomplete build into a success. *)
If[DirectoryQ[outputDirectory],
    DeleteDirectory[outputDirectory, DeleteContents -> True]
];
CreateDirectory[outputDirectory, CreateIntermediateDirectories -> True];

buildPacletDirectory = FileNameJoin[{
    outputDirectory,
    PacletTools`Utils`MakePacletDirectoryName[paclet]
}];
documentationResult =
    JuliaFormBuildSupport`BuildDocumentationForAllLanguages[
        pacletDirectory,
        buildPacletDirectory,
        paclet
    ];
If[!MatchQ[documentationResult, _Success],
    Print["Documentation build failed: ", documentationResult];
    Exit[1]
];

Print["Building paclet from ", pacletDirectory, " into ", outputDirectory];
result = PacletTools`PacletBuild[pacletDirectory, outputDirectory];
If[!MatchQ[result, _Success],
    Print["PacletBuild failed: ", result];
    Exit[1]
];

archive = Replace[result["PacletArchive"], File[path_] :> path];
If[!StringQ[archive] || !FileExistsQ[archive],
    Print["PacletBuild did not create an archive: ", archive];
    Exit[1]
];

(* PacletManifest.wl intentionally covers extension source files, but not the
   generated documentation indexes or PacletInfo.wl. Record every completed
   build file in a separate inventory, excluding only that inventory itself,
   and recreate the archive so the inventory is shipped with the paclet. *)
inventoryResult =
    JuliaFormBuildSupport`CreatePacletIntegrityInventory[
        buildPacletDirectory
    ];
If[!MatchQ[inventoryResult, _Success],
    Print["Paclet integrity inventory creation failed: ", inventoryResult];
    Exit[1]
];

buildValidation =
    JuliaFormBuildSupport`ValidatePacletBuildDirectory[buildPacletDirectory];
If[!MatchQ[buildValidation, _Success],
    Print["Built paclet directory validation failed: ", buildValidation];
    Exit[1]
];

deleteResult = Quiet[Check[DeleteFile[archive], $Failed]];
If[deleteResult === $Failed || FileExistsQ[archive],
    Print["Could not replace the initial archive with the inventoried archive: ", archive];
    Exit[1]
];
repackedArchive = Quiet[Check[
    CreatePacletArchive[buildPacletDirectory, outputDirectory],
    $Failed
]];
If[
    !StringQ[repackedArchive] || !FileExistsQ[repackedArchive] ||
        ExpandFileName[repackedArchive] =!= ExpandFileName[archive],
    Print[
        "CreatePacletArchive did not recreate the expected inventoried archive: ",
        repackedArchive
    ];
    Exit[1]
];
archive = repackedArchive;

archives = FileNames["*.paclet", outputDirectory];
If[archives =!= {archive},
    Print[
        "Expected exactly one paclet archive and for it to match PacletBuild output: ",
        archives
    ];
    Exit[1]
];

archiveValidation = JuliaFormBuildSupport`ValidatePacletArchive[archive];
If[!MatchQ[archiveValidation, _Success],
    Print["Paclet archive validation failed: ", archiveValidation];
    Exit[1]
];

Print["Built ", archive];
Print[
    "Validated documentation languages and indexes: ",
    JuliaFormBuildSupport`$RequiredDocumentationLanguages
];
