import 'package:mobx/mobx.dart';
import 'package:mockito/mockito.dart';
import 'package:test/test.dart';

import 'shared_mocks.dart';

void main() {
  group('Action', () {
    test('basics work', () {
      final a = Action((String name, String value) {
        expect(name, equals('name'));
        expect(value, equals('MobX'));
      });

      a(['name', 'MobX']);
      expect(a.name, startsWith('Action'));
    });

    test('modifications are picked up', () {
      final x = Observable(10);

      var total = 0;
      final a = Action(() {
        x.value = x.value +
            1; // No reaction-infinite-loop as we are not tracking the observables
      });

      final dispose = autorun((_) {
        total = x.value * 10;
      });

      expect(total, equals(100));

      a();
      expect(total, equals(110));

      dispose();
    });

    test('modifications are batched', () {
      final x = Observable(10);
      final y = Observable(20);
      final z = Observable(30);

      var total = 0;
      var autorunExecutionCount = 0;

      final dispose = autorun((_) {
        total = x.value + y.value + z.value;
        autorunExecutionCount++;
      });

      expect(total, equals(60));
      expect(autorunExecutionCount, equals(1));

      final a = Action(() {
        x.value++;
        y.value++;
        z.value++;
      });

      a();
      expect(total, equals(63));
      expect(autorunExecutionCount, equals(2));

      a();
      expect(total, equals(66));
      expect(autorunExecutionCount, equals(3));

      dispose();
    });

    test('inside autorun should be untracked', () {
      final x = Observable(10);
      final y = Observable(20);

      var total = 0;
      final a = Action(() => y.value);

      final d = autorun((_) {
        total = x.value + a();
      });

      expect(total, equals(30));

      // This should not trigger the autorun as y.value is accessed inside the action(),
      // which by design should be untracked
      y.value = 30;

      expect(total, equals(30)); // total should still be 10 + 20
      x.value = 11;
      expect(total, equals(41)); // total should still be 11 + 30

      d();
    });

    test('can be invoked with named args', () {
      String message;

      final a = Action(({String name, String value}) {
        message = '$name: $value';
      });

      a([], {'name': 'Hello', 'value': 'MobX'});
      expect(message, equals('Hello: MobX'));
    });

    test('when nested works', () {
      final x = Observable(10);
      final y = Observable(20);

      var executionCount = 0;

      final d = autorun((_) {
        // ignore: unnecessary_statements
        x.value + y.value;
        executionCount++;
      });

      Action(() {
        x.value = 100;

        expect(executionCount, equals(1)); // No notifications are fired
        Action(() {
          y.value = 200;
          expect(executionCount, equals(1)); // No notifications are fired
        })();
      })();

      // Notifications are fired now
      expect(executionCount, equals(2));

      d();
    });

    test('uses provided context', () {
      final context = MockContext();
      void fn() {}
      final act = Action(fn, context: context);

      act();

      verify(context.nameFor('Action'));
      verify(context.untrackedStart());
      verify(context.startBatch());
      verify(context.endBatch());
      verify(context.untrackedEnd(null));
    });
  });

  test('runInAction works', () {
    final x = Observable(10);
    final y = Observable(20);

    var executionCount = 0;
    var total = 0;

    final d = autorun((_) {
      total = x.value + y.value;
      executionCount++;
    });

    runInAction(() {
      x.value = 100;
      y.value = 200;

      expect(executionCount, equals(1)); // No notifications are fired
    });

    // Notifications are fired now
    expect(executionCount, equals(2));
    expect(total, equals(300));

    d();
  });

  test('transaction works', () {
    final x = Observable(10);
    final y = Observable(20);

    var total = 0;

    final d = autorun((_) {
      total = x.value + y.value;
    });

    transaction(() {
      x.value = 100;
      y.value = 200;

      // within a transaction(), there are no notifications fired, so the total should not change
      expect(total, equals(30));
    });

    // Notifications fire now, causing autorun() to execute
    expect(total, equals(300));

    d();
  });

  test('untracked works', () {
    final x = Observable(0);
    var count = 0;

    final d = autorun((_) {
      // No tracking should be performed since we are reading inside untracked()
      untracked(() {
        x.value;
      });

      count++;
    });

    expect(count, equals(1));

    x.value = 100;

    // Should be no change in count
    expect(count, equals(1));

    d();
  });
}
