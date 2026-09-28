/* AUTOMATICALLY GENERATED CODE DO NOT MODIFY */
/*   To generate run: "serverpod generate"    */

// ignore_for_file: implementation_imports
// ignore_for_file: library_private_types_in_public_api
// ignore_for_file: non_constant_identifier_names
// ignore_for_file: public_member_api_docs
// ignore_for_file: type_literal_in_constant_pattern
// ignore_for_file: use_super_parameters
// ignore_for_file: invalid_use_of_internal_member

// ignore_for_file: no_leading_underscores_for_library_prefixes
import 'package:serverpod_client/serverpod_client.dart' as _isc;

abstract class Article
    implements _isc.SerializableModel, _isc.ProtocolSerialization {
  Article._({
    this.id,
    required this.title,
    required this.content,
    required this.published,
    required this.authorId,
    required this.createdAt,
  });

  factory Article({
    int? id,
    required String title,
    required String content,
    required bool published,
    required int authorId,
    required DateTime createdAt,
  }) = _ArticleImpl;

  factory Article.fromJson(Map<String, dynamic> jsonSerialization) {
    return Article(
      id: jsonSerialization['id'] as int?,
      title: jsonSerialization['title'] as String,
      content: jsonSerialization['content'] as String,
      published: _isc.BoolJsonExtension.fromJson(
        jsonSerialization['published'],
      ),
      authorId: jsonSerialization['authorId'] as int,
      createdAt: _isc.DateTimeJsonExtension.fromJson(
        jsonSerialization['createdAt'],
      ),
    );
  }

  /// The database id, set if the object has been inserted into the
  /// database or if it has been fetched from the database. Otherwise,
  /// the id will be null.
  int? id;

  String title;

  String content;

  bool published;

  int authorId;

  DateTime createdAt;

  /// Returns a shallow copy of this [Article]
  /// with some or all fields replaced by the given arguments.
  @_isc.useResult
  Article copyWith({
    int? id,
    String? title,
    String? content,
    bool? published,
    int? authorId,
    DateTime? createdAt,
  });
  @override
  Map<String, dynamic> toJson() {
    return {
      '__className__': 'Article',
      if (id != null) 'id': id,
      'title': title,
      'content': content,
      'published': published,
      'authorId': authorId,
      'createdAt': createdAt.toJson(),
    };
  }

  @override
  Map<String, dynamic> toJsonForProtocol() {
    return {
      '__className__': 'Article',
      if (id != null) 'id': id,
      'title': title,
      'content': content,
      'published': published,
      'authorId': authorId,
      'createdAt': createdAt.toJson(),
    };
  }

  @override
  String toString() {
    return _isc.SerializationManager.encode(this);
  }
}

class _Undefined {}

class _ArticleImpl extends Article {
  _ArticleImpl({
    int? id,
    required String title,
    required String content,
    required bool published,
    required int authorId,
    required DateTime createdAt,
  }) : super._(
         id: id,
         title: title,
         content: content,
         published: published,
         authorId: authorId,
         createdAt: createdAt,
       );

  /// Returns a shallow copy of this [Article]
  /// with some or all fields replaced by the given arguments.
  @_isc.useResult
  @override
  Article copyWith({
    Object? id = _Undefined,
    String? title,
    String? content,
    bool? published,
    int? authorId,
    DateTime? createdAt,
  }) {
    return Article(
      id: id is int? ? id : this.id,
      title: title ?? this.title,
      content: content ?? this.content,
      published: published ?? this.published,
      authorId: authorId ?? this.authorId,
      createdAt: createdAt ?? this.createdAt,
    );
  }
}
