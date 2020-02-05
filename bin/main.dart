import 'package:dukascopy/dukascopy.dart' as dukascopy;
import 'package:args/args.dart';

Future<int> main(List<String> arguments) async {
  var parser = ArgParser();
  parser.addOption('mode');
  parser.addFlag('verbose', defaultsTo: true);

  var results = parser.parse(arguments);
  print(results['mode']);
  print(results['verbose']);
  var time = DateTime.tryParse('20200204 01:00:00');
  var ticks = await dukascopy.getTicks('EURUSD', time);
  var head = ticks.sublist(0, 20);
  for (var tick in head) {
    print(tick);
  }
  return 0;
}
