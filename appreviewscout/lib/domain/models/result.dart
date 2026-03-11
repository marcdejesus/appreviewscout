sealed class Result<T> {
  const Result();

  bool get isOk => this is Ok<T>;
  bool get isError => this is Error<T>;
}

class Ok<T> extends Result<T> {
  const Ok(this.value);
  final T value;
}

class Error<T> extends Result<T> {
  const Error(this.message, {this.exception});
  final String message;
  final Object? exception;
}
