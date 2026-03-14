import 'dart:async';

import 'package:mocktail/mocktail.dart';
import 'package:supabase_flutter/supabase_flutter.dart';


class MockSupabaseClient extends Mock implements SupabaseClient {}


class FakeQueryBuilder extends Fake implements SupabaseQueryBuilder {
  final dynamic _data;
  FakeQueryBuilder(this._data);

  @override
  dynamic noSuchMethod(Invocation invocation) =>
      FakeFilterBuilder<PostgrestList>(_data);
}

class RecordingQueryBuilder extends Fake implements SupabaseQueryBuilder {
  RecordingQueryBuilder(this._data);

  final dynamic _data;
  final List<Invocation> invocations = [];

  @override
  dynamic noSuchMethod(Invocation invocation) {
    invocations.add(invocation);
    return RecordingFilterBuilder<PostgrestList>(_data, invocations);
  }
}

class FakeFilterBuilder<T> extends Fake implements PostgrestFilterBuilder<T> {
  final dynamic _data;
  FakeFilterBuilder(this._data);


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


  @override
  Future<R> then<R>(
    FutureOr<R> Function(T value) onValue, {
    Function? onError,
  }) => Future<T>.value(_data as T).then(onValue, onError: onError);

  @override
  Future<T> catchError(Function onError, {bool Function(Object error)? test}) =>
      Future<T>.value(_data as T).catchError(onError, test: test);

  @override
  Future<T> whenComplete(FutureOr<void> Function() action) =>
      Future<T>.value(_data as T).whenComplete(action);

  @override
  Future<T> timeout(Duration timeLimit, {FutureOr<T> Function()? onTimeout}) =>
      Future<T>.value(_data as T).timeout(timeLimit, onTimeout: onTimeout);

  @override
  Stream<T> asStream() => Stream<T>.value(_data as T);


  @override
  dynamic noSuchMethod(Invocation invocation) => this;
}

class RecordingFilterBuilder<T> extends Fake
    implements PostgrestFilterBuilder<T> {
  RecordingFilterBuilder(this._data, this.invocations);

  final dynamic _data;
  final List<Invocation> invocations;

  @override
  PostgrestFilterBuilder<Map<String, dynamic>> single() {
    invocations.add(Invocation.method(#single, const []));
    return RecordingFilterBuilder<Map<String, dynamic>>(
      _data is List ? _data.first : _data,
      invocations,
    );
  }

  @override
  RecordingFilterBuilder<Map<String, dynamic>?> maybeSingle() {
    invocations.add(Invocation.method(#maybeSingle, const []));
    return RecordingFilterBuilder<Map<String, dynamic>?>(
      _data is List && _data.isNotEmpty
          ? _data.first as Map<String, dynamic>
          : null,
      invocations,
    );
  }

  @override
  Future<R> then<R>(
    FutureOr<R> Function(T value) onValue, {
    Function? onError,
  }) => Future<T>.value(_data as T).then(onValue, onError: onError);

  @override
  Future<T> catchError(Function onError, {bool Function(Object error)? test}) =>
      Future<T>.value(_data as T).catchError(onError, test: test);

  @override
  Future<T> whenComplete(FutureOr<void> Function() action) =>
      Future<T>.value(_data as T).whenComplete(action);

  @override
  Future<T> timeout(Duration timeLimit, {FutureOr<T> Function()? onTimeout}) =>
      Future<T>.value(_data as T).timeout(timeLimit, onTimeout: onTimeout);

  @override
  Stream<T> asStream() => Stream<T>.value(_data as T);

  @override
  dynamic noSuchMethod(Invocation invocation) {
    invocations.add(invocation);
    return this;
  }
}
