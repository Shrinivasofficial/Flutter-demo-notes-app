import 'package:cloud_firestore/cloud_firestore.dart';

import '../models/note.dart';

class FirestoreService {
  FirestoreService({
    FirebaseFirestore? firestore,
  }) : _firestore =
            firestore ?? FirebaseFirestore.instance;

  final FirebaseFirestore _firestore;

  CollectionReference<Map<String, dynamic>>
      get _notesCollection =>
          _firestore.collection('notes');

  // ============================================================
  // UPLOAD ONE NOTE
  // ============================================================

  Future<void> uploadNote(Note note) async {
    if (note.id == null) {
      throw Exception(
        'Cannot upload a note without an ID.',
      );
    }

    final document =
        _notesCollection.doc(
      note.id.toString(),
    );

    await document.set({
      'id': note.id,
      'title': note.title,
      'content': note.content,
      'createdAt': Timestamp.fromDate(
        note.createdAt,
      ),
      'updatedAt': Timestamp.fromDate(
        note.updatedAt,
      ),
    });

    print(
      'FIREBASE: Uploaded note ${note.id}',
    );
  }

  // ============================================================
  // UPLOAD ALL LOCAL NOTES
  // ============================================================

  Future<void> uploadNotes(
    List<Note> notes,
  ) async {
    print(
      'FIREBASE: Uploading ${notes.length} notes',
    );

    if (notes.isEmpty) {
      print(
        'FIREBASE: No local notes to upload',
      );
      return;
    }

    final batch = _firestore.batch();

    for (final note in notes) {
      if (note.id == null) {
        continue;
      }

      final document =
          _notesCollection.doc(
        note.id.toString(),
      );

      batch.set(
        document,
        {
          'id': note.id,
          'title': note.title,
          'content': note.content,
          'createdAt':
              Timestamp.fromDate(
            note.createdAt,
          ),
          'updatedAt':
              Timestamp.fromDate(
            note.updatedAt,
          ),
        },
      );
    }

    await batch.commit();

    print(
      'FIREBASE: Upload completed',
    );
  }

  // ============================================================
  // DOWNLOAD ALL NOTES
  // ============================================================

  Future<List<Note>> downloadNotes() async {
    print(
      'FIREBASE: Downloading notes',
    );

    final snapshot =
        await _notesCollection.get();

    final notes = <Note>[];

    for (final document
        in snapshot.docs) {
      final data = document.data();

      final id =
          (data['id'] as num?)?.toInt();

      if (id == null) {
        continue;
      }

      final createdAt =
          _getDateTime(
        data['createdAt'],
      );

      final updatedAt =
          _getDateTime(
        data['updatedAt'],
      );

      notes.add(
        Note(
          id: id,
          title:
              data['title'] as String? ?? '',
          content:
              data['content'] as String? ?? '',
          createdAt: createdAt,
          updatedAt: updatedAt,
        ),
      );
    }

    print(
      'FIREBASE: Downloaded ${notes.length} notes',
    );

    return notes;
  }

  // ============================================================
  // DELETE
  // ============================================================

  Future<void> deleteNote(int id) async {
    await _notesCollection
        .doc(id.toString())
        .delete();

    print(
      'FIREBASE: Deleted note $id',
    );
  }

  // ============================================================
  // TIMESTAMP CONVERSION
  // ============================================================

  DateTime _getDateTime(
    dynamic value,
  ) {
    if (value is Timestamp) {
      return value.toDate();
    }

    if (value is DateTime) {
      return value;
    }

    if (value is String) {
      return DateTime.tryParse(value) ??
          DateTime.now();
    }

    return DateTime.now();
  }
}