/// A sealed Result type for functional error handling.
///
/// Use this instead of try/catch for predictable error flows:
/// ```dart
/// final result = await repository.fetchData();
/// return result.fold(
///   (failure) => showError(failure.message),
///   (data) => displayData(data),
/// );
/// ```
sealed class Result<T> {
  const Result();

  /// Execute the appropriate handler based on success or failure.
  R fold<R>({
    required R Function(Failure) onFailure,
    required R Function(T data) onSuccess,
  });

  /// Transform the success value, passing through failures unchanged.
  Result<R> map<R>(R Function(T data) fn) {
    return fold(
      onFailure: (failure) => Result<R>.failure(
        message: failure.message,
        code: failure.code,
        exception: failure.exception,
        stackTrace: failure.stackTrace,
      ),
      onSuccess: (data) => Result<R>.success(fn(data)),
    );
  }

  /// Return the success value or a fallback.
  T getOrElse(T Function(Failure) fn) {
    return fold(onFailure: fn, onSuccess: (data) => data);
  }

  /// Return the success value or throw the failure.
  T getOrThrow() {
    return fold(
      onFailure: (failure) => throw failure,
      onSuccess: (data) => data,
    );
  }

  /// Check if this result is a success.
  bool get isSuccess => this is Success<T>;

  /// Check if this result is a failure.
  bool get isFailure => this is Failure;

  /// Create a successful result.
  const factory Result.success(T data) = Success<T>;

  /// Create a failure result from a Failure object.
  factory Result.failure({
    required String message,
    String? code,
    Object? exception,
    StackTrace? stackTrace,
  }) = Failure<T>;
}

/// Successful result containing data.
class Success<T> extends Result<T> {
  final T data;

  const Success(this.data);

  @override
  R fold<R>({
    required R Function(Failure) onFailure,
    required R Function(T data) onSuccess,
  }) => onSuccess(data);

  @override
  String toString() => 'Success($data)';
}

/// Failed result containing error information.
class Failure<T> extends Result<T> implements Exception {
  final String message;
  final String? code;
  final Object? exception;
  final StackTrace? stackTrace;

  const Failure({
    required this.message,
    this.code,
    this.exception,
    this.stackTrace,
  });

  @override
  R fold<R>({
    required R Function(Failure) onFailure,
    required R Function(T data) onSuccess,
  }) => onFailure(this);

  @override
  String toString() {
    final buffer = StringBuffer('Failure');
    if (code != null) buffer.write(' [$code]');
    buffer.write(': $message');
    if (exception != null) buffer.write(' ($exception)');
    return buffer.toString();
  }
}
