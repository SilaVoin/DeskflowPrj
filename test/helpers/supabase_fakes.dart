import 'dart:async';

import 'package:mocktail/mocktail.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

// ─────────────────────────── Mock client ──────────────────────────────

class MockSupabaseClient extends Mock implements SupabaseClient {}

// ─────────────────────────── Fake builders ────────────────────────────

/// Fakes the return of `SupabaseClient.from('table')`.
///
/// All query chain methods are funnelled through [noSuchMethod] and
/// ultimately resolve to [_data] when the chain is `await`ed.
class FakeQueryBuilder extends Fake implements SupabaseQueryBuilder {
  final dynamic _data;
  FakeQueryBuilder(this._data);

  // noSuchMethod handles select, insert, update, delete, upsert — all of
  // which return PostgrestFilterBuilder<PostgrestList>.
  @override
  dynamic noSuchMethod(Invocation invocation) =>
      FakeFilterBuilder<PostgrestList>(_data);
}

/// Fakes the PostgREST filter / transform chain.
///
/// Chain methods (eq, order, range…) return `this`.
/// [single] and [count] get explicit overrides because they change the
/// generic type parameter.  Everything else uses [noSuchMethod].
class FakeFilterBuilder<T> extends Fake implements PostgrestFilterBuilder<T> {
  final dynamic _data;
  FakeFilterBuilder(this._data);

  // ── Methods that change the generic type ──────────────────────────

  @override
  PostgrestFilterBuilder<Map<String, dynamic>> single() =>
      FakeFilterBuilder<Map<String, dynamic>>(
        _data is List ? _data.first : _data,
      );

  @override
  FakeFilterBuilder<Map<String, dynamic>?> maybeSingle() =>
      FakeFilterBuilder<Map<String, dynamic>?>(
        _data is List && _data.isNotEmpty
            ? _data.first as Map<String, dynamic>
            : null,
      );

  // ── Future<T> implementation (makes the builder await-able) ───────

  @override
  Future<R> then<R>(
    FutureOr<R> Function(T value) onValue, {
    Function? onError,
  }) =>
      Future<T>.value(_data as T).then(onValue, onError: onError);

  @override
  Future<T> catchError(Function onError,
          {bool Function(Object error)? test}) =>
      Future<T>.value(_data as T).catchError(onError, test: test);

  @override
  Future<T> whenComplete(FutureOr<void> Function() action) =>
      Future<T>.value(_data as T).whenComplete(action);

  @override
  Future<T> timeout(Duration timeLimit,
          {FutureOr<T> Function()? onTimeout}) =>
      Future<T>.value(_data as T).timeout(timeLimit, onTimeout: onTimeout);

  @override
  Stream<T> asStream() => Stream<T>.value(_data as T);

  // ── All other chain methods (eq, order, range…) return `this` ─────

  @override
  dynamic noSuchMethod(Invocation invocation) => this;
}
