part of '../reactive_model.dart';

abstract class ReactiveModelUndoRedoState<T> extends ReactiveModelBuilder<T> {
  int _undoStackLength = 0;

  ///Whether the state can be redone.
  bool get canRedoState => _redoQueue.isNotEmpty;

  ///Whether the state can be done
  bool get canUndoState => _undoQueue.isNotEmpty;

  ///Clear undoStack;
  void clearUndoStack() {
    _undoQueue.clear();
    _redoQueue.clear();
  }

  ///redo to the next valid state (isWaiting and hasError are ignored)
  ReactiveModel<T> redoState() {
    if (!canRedoState) {
      return this as ReactiveModel<T>;
    }
    _undoQueue.add(snapState);
    snapState = _redoQueue.removeLast();
    _notifyListeners();
    return this as ReactiveModel<T>;
  }

  ///undo to the last valid state (isWaiting and hasError are ignored)
  ReactiveModel<T> undoState() {
    if (!canUndoState) {
      return this as ReactiveModel<T>;
    }
    _redoQueue.add(snapState);
    // final oldSnapShot = ;
    snapState = _undoQueue.removeLast();
    _notifyListeners();

    return this as ReactiveModel<T>;
  }

  void _addToUndoQueue() {
    if (_undoStackLength < 1) {
      return;
    }

    _undoQueue.add(
      snapState._copyWith(
        connectionState: ConnectionState.done,
      ),
    );
    _redoQueue.clear();

    if (_undoQueue.length > _undoStackLength) {
      _undoQueue.removeFirst();
    }
  }

  ///Set the undo/redo stack length
  set undoStackLength(int length) {
    _undoStackLength = length;
  }
}
