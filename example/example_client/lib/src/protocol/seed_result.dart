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

abstract class SeedResult
    implements _isc.SerializableModel, _isc.ProtocolSerialization {
  SeedResult._({
    required this.message,
    required this.authorsCreated,
    required this.articlesCreated,
    required this.success,
  });

  factory SeedResult({
    required String message,
    required int authorsCreated,
    required int articlesCreated,
    required bool success,
  }) = _SeedResultImpl;

  factory SeedResult.fromJson(Map<String, dynamic> jsonSerialization) {
    return SeedResult(
      message: jsonSerialization['message'] as String,
      authorsCreated: jsonSerialization['authorsCreated'] as int,
      articlesCreated: jsonSerialization['articlesCreated'] as int,
      success: _isc.BoolJsonExtension.fromJson(jsonSerialization['success']),
    );
  }

  String message;

  int authorsCreated;

  int articlesCreated;

  bool success;

  /// Returns a shallow copy of this [SeedResult]
  /// with some or all fields replaced by the given arguments.
  @_isc.useResult
  SeedResult copyWith({
    String? message,
    int? authorsCreated,
    int? articlesCreated,
    bool? success,
  });
  @override
  Map<String, dynamic> toJson() {
    return {
      '__className__': 'SeedResult',
      'message': message,
      'authorsCreated': authorsCreated,
      'articlesCreated': articlesCreated,
      'success': success,
    };
  }

  @override
  Map<String, dynamic> toJsonForProtocol() {
    return {
      '__className__': 'SeedResult',
      'message': message,
      'authorsCreated': authorsCreated,
      'articlesCreated': articlesCreated,
      'success': success,
    };
  }

  @override
  String toString() {
    return _isc.SerializationManager.encode(this);
  }
}

class _SeedResultImpl extends SeedResult {
  _SeedResultImpl({
    required String message,
    required int authorsCreated,
    required int articlesCreated,
    required bool success,
  }) : super._(
         message: message,
         authorsCreated: authorsCreated,
         articlesCreated: articlesCreated,
         success: success,
       );

  /// Returns a shallow copy of this [SeedResult]
  /// with some or all fields replaced by the given arguments.
  @_isc.useResult
  @override
  SeedResult copyWith({
    String? message,
    int? authorsCreated,
    int? articlesCreated,
    bool? success,
  }) {
    return SeedResult(
      message: message ?? this.message,
      authorsCreated: authorsCreated ?? this.authorsCreated,
      articlesCreated: articlesCreated ?? this.articlesCreated,
      success: success ?? this.success,
    );
  }
}
