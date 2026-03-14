import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:flutter_hooks/flutter_hooks.dart';

import 'package:deskflow/core/theme/deskflow_theme.dart';
import 'package:deskflow/core/widgets/glass_card.dart';
import 'package:deskflow/core/widgets/glass_floating_action_button.dart';
import 'package:deskflow/core/widgets/pill_search_bar.dart';
import 'package:deskflow/core/widgets/empty_state_widget.dart';
import 'package:deskflow/core/widgets/error_state_widget.dart';
import 'package:deskflow/core/widgets/floating_island_nav.dart';
import 'package:deskflow/core/widgets/skeleton_loader.dart';
import 'package:deskflow/features/customers/domain/customer_providers.dart';
import 'package:deskflow/features/orders/domain/customer.dart';

class CustomersListScreen extends HookConsumerWidget {
  const CustomersListScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final searchQuery = useState('');
    final scrollController = useScrollController();
    final customersAsync = ref.watch(
      customersListProvider(search: searchQuery.value.isEmpty ? null : searchQuery.value),
    );

    useEffect(() {
      void onScroll() {
        if (!scrollController.hasClients) return;
        final maxScroll = scrollController.position.maxScrollExtent;
        final currentScroll = scrollController.position.pixels;
        if (currentScroll >= maxScroll - 200) {
          ref
              .read(customersListProvider(
                search: searchQuery.value.isEmpty ? null : searchQuery.value,
              ).notifier)
              .loadMore();
        }
      }

      scrollController.addListener(onScroll);
      return () => scrollController.removeListener(onScroll);
    }, [scrollController, searchQuery.value]);

    return Scaffold(
      backgroundColor: Colors.transparent,
      appBar: AppBar(
        title: const Text('Клиенты'),
        leading: context.canPop()
            ? IconButton(
                icon: const Icon(Icons.arrow_back_rounded),
                onPressed: () => context.pop(),
              )
            : null,
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(
              DeskflowSpacing.lg,
              DeskflowSpacing.sm,
              DeskflowSpacing.lg,
              DeskflowSpacing.sm,
            ),
            child: PillSearchBar(
              hintText: 'Поиск клиентов...',
              onChanged: (query) => searchQuery.value = query,
            ),
          ),

          Expanded(
            child: customersAsync.when(
              data: (paginated) {
                final customers = paginated.items;
                if (customers.isEmpty) {
                  return EmptyStateWidget(
                    icon: Icons.contacts_rounded,
                    title: searchQuery.value.isNotEmpty
                        ? 'Ничего не найдено'
                        : 'Нет клиентов',
                    description: searchQuery.value.isNotEmpty
                        ? 'Попробуйте изменить запрос'
                        : 'Добавьте первого клиента',
                  );
                }

                return RefreshIndicator(
                  color: DeskflowColors.primarySolid,
                  backgroundColor: DeskflowColors.modalSurface,
                  onRefresh: () async {
                    ref.invalidate(customersListProvider);
                  },
                  child: ListView.separated(
                    controller: scrollController,
                    padding: const EdgeInsets.fromLTRB(
                      DeskflowSpacing.lg,
                      DeskflowSpacing.sm,
                      DeskflowSpacing.lg,
                      DeskflowSpacing.xxxl * 2,
                    ),
                    itemCount:
                        customers.length + (paginated.hasMore ? 1 : 0),
                    separatorBuilder: (_, _) =>
                        const SizedBox(height: DeskflowSpacing.sm),
                    itemBuilder: (context, index) {
                      if (index >= customers.length) {
                        return const Padding(
                          padding: EdgeInsets.all(DeskflowSpacing.lg),
                          child: Center(
                            child: SizedBox(
                              width: 24,
                              height: 24,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: DeskflowColors.primarySolid,
                              ),
                            ),
                          ),
                        );
                      }
                      final customer = customers[index];
                      return _CustomerCard(
                        customer: customer,
                        onTap: () => context.push('/customers/${customer.id}'),
                      );
                    },
                  ),
                );
              },
              loading: () => const _CustomersLoadingSkeleton(),
              error: (error, _) => ErrorStateWidget(
                message: error.toString(),
                onRetry: () => ref.invalidate(customersListProvider),
              ),
            ),
          ),
        ],
      ),
      floatingActionButton: Padding(
        padding: EdgeInsets.only(
          bottom: FloatingIslandNav.totalHeight(context) + 16,
        ),
        child: GlassFloatingActionButton(
          icon: Icons.person_add_rounded,
          onPressed: () => context.push('/customers/create'),
        ),
      ),
    );
  }
}

class _CustomerCard extends StatelessWidget {
  final Customer customer;
  final VoidCallback onTap;

  const _CustomerCard({
    required this.customer,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GlassCard(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.all(DeskflowSpacing.lg),
        child: Row(
          children: [
            Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                color: DeskflowColors.primary,
                borderRadius: BorderRadius.circular(DeskflowRadius.md),
              ),
              alignment: Alignment.center,
              child: Text(
                customer.initials,
                style: DeskflowTypography.body.copyWith(
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
            const SizedBox(width: DeskflowSpacing.md),

            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    customer.name,
                    style: DeskflowTypography.body,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  if (customer.phone != null) ...[
                    const SizedBox(height: DeskflowSpacing.xs),
                    Text(
                      customer.phone!,
                      style: DeskflowTypography.bodySmall,
                    ),
                  ],
                ],
              ),
            ),

            if (customer.orderCount > 0) ...[
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: DeskflowSpacing.sm,
                  vertical: DeskflowSpacing.xs,
                ),
                decoration: BoxDecoration(
                  color: DeskflowColors.glassSurface,
                  borderRadius: BorderRadius.circular(DeskflowRadius.pill),
                ),
                child: Text(
                  '${customer.orderCount} зак.',
                  style: DeskflowTypography.caption.copyWith(
                    color: DeskflowColors.textSecondary,
                  ),
                ),
              ),
            ],

            const SizedBox(width: DeskflowSpacing.xs),
            const Icon(
              Icons.chevron_right_rounded,
              color: DeskflowColors.textTertiary,
              size: 20,
            ),
          ],
        ),
      ),
    );
  }
}

class _CustomersLoadingSkeleton extends StatelessWidget {
  const _CustomersLoadingSkeleton();

  @override
  Widget build(BuildContext context) {
    return SkeletonLoader(
      child: ListView.separated(
        padding: const EdgeInsets.all(DeskflowSpacing.lg),
        itemCount: 8,
        separatorBuilder: (_, _) => const SizedBox(height: DeskflowSpacing.sm),
        itemBuilder: (_, _) => SkeletonLoader.box(height: 76),
      ),
    );
  }
}
