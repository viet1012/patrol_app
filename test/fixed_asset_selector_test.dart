import 'package:chuphinh/fixedAsset/widgets/fixed_asset_selector.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

class _FakeController extends ChangeNotifier {
  String location = 'A35';
  int summaryVersion = 0;
  final Set<String> audited = <String>{};

  void touch() => notifyListeners();
}

void main() {
  testWidgets('rebuilds only when the selected snapshot changes', (
    tester,
  ) async {
    final c = _FakeController();
    addTearDown(c.dispose);
    var locationBuilds = 0;
    var auditedBuilds = 0;

    await tester.pumpWidget(
      Directionality(
        textDirection: TextDirection.ltr,
        child: Column(
          children: <Widget>[
            FixedAssetSelector(
              listenable: c,
              select: () => (location: c.location),
              builder: (context, v) {
                locationBuilds++;
                return Text(v.location);
              },
            ),
            FixedAssetSelector(
              listenable: c,
              select: () => (set: c.audited, count: c.audited.length),
              builder: (context, v) {
                auditedBuilds++;
                return Text('${v.count}');
              },
            ),
          ],
        ),
      ),
    );
    expect(locationBuilds, 1);
    expect(auditedBuilds, 1);

    // Unrelated notification: nobody rebuilds.
    c.summaryVersion++;
    c.touch();
    await tester.pump();
    expect(locationBuilds, 1);
    expect(auditedBuilds, 1);

    // Relevant change: only that section rebuilds.
    c.location = 'A31';
    c.touch();
    await tester.pump();
    expect(locationBuilds, 2);
    expect(auditedBuilds, 1);
    expect(find.text('A31'), findsOneWidget);

    // In-place Set mutation is caught through the length field.
    c.audited.add('mc-001');
    c.touch();
    await tester.pump();
    expect(auditedBuilds, 2);
    expect(locationBuilds, 2);
    expect(find.text('1'), findsOneWidget);
  });
}
