import 'package:flutter_test/flutter_test.dart';
import 'package:askopdf_view/main.dart';

void main() {
  testWidgets('App starts', (tester) async {
    await tester.pumpWidget(const PdfViewer());
    expect(find.text('Open PDF'), findsOneWidget);
  });
}
