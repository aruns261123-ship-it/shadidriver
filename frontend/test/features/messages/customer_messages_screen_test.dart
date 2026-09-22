import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shadidriver/app/providers/app_providers.dart';
import 'package:shadidriver/features/messages/presentation/customer_messages_screen.dart';
import 'package:shadidriver/features/notifications/data/mock_notification_repository.dart';

void main() {
  group('CustomerMessagesScreen Widget Tests', () {
    testWidgets(
      'renders message threads and opens message detail sheet on tap',
      (tester) async {
        final mockNotifRepo = MockNotificationRepository();

        await tester.pumpWidget(
          ProviderScope(
            overrides: [
              notificationRepositoryProvider.overrideWithValue(mockNotifRepo),
            ],
            child: const MaterialApp(home: CustomerMessagesScreen()),
          ),
        );

        // Wait for initial notification load
        await tester.pumpAndSettle();

        // Screen title
        expect(find.text('Messages'), findsOneWidget);

        // Seeded threads from notification repository
        expect(find.text('Booking Request Received'), findsOneWidget);
        expect(find.text('Chauffeur Allocated'), findsOneWidget);
        expect(find.text('Ceremonial Standards Confirmed'), findsOneWidget);

        // Tap on the first message card
        await tester.tap(find.text('Booking Request Received'));
        await tester.pumpAndSettle();

        // Detail sheet opens
        expect(find.textContaining('Received'), findsWidgets);
        expect(find.text('View Bookings'), findsOneWidget);
        expect(find.text('Concierge Help'), findsOneWidget);

        // Verify the item was marked as read
        final notifs = await mockNotifRepo.getNotifications();
        final item = notifs.dataOrNull!.firstWhere((n) => n.id == 'notif_1');
        expect(item.isRead, isTrue);
      },
    );
  });
}
