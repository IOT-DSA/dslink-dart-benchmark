import "dart:async";

import "package:args/args.dart";
import "package:dslink/dslink.dart";

LinkProvider link;
Requester r;
String benchmarkPath;
int sampleRate;

main(List<String> args) async {
  var argp = new ArgParser();
  argp.addOption("path", help: "Responder Path", defaultsTo: "/downstream/Benchmark");
  argp.addOption("sample", help: "Sample Rate", defaultsTo: "1000");

  link = new LinkProvider(args, "Benchmarker-", isRequester: true, isResponder: false);

  link.configure(argp: argp, optionsHandler: (opts) {
    benchmarkPath = opts["path"];
    sampleRate = int.parse(opts["sample"]);
  });

  link.init();
  link.connect();
  r = await link.onRequesterReady;

  Map<String, RemoteNode> nodes = await getRemoteNodeRecursive(benchmarkPath);
  List<RemoteNode> metrics = nodes.values.where((x) => x.configs.containsKey(r"$type")).toList();

  var count = 0;

  for (RemoteNode metric in metrics) {
    r.subscribe(metric.remotePath, (ValueUpdate update) {
      count++;
    });
  }

  Scheduler.every(new Interval.forMilliseconds(sampleRate), () {
    var c = count;
    count = 0;
    print("Count: ${c}");
  });
}

Future<Map<String, RemoteNode>> getRemoteNodeRecursive(String path) async {
  var root = await getRemoteNode(path);
  var map = {};
  map[path] = root;

  for (RemoteNode child in root.children.values) {
    map.addAll(await getRemoteNodeRecursive(child.remotePath));
  }

  return map;
}

Future<RemoteNode> getRemoteNode(String path) async {
  return (await r.list(path).first).node;
}


