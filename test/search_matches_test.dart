import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:asko_pdf/gelide/gelide.dart';
import 'package:asko_pdf/services/gelide_pdf_engine.dart';

SearchMatch _match(int start, int end) => SearchMatch(
  text: 'aa',
  startIndex: start,
  endIndex: end,
  rects: [Rect.fromLTRB(start / 100, 0.1, end / 100, 0.12)],
);

void main() {
  test('overlapping matches are not counted twice', () {
    final results = nonOverlappingSearchMatches(3, [
      _match(25, 27),
      _match(26, 28),
      _match(27, 29),
    ]);

    expect(results.length, 2);
    expect(results.first.rects.first.left, 0.25);
    expect(results.last.rects.first.left, 0.27);
    expect(results.every((match) => match.pageIndex == 3), isTrue);
  });

  test('separate matches are all kept in page order', () {
    final results = nonOverlappingSearchMatches(0, [
      _match(40, 42),
      _match(10, 12),
      _match(20, 22),
    ]);

    expect(
      results.map((match) => match.rects.first.left).toList(),
      [0.1, 0.2, 0.4],
    );
  });
}
