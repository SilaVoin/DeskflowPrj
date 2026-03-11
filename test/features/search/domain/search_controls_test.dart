import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:deskflow/features/search/domain/search_controls.dart';
import 'package:deskflow/features/search/domain/search_providers.dart';

void main() {
  group('SearchControls', () {
    test('defaults to collapsed history and all entities', () {
      const controls = SearchControls();

      expect(controls.query, isEmpty);
      expect(controls.entityFilter, SearchFilter.all);
      expect(controls.orderStatusId, isNull);
      expect(controls.isHistoryExpanded, false);
      expect(controls.showsOrderStatusFilters, false);
    });

    test('switching to orders keeps status filter available', () {
      final controls = const SearchControls().switchEntityFilter(
        SearchFilter.orders,
      );

      expect(controls.entityFilter, SearchFilter.orders);
      expect(controls.showsOrderStatusFilters, true);
    });

    test('switching away from orders clears status filter', () {
      const controls = SearchControls(
        entityFilter: SearchFilter.orders,
        orderStatusId: 'status-1',
      );

      final next = controls.switchEntityFilter(SearchFilter.customers);

      expect(next.entityFilter, SearchFilter.customers);
      expect(next.orderStatusId, isNull);
      expect(next.showsOrderStatusFilters, false);
    });

    test('status filter is ignored outside orders slice', () {
      const controls = SearchControls();

      final next = controls.setOrderStatus('status-1');

      expect(next.orderStatusId, isNull);
    });

    test('query updates use normalized text', () {
      const controls = SearchControls();

      final next = controls.withQuery('  Иванов   #001  ');

      expect(next.query, 'Иванов #001');
      expect(next.hasRunnableQuery, true);
    });

    test('history expansion toggles explicitly', () {
      const controls = SearchControls();

      expect(controls.toggleHistoryExpanded().isHistoryExpanded, true);
      expect(controls.toggleHistoryExpanded(true).isHistoryExpanded, true);
      expect(controls.toggleHistoryExpanded(false).isHistoryExpanded, false);
    });

    test('clearQuery keeps sticky filters intact', () {
      final container = ProviderContainer();
      addTearDown(container.dispose);

      final notifier = container.read(searchControlsProvider.notifier);

      notifier.switchEntityFilter(SearchFilter.orders);
      notifier.setOrderStatus('status-1');
      notifier.setQuery('Иванов');
      notifier.clearQuery();

      final controls = container.read(searchControlsProvider);
      expect(controls.query, isEmpty);
      expect(controls.entityFilter, SearchFilter.orders);
      expect(controls.orderStatusId, 'status-1');
    });
  });
}
