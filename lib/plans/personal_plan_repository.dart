import 'package:flutter/foundation.dart';
import 'package:thulium_campus/thulium_campus.dart';

import '../auth/secure_custom_plan_store.dart';

/// Serializes edits from the calendar and assistant against the same storage.
final class PersonalPlanRepository extends ChangeNotifier {
  PersonalPlanRepository({SecureCustomPlanStore? store})
    : _store = store ?? SecureCustomPlanStore();

  final SecureCustomPlanStore _store;
  final _latest = <String, CustomPlanCollection>{};
  Future<void> _pending = Future.value();
  bool _disposed = false;

  Future<CustomPlanCollection> readFor(String account) =>
      _store.readFor(account);

  CustomPlanCollection? latestChangeFor(String account) => _latest[account];

  Future<void> save(
    String account, {
    required CustomPlanCollection expected,
    required CustomPlanCollection next,
    Future<void> Function()? validate,
  }) {
    final operation = _pending.then((_) async {
      final current = await readFor(account);
      if (current.encode() != expected.encode()) {
        throw StateError('Plans changed before the edit could be saved.');
      }
      await validate?.call();
      await _store.writeFor(account, next);
      if (!_disposed) {
        _latest[account] = next;
        notifyListeners();
      }
    });
    _pending = operation.then<void>(
      (_) {},
      onError: (Object _, StackTrace _) {},
    );
    return operation;
  }

  @override
  void dispose() {
    _disposed = true;
    super.dispose();
  }
}
