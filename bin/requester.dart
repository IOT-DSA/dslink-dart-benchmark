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

  RemoteNode root = await getRemoteNode(benchmarkPath);
  List<RemoteNode> nodes = await Future.wait(root.children.values.map((RemoteNode x) => getRemoteNode(x.remotePath)));
  List<RemoteNode> metrics = await Future.wait(nodes
    .expand((RemoteNode n) => n.children.values.map(
      (RemoteNode c) => getRemoteNode(c.remotePath))));

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

Future<RemoteNode> getRemoteNode(String path) async {
  return (await r.list(path).first).node;
}


