import 'package:bidvibe/screens/admin/admin_ops_cases.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('admin dispute detail displays evidence photos', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: AdminOpsDisputeDetailScreen(
          dispute: {
            'id': '17',
            'orderId': '42',
            'itemTitle': 'Máy ảnh',
            'title': 'Hàng bị hư hỏng',
            'status': 'resolved',
            'source': 'bidder',
            'photos': [
              {'url': 'https://cdn.test/buyer.png', 'uploaderRole': 'bidder'},
              {'url': 'https://cdn.test/seller.png', 'uploaderRole': 'seller'},
              {'url': 'not a url', 'uploaderRole': 'warehouse'},
            ],
          },
        ),
      ),
    );
    await tester.pump();

    expect(find.text('Ảnh bằng chứng (2)'), findsOneWidget);
    expect(find.text('Người mua'), findsOneWidget);
    expect(find.text('Người bán'), findsOneWidget);
    expect(find.byType(Image), findsNWidgets(2));

    await tester.pumpWidget(const SizedBox.shrink());
  });
}
