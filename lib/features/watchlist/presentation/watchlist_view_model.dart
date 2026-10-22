import 'package:bath_wise/features/watchlist/data/watchlist_providers.dart';
import 'package:bath_wise/features/watchlist/domain/watchlist_repository.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'watchlist_view_model.g.dart';

/// The watchlist's codes in display order, and the edits on it.
///
/// Edits update the state before the write lands: a dismissed or dragged
/// row must move in the same frame, or Flutter complains (Dismissible)
/// or the row jumps back for a frame (reorder). The database stream then
/// confirms the same list.
@Riverpod(keepAlive: true)
class WatchlistViewModel extends _$WatchlistViewModel {
  WatchlistRepository get _repo => ref.read(watchlistRepositoryProvider);

  @override
  Stream<List<String>> build() =>
      ref.watch(watchlistRepositoryProvider).watchCodes();

  List<String> get _codes => state.value ?? const [];

  Future<void> add(String code) => _repo.add(code);

  /// Removes [code] and its alerts; keep the result for [undoRemove].
  Future<RemovedWatchItem?> remove(String code) {
    state = AsyncData([
      for (final c in _codes)
        if (c != code) c,
    ]);
    return _repo.remove(code);
  }

  Future<void> undoRemove(RemovedWatchItem item) => _repo.restore(item);

  /// Moves the row at [oldIndex] to [newIndex], an index into the list
  /// after the row was taken out (what `onReorderItem` passes).
  Future<void> move(int oldIndex, int newIndex) {
    final codes = [..._codes];
    if (oldIndex == newIndex || oldIndex >= codes.length) return Future.value();
    codes.insert(newIndex, codes.removeAt(oldIndex));
    state = AsyncData(codes);
    return _repo.reorder(codes);
  }
}
