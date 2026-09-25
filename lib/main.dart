import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import 'database/database_helper.dart';
import 'firebase_options.dart';
import 'models/note.dart';
import 'services/firestore_service.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await Firebase.initializeApp(
    options:
        DefaultFirebaseOptions.currentPlatform,
  );

  runApp(
    const StudentNotesApp(),
  );
}

// ============================================================
// APP
// ============================================================

class StudentNotesApp
    extends StatelessWidget {
  const StudentNotesApp({
    super.key,
  });

  @override
  Widget build(
    BuildContext context,
  ) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'Student Notes',
      theme: ThemeData(
        useMaterial3: true,
        colorScheme:
            ColorScheme.fromSeed(
          seedColor: Colors.indigo,
        ),
        scaffoldBackgroundColor:
            const Color(0xFFF6F7FB),
      ),
      home:
          const NotesHomePage(),
    );
  }
}

// ============================================================
// HOME PAGE
// ============================================================

class NotesHomePage
    extends StatefulWidget {
  const NotesHomePage({
    super.key,
  });

  @override
  State<NotesHomePage> createState() =>
      _NotesHomePageState();
}

class _NotesHomePageState
    extends State<NotesHomePage> {
  final DatabaseHelper _database =
      DatabaseHelper.instance;

  final FirestoreService _firestore =
      FirestoreService();

  List<Note> notes = [];

  bool isLoading = true;
  bool isSyncing = false;

  @override
  void initState() {
    super.initState();

    _initialize();
  }

  // ==========================================================
  // INITIALIZE
  // ==========================================================

  Future<void> _initialize() async {
    await _loadLocalNotes();

    // Attempt cloud sync after
    // showing local data.
    await _sync(
      showMessage: false,
    );
  }

  // ==========================================================
  // LOAD LOCAL NOTES
  // ==========================================================

  Future<void> _loadLocalNotes() async {
    try {
      final rows =
          await _database.getNotes();

      final loadedNotes = rows
          .map(
            (row) =>
                Note.fromMap(row),
          )
          .toList();

      if (!mounted) {
        return;
      }

      setState(() {
        notes = loadedNotes;
        isLoading = false;
      });
    } catch (e) {
      debugPrint(
        'SQLITE LOAD ERROR: $e',
      );

      if (!mounted) {
        return;
      }

      setState(() {
        isLoading = false;
      });

      _showMessage(
        'Could not load local notes.',
      );
    }
  }

  // ==========================================================
  // ADD NOTE
  // ==========================================================

  Future<void> _createNote(
    String title,
    String content,
  ) async {
    try {
      final id =
          await _database.createNote(
        title: title,
        content: content,
      );

      await _loadLocalNotes();

      final note =
          notes.firstWhere(
        (item) => item.id == id,
      );

      try {
        await _firestore
            .uploadNote(note)
            .timeout(
          const Duration(
            seconds: 15,
          ),
        );

        _showMessage(
          'Note saved and synced.',
        );
      } catch (e) {
        debugPrint(
          'FIREBASE CREATE ERROR: $e',
        );

        _showMessage(
          'Note saved locally. Firebase sync failed.',
        );
      }
    } catch (e) {
      debugPrint(
        'CREATE ERROR: $e',
      );

      _showMessage(
        'Failed to create note.',
      );
    }
  }

  // ==========================================================
  // UPDATE NOTE
  // ==========================================================

  Future<void> _updateNote(
    Note oldNote,
    String title,
    String content,
  ) async {
    if (oldNote.id == null) {
      return;
    }

    try {
      await _database.updateNote(
        id: oldNote.id!,
        title: title,
        content: content,
      );

      await _loadLocalNotes();

      final updatedNote =
          notes.firstWhere(
        (note) =>
            note.id == oldNote.id,
      );

      try {
        await _firestore
            .uploadNote(updatedNote)
            .timeout(
          const Duration(
            seconds: 15,
          ),
        );

        _showMessage(
          'Note updated and synced.',
        );
      } catch (e) {
        debugPrint(
          'FIREBASE UPDATE ERROR: $e',
        );

        _showMessage(
          'Updated locally. Firebase sync failed.',
        );
      }
    } catch (e) {
      debugPrint(
        'UPDATE ERROR: $e',
      );

      _showMessage(
        'Failed to update note.',
      );
    }
  }

  // ==========================================================
  // DELETE NOTE
  // ==========================================================

  Future<void> _deleteNote(
    Note note,
  ) async {
    if (note.id == null) {
      return;
    }

    try {
      await _database.deleteNote(
        note.id!,
      );

      setState(() {
        notes.removeWhere(
          (item) =>
              item.id == note.id,
        );
      });

      try {
        await _firestore
            .deleteNote(note.id!)
            .timeout(
          const Duration(
            seconds: 15,
          ),
        );

        _showMessage(
          'Note deleted.',
        );
      } catch (e) {
        debugPrint(
          'FIREBASE DELETE ERROR: $e',
        );

        _showMessage(
          'Deleted locally. Firebase deletion failed.',
        );
      }
    } catch (e) {
      debugPrint(
        'DELETE ERROR: $e',
      );

      _showMessage(
        'Failed to delete note.',
      );
    }
  }

  // ==========================================================
  // SYNC
  // ==========================================================

  Future<void> _sync({
    bool showMessage = true,
  }) async {
    if (isSyncing) {
      return;
    }

    setState(() {
      isSyncing = true;
    });

    debugPrint(
      '========================================',
    );

    debugPrint(
      'SYNC: START',
    );

    try {
      // ------------------------------------------------------
      // STEP 1
      // Read SQLite
      // ------------------------------------------------------

      final localRows =
          await _database.getNotes();

      final localNotes = localRows
          .map(
            (row) =>
                Note.fromMap(row),
          )
          .toList();

      debugPrint(
        'SYNC: Local notes = ${localNotes.length}',
      );

      // ------------------------------------------------------
      // STEP 2
      // Upload SQLite → Firestore
      // ------------------------------------------------------

      debugPrint(
        'SYNC: Uploading local notes...',
      );

      await _firestore
          .uploadNotes(localNotes)
          .timeout(
        const Duration(
          seconds: 15,
        ),
      );

      debugPrint(
        'SYNC: Upload successful',
      );

      // ------------------------------------------------------
      // STEP 3
      // Download Firestore
      // ------------------------------------------------------

      debugPrint(
        'SYNC: Downloading cloud notes...',
      );

      final cloudNotes =
          await _firestore
              .downloadNotes()
              .timeout(
            const Duration(
              seconds: 15,
            ),
          );

      debugPrint(
        'SYNC: Cloud notes = ${cloudNotes.length}',
      );

      // ------------------------------------------------------
      // STEP 4
      // Merge Cloud → SQLite
      // ------------------------------------------------------

      for (final cloudNote
          in cloudNotes) {
        if (cloudNote.id == null) {
          continue;
        }

        final matchingLocal =
            localNotes.where(
          (localNote) =>
              localNote.id ==
              cloudNote.id,
        );

        if (matchingLocal.isEmpty) {
          debugPrint(
            'SYNC: Adding cloud note ${cloudNote.id} to SQLite',
          );

          await _database
              .insertOrReplaceNote(
            cloudNote.toMap(),
          );

          continue;
        }

        final localNote =
            matchingLocal.first;

        // Newest version wins.
        if (cloudNote.updatedAt
            .isAfter(
          localNote.updatedAt,
        )) {
          debugPrint(
            'SYNC: Cloud version newer for ${cloudNote.id}',
          );

          await _database
              .insertOrReplaceNote(
            cloudNote.toMap(),
          );
        }
      }

      // ------------------------------------------------------
      // STEP 5
      // Reload UI
      // ------------------------------------------------------

      await _loadLocalNotes();

      debugPrint(
        'SYNC: COMPLETE',
      );

      debugPrint(
        '========================================',
      );

      if (showMessage) {
        _showMessage(
          'Sync completed successfully.',
        );
      }
    } catch (e, stackTrace) {
      debugPrint(
        'SYNC ERROR: $e',
      );

      debugPrint(
        'STACK TRACE: $stackTrace',
      );

      debugPrint(
        '========================================',
      );

      if (showMessage) {
        _showMessage(
          'Sync failed. Local notes are safe.',
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          isSyncing = false;
        });
      }
    }
  }

  // ==========================================================
  // ADD DIALOG
  // ==========================================================

  void _showAddNoteDialog() {
    final titleController =
        TextEditingController();

    final contentController =
        TextEditingController();

    _showNoteDialog(
      title: 'Add Note',
      titleController:
          titleController,
      contentController:
          contentController,
      buttonText: 'Save Note',
      onSave: () async {
        final title =
            titleController.text.trim();

        final content =
            contentController.text.trim();

        if (title.isEmpty ||
            content.isEmpty) {
          _showMessage(
            'Enter title and content.',
          );
          return;
        }

        Navigator.pop(context);

        await _createNote(
          title,
          content,
        );
      },
    );
  }

  // ==========================================================
  // EDIT DIALOG
  // ==========================================================

  void _showEditNoteDialog(
    Note note,
  ) {
    final titleController =
        TextEditingController(
      text: note.title,
    );

    final contentController =
        TextEditingController(
      text: note.content,
    );

    _showNoteDialog(
      title: 'Edit Note',
      titleController:
          titleController,
      contentController:
          contentController,
      buttonText: 'Update Note',
      onSave: () async {
        final title =
            titleController.text.trim();

        final content =
            contentController.text.trim();

        if (title.isEmpty ||
            content.isEmpty) {
          _showMessage(
            'Enter title and content.',
          );
          return;
        }

        Navigator.pop(context);

        await _updateNote(
          note,
          title,
          content,
        );
      },
    );
  }

  // ==========================================================
  // NOTE DIALOG
  // ==========================================================

  void _showNoteDialog({
    required String title,
    required TextEditingController
        titleController,
    required TextEditingController
        contentController,
    required String buttonText,
    required Future<void> Function()
        onSave,
  }) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      builder: (sheetContext) {
        return Padding(
          padding: EdgeInsets.only(
            left: 20,
            right: 20,
            top: 24,
            bottom:
                MediaQuery.of(
                      sheetContext,
                    )
                    .viewInsets
                    .bottom +
                    24,
          ),
          child:
              SingleChildScrollView(
            child: Column(
              mainAxisSize:
                  MainAxisSize.min,
              crossAxisAlignment:
                  CrossAxisAlignment
                      .start,
              children: [
                Text(
                  title,
                  style:
                      const TextStyle(
                    fontSize: 24,
                    fontWeight:
                        FontWeight.bold,
                  ),
                ),

                const SizedBox(
                  height: 20,
                ),

                TextField(
                  controller:
                      titleController,
                  decoration:
                      const InputDecoration(
                    labelText: 'Title',
                    border:
                        OutlineInputBorder(),
                  ),
                ),

                const SizedBox(
                  height: 16,
                ),

                TextField(
                  controller:
                      contentController,
                  maxLines: 5,
                  decoration:
                      const InputDecoration(
                    labelText:
                        'Content',
                    border:
                        OutlineInputBorder(),
                    alignLabelWithHint:
                        true,
                  ),
                ),

                const SizedBox(
                  height: 20,
                ),

                SizedBox(
                  width:
                      double.infinity,
                  child:
                      FilledButton(
                    onPressed: onSave,
                    child:
                        Text(buttonText),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  // ==========================================================
  // DELETE CONFIRMATION
  // ==========================================================

  Future<void>
      _confirmDelete(
    Note note,
  ) async {
    final result =
        await showDialog<bool>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title:
              const Text(
            'Delete Note?',
          ),
          content:
              const Text(
            'This will delete the note locally and from Firebase.',
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.pop(
                  context,
                  false,
                );
              },
              child:
                  const Text(
                'Cancel',
              ),
            ),
            FilledButton(
              onPressed: () {
                Navigator.pop(
                  context,
                  true,
                );
              },
              child:
                  const Text(
                'Delete',
              ),
            ),
          ],
        );
      },
    );

    if (result == true) {
      await _deleteNote(note);
    }
  }

  // ==========================================================
  // NOTE CARD
  // ==========================================================

  Widget _noteCard(
    Note note,
  ) {
    final date =
        DateFormat(
      'dd MMM yyyy, hh:mm a',
    ).format(
      note.updatedAt,
    );

    return Card(
      margin:
          const EdgeInsets.only(
        bottom: 12,
      ),
      elevation: 0,
      child: Padding(
        padding:
            const EdgeInsets.all(
          16,
        ),
        child: Row(
          crossAxisAlignment:
              CrossAxisAlignment
                  .start,
          children: [
            Expanded(
              child:
                  Column(
                crossAxisAlignment:
                    CrossAxisAlignment
                        .start,
                children: [
                  Text(
                    note.title,
                    style:
                        const TextStyle(
                      fontSize: 18,
                      fontWeight:
                          FontWeight.bold,
                    ),
                  ),

                  const SizedBox(
                    height: 8,
                  ),

                  Text(
                    note.content,
                    maxLines: 3,
                    overflow:
                        TextOverflow
                            .ellipsis,
                    style:
                        TextStyle(
                      color: Colors
                          .grey
                          .shade700,
                    ),
                  ),

                  const SizedBox(
                    height: 12,
                  ),

                  Text(
                    'Updated $date',
                    style:
                        TextStyle(
                      fontSize: 12,
                      color: Colors
                          .grey
                          .shade600,
                    ),
                  ),
                ],
              ),
            ),

            PopupMenuButton<
                String>(
              onSelected:
                  (value) {
                if (value ==
                    'edit') {
                  _showEditNoteDialog(
                    note,
                  );
                }

                if (value ==
                    'delete') {
                  _confirmDelete(
                    note,
                  );
                }
              },
              itemBuilder:
                  (context) {
                return const [
                  PopupMenuItem(
                    value: 'edit',
                    child: Row(
                      children: [
                        Icon(
                          Icons
                              .edit_outlined,
                        ),
                        SizedBox(
                          width: 8,
                        ),
                        Text(
                          'Edit',
                        ),
                      ],
                    ),
                  ),
                  PopupMenuItem(
                    value: 'delete',
                    child: Row(
                      children: [
                        Icon(
                          Icons
                              .delete_outline,
                        ),
                        SizedBox(
                          width: 8,
                        ),
                        Text(
                          'Delete',
                        ),
                      ],
                    ),
                  ),
                ];
              },
            ),
          ],
        ),
      ),
    );
  }

  // ==========================================================
  // EMPTY STATE
  // ==========================================================

  Widget _emptyState() {
    return Center(
      child:
          Column(
        mainAxisAlignment:
            MainAxisAlignment
                .center,
        children: [
          Icon(
            Icons
                .note_alt_outlined,
            size: 72,
            color: Colors
                .indigo
                .shade300,
          ),

          const SizedBox(
            height: 20,
          ),

          const Text(
            'No notes yet',
            style:
                TextStyle(
              fontSize: 22,
              fontWeight:
                  FontWeight.bold,
            ),
          ),

          const SizedBox(
            height: 8,
          ),

          Text(
            'Tap + to create your first note.',
            style:
                TextStyle(
              color: Colors
                  .grey
                  .shade600,
            ),
          ),
        ],
      ),
    );
  }

  // ==========================================================
  // SNACKBAR
  // ==========================================================

  void _showMessage(
    String message,
  ) {
    if (!mounted) {
      return;
    }

    ScaffoldMessenger.of(
      context,
    ).hideCurrentSnackBar();

    ScaffoldMessenger.of(
      context,
    ).showSnackBar(
      SnackBar(
        content:
            Text(message),
      ),
    );
  }

  // ==========================================================
  // BUILD
  // ==========================================================

  @override
  Widget build(
    BuildContext context,
  ) {
    return Scaffold(
      appBar: AppBar(
        title:
            const Text(
          'Student Notes',
          style:
              TextStyle(
            fontWeight:
                FontWeight.bold,
          ),
        ),
        backgroundColor:
            Colors.transparent,
        elevation: 0,
        actions: [
          IconButton(
            tooltip:
                'Sync with Firebase',
            onPressed:
                isSyncing
                    ? null
                    : () {
                        _sync();
                      },
            icon:
                isSyncing
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child:
                            CircularProgressIndicator(
                          strokeWidth: 2,
                        ),
                      )
                    : const Icon(
                        Icons.sync,
                      ),
          ),
          const SizedBox(
            width: 8,
          ),
        ],
      ),

      body:
          Padding(
        padding:
            const EdgeInsets.all(
          20,
        ),
        child:
            Column(
          crossAxisAlignment:
              CrossAxisAlignment
                  .start,
          children: [
            const Text(
              'My Notes',
              style:
                  TextStyle(
                fontSize: 28,
                fontWeight:
                    FontWeight.bold,
              ),
            ),

            const SizedBox(
              height: 6,
            ),

            Text(
              '${notes.length} ${notes.length == 1 ? 'note' : 'notes'}',
              style:
                  TextStyle(
                color: Colors
                    .grey
                    .shade600,
              ),
            ),

            const SizedBox(
              height: 20,
            ),

            Expanded(
              child:
                  isLoading
                      ? const Center(
                          child:
                              CircularProgressIndicator(),
                        )
                      : RefreshIndicator(
                          onRefresh:
                              () =>
                                  _sync(
                            showMessage:
                                true,
                          ),
                          child:
                              notes.isEmpty
                                  ? ListView(
                                      physics:
                                          const AlwaysScrollableScrollPhysics(),
                                      children: [
                                        SizedBox(
                                          height:
                                              MediaQuery.of(context).size.height *
                                                  0.55,
                                          child:
                                              _emptyState(),
                                        ),
                                      ],
                                    )
                                  : ListView.builder(
                                      physics:
                                          const AlwaysScrollableScrollPhysics(),
                                      itemCount:
                                          notes.length,
                                      itemBuilder:
                                          (context, index) {
                                        return _noteCard(
                                          notes[index],
                                        );
                                      },
                                    ),
                        ),
            ),
          ],
        ),
      ),

      floatingActionButton:
          FloatingActionButton
              .extended(
        onPressed:
            _showAddNoteDialog,
        icon:
            const Icon(
          Icons.add,
        ),
        label:
            const Text(
          'Add Note',
        ),
      ),
    );
  }
}