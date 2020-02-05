/*
https://datafeed.dukascopy.com/datafeed/{PAIR}/{YEAR}/{MONTH}/{DAY}/{HOUR}h_ticks.bi5
{PAIR} is the currency pair, for example "AUDUSD", "EURUSD", or "USDJPY"
{YEAR} is the year, for example "2010", "2014", or "2017"
{MONTH} is the month, a two digit number. For some reason, months are zero-indexed. For example, "00" corresponds to January, "05" is June, "11" is December.
{DAY} is the day of the month, and as far as I can tell, it is NOT zero-indexed. Again, it is two digits wide.
{HOUR} is the hour of the day. For some reason, Dukascopy stores each hour of the day separately. It is zero-indexed, so "00" to "23"

[ TIME  ] [ ASKP  ] [ BIDP  ] [ ASKV  ] [ BIDV  ]
0000 0800 0002 2f51 0002 2f47 4096 6666 4013 3333

TIME is a 32-bit big-endian integer representing the number of milliseconds that have passed since the beginning of this hour.
ASKP is a 32-bit big-endian integer representing the asking price of the pair, multiplied by 100,000.
BIDP is a 32-bit big-endian integer representing the bidding price of the pair, multiplied by 100,000.
ASKV is a 32-bit big-endian floating point number representing the asking volume, divided by 1,000,000.
BIDV is a 32-bit big-endian floating point number representing the bidding volume, divided by 1,000,000.
*/

import 'dart:typed_data';
import 'package:http/http.dart' as http;
import 'package:lzma/lzma.dart';
import 'package:sprintf/sprintf.dart';

String buildUrl(String pair, int year, int month, int day, int hour) {
  const bi5url =
      'https://datafeed.dukascopy.com/datafeed/%s/%04i/%02i/%02i/%02ih_ticks.bi5';
  return sprintf(bi5url, [pair, year, month - 1, day, hour]);
}

String buildUrlFromLocalTime(String pair, DateTime localTime) {
  var utc = localTime.toUtc();
  return buildUrlFromUtcTime(pair, utc);
}

String buildUrlFromUtcTime(String pair, DateTime utc) {
  return buildUrl(pair, utc.year, utc.month, utc.day, utc.hour);
}

class Bi5Data {
  DateTime time;
  double ask;
  double bid;
  int askVol;
  int bidVol;

  Bi5Data(DateTime utcTime, int t, double a, double b, int av, int bv) {
    time = utcTime.add(Duration(milliseconds: t));
    ask = a;
    bid = b;
    askVol = av;
    bidVol = bv;
  }

  @override
  String toString() {
    var buffer = StringBuffer();
    buffer.writeAll([time, ask, bid, askVol, bidVol], ',');
    return buffer.toString();
  }
}

const currencyMap = <String, double>{
  'JPY': 1000.0,
  'RUB': 1000.0,
  'XAU': 1000.0,
  'XAG': 1000.0
};

const defaultPoint = 100000.0;

double getSymbolPoint(String symbol) {
  var upperSymbol = symbol.toUpperCase();
  var point;
  for (var key in currencyMap.keys) {
    if (upperSymbol.contains(key)) {
      point = currencyMap[key];
      break;
    }
  }
  point ??= defaultPoint;
  return point;
}

Bi5Data decode(ByteData bi5data, int offset, DateTime utcHour, double point) {
  var time = bi5data.getUint32(offset + 0);
  var ask = bi5data.getUint32(offset + 4) / point;
  var bid = bi5data.getUint32(offset + 8) / point;
  var askVol = (bi5data.getFloat32(offset + 12) * 10000000).round();
  var bidVol = (bi5data.getFloat32(offset + 16) * 10000000).round();

  return Bi5Data(utcHour, time, ask, bid, askVol, bidVol);
}

DateTime normalizationDateTime(DateTime utc) {
  return DateTime.utc(utc.year, utc.month, utc.day, utc.hour);
}

List<Bi5Data> decodeBi5Buffer(Uint8List bytes, String pair, DateTime start) {
  var utcTime = normalizationDateTime(start);
  var decodeBytes = lzma.decode(bytes);
  var list = Uint8List.fromList(decodeBytes);
  var bi5data = ByteData.view(list.buffer);
  if (bi5data.lengthInBytes % 20 == 0) {
    // invalid buffer
    // may be throw error?
    return null;
  }
  var point = getSymbolPoint(pair);
  var offset = 0;
  var length = bi5data.lengthInBytes;
  var bi5list = <Bi5Data>[];
  while (offset < length) {
    var tick = decode(bi5data, offset, utcTime, point);
    bi5list.add(tick);
    offset += 20;
  }
  return bi5list;
}

Future<List<Bi5Data>> getTicks(String pair, DateTime utc) async {
  var _client = http.Client();
  try {
    var url = buildUrl(pair, utc.year, utc.month, utc.day, utc.hour);
    var bytes = await _client.readBytes(url);
    return decodeBi5Buffer(bytes, pair, utc);
  } catch (e) {
    print(e);
    return null;
  } finally {
    _client.close();
  }
}
