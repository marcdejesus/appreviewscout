import 'package:flutter/foundation.dart';

import '../models/result.dart';

typedef Action0<T> = Future<Result<T>> Function();

class Command0<T> extends ChangeNotifier {
  Command0(this._action);

  final Action0<T> _action;

  bool _running = false;
  bool get running => _running;

  Result<T>? _result;
  Result<T>? get result => _result;

  Future<Result<T>> execute() async {
    if (_running) {
      return Error<T>('Command already running');
    }

    _running = true;
    notifyListeners();
    final nextResult = await _action();
    _result = nextResult;
    _running = false;
    notifyListeners();
    return nextResult;
  }

  void clearResult() {
    _result = null;
    notifyListeners();
  }
}

typedef Action1<T, A> = Future<Result<T>> Function(A arg);

class Command1<T, A> extends ChangeNotifier {
  Command1(this._action);

  final Action1<T, A> _action;

  bool _running = false;
  bool get running => _running;

  Result<T>? _result;
  Result<T>? get result => _result;

  Future<Result<T>> execute(A arg) async {
    if (_running) {
      return Error<T>('Command already running');
    }

    _running = true;
    notifyListeners();
    final nextResult = await _action(arg);
    _result = nextResult;
    _running = false;
    notifyListeners();
    return nextResult;
  }

  void clearResult() {
    _result = null;
    notifyListeners();
  }
}
