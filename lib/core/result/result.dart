import '../errors/failures.dart';

/// A functional Result type representing either a successful computation (`Success`)
/// or a failure (`Failure`) with a strongly typed [AppFailure].
sealed class Result<T> {
  const Result();

  /// Create a successful result containing [data].
  const factory Result.success(T data) = Success<T>;

  /// Create a failed result containing [failure].
  const factory Result.failure(AppFailure failure) = Failure<T>;

  bool get isSuccess => this is Success<T>;
  bool get isFailure => this is Failure<T>;

  T? get dataOrNull => switch (this) {
        Success(:final data) => data,
        Failure() => null,
      };

  AppFailure? get failureOrNull => switch (this) {
        Success() => null,
        Failure(failure: final f) => f,
      };

  /// Pattern-matches over the result.
  R when<R>({
    required R Function(T data) success,
    required R Function(AppFailure failure) failure,
  }) {
    return switch (this) {
      Success(data: final d) => success(d),
      Failure(failure: final f) => failure(f),
    };
  }

  /// Transforms the successful value if present.
  Result<R> map<R>(R Function(T data) transform) {
    return switch (this) {
      Success(data: final d) => Result.success(transform(d)),
      Failure(failure: final f) => Result.failure(f),
    };
  }

  /// Fold executes [onFailure] or [onSuccess] based on the result.
  R fold<R>(
    R Function(AppFailure failure) onFailure,
    R Function(T data) onSuccess,
  ) {
    return switch (this) {
      Success(:final data) => onSuccess(data),
      Failure(:final failure) => onFailure(failure),
    };
  }
}

/// Represents a successful result holding [data].
final class Success<T> extends Result<T> {
  final T data;
  const Success(this.data);

  @override
  bool operator ==(Object other) =>
      identical(this, other) || (other is Success<T> && other.data == data);

  @override
  int get hashCode => data.hashCode;

  @override
  String toString() => 'Result.success($data)';
}

/// Represents a failure holding an [AppFailure].
final class Failure<T> extends Result<T> {
  final AppFailure failure;
  const Failure(this.failure);

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is Failure<T> && other.failure == failure);

  @override
  int get hashCode => failure.hashCode;

  @override
  String toString() => 'Result.failure($failure)';
}
