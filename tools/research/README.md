# Static interface research tools

These original Python tools inspect a user-supplied Windows package and matching debug symbols as **data**. They do not load or run the Windows application, install anything, or change GPU settings. They are development aids, not part of the installed Redline runtime.

Recovered source, assembly and binary resources must remain outside public release inputs. Use an ignored `.research-private/` directory. The AMD package, its PDBs, recovered QML, icon/font assets and generated raw inventories are not included in this repository.

The parsers support the formats observed in the supplied package: x64 PE, MSF 7.00/CodeView PDB and Qt resource/metaobject revision 3/13. They are experimental parsers with explicit format/bounds checks, not general validators for arbitrary hostile files. No complete semantic decompilation is claimed.

Tools:

- `index-amd-pe.py`: all executable-image import/export metadata from an MSIX.
- `analyze-amd-pdb.py`: PDB/executable GUID+age matching and selected symbol records.
- `recover-amd-qt-resources.py`: the embedded resource arrays located by matching symbol metadata, with per-payload hashes and reconstructed data-only RCC files.
- `index-amd-qml.py`: lexical object, navigation, label and candidate backend-member inventories. It does not evaluate bindings or produce a complete QML/JavaScript AST.
- `index-amd-native-models.py`: PDB native type enums and named model members.
- `index-amd-metaobjects.py`: Qt class/property/method/enum declarations; no target metacalls or getters.
- `index-amd-procedures.py`: procedure names, module boundaries and exact code extents.
- `trace-amd-native-calls.py`: bounded disassembly of selected procedures using `objdump`, with direct/import call candidates. Virtual/indirect targets and runtime state remain unresolved.

Every Python command accepts `--help`. The first-stage symbol identity must match before interpreting resource metadata. The Qt resource decoder validates the observed paired resource-array layout; do not assume another application uses the same organization. For shared compiler entrypoints, the call tracer records the alternate procedure name explicitly rather than inventing a recovered function body.
