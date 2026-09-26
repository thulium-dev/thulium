import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:thulium/auth/secure_custom_plan_store.dart';
import 'package:thulium_campus/thulium_campus.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('custom plans persist separately for each student account', () async {
    FlutterSecureStorage.setMockInitialValues({});
    final store = SecureCustomPlanStore();
    final collection = CustomPlanCollection(
      categories: const [
        CustomPlanCategory(
          id: 'user.study',
          name: 'Study',
          colorValue: 0xFF6B5CE7,
        ),
      ],
      plans: [
        CustomPlan(
          id: 'plan-1',
          name: 'Study group',
          location: 'Library',
          startsAt: DateTime(2026, 9, 21, 9),
          endsAt: DateTime(2026, 9, 21, 10),
          category: 'user.study',
          repeat: PlanRepeat.weekly,
        ),
      ],
    );

    final first = collection
        .entriesForWeek([], DateTime(2026, 9, 21), DateTime(2026, 9, 28))
        .single;
    final personalized = collection
        .replaceOccurrence(first, null)
        .copyWith(skipCancelConfirmation: true);
    await store.writeFor('student-a', personalized);
    expect(
      (await SecureCustomPlanStore().readFor('student-a')).plans.single.name,
      'Study group',
    );
    final restored = await SecureCustomPlanStore().readFor('student-a');
    expect(restored.overrides, hasLength(1));
    expect(restored.skipCancelConfirmation, isTrue);
    expect((await store.readFor('student-b')).plans, isEmpty);
  });
}
