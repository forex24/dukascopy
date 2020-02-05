import 'package:dukascopy/dukascopy.dart';
import 'package:test/test.dart';

void main() {
  test('getSymbolPoint', () {
    expect(getSymbolPoint('USDJPY'), 1000.0);
    expect(getSymbolPoint('XAUUSD'), 1000.0);
    expect(getSymbolPoint('XAGUSD'), 1000.0);
    expect(getSymbolPoint('USDRUB'), 1000.0);
    expect(getSymbolPoint('EURUSD'), 100000.0);
  });
}
