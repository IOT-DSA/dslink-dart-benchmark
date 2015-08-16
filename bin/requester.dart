import "dart:async";

import "package:args/args.dart";
import "package:dslink/dslink.dart";

LinkProvider link;
Requester r;
String benchmarkPath;
int sampleRate;
String rid;
bool silent = false;

main(List<String> args) async {
  var argp = new ArgParser();
  argp.addOption("path", help: "Responder Path", defaultsTo: "/conns");
  argp.addOption("sample", help: "Sample Rate", defaultsTo: "1000");
  argp.addOption("id", help: "Requester ID");
  argp.addFlag("silent", help: "Silent Mode", defaultsTo: false);

  link = new LinkProvider(args, "Benchmarker-", isRequester: true, isResponder: true, defaultNodes: {
    "Count": {
      r"$type": "int",
      "?value": 0
    },
    "Percentage": {
      r"$type": "number",
      "?value": 0,
      "@unit": "%"
    }
  }, autoInitialize: false);

  link.configure(argp: argp, optionsHandler: (opts) {
    benchmarkPath = opts["path"];
    sampleRate = int.parse(opts["sample"]);
    rid = opts["id"];
    silent = opts["silent"];
  });

  link.init();
  link.connect();
  r = await link.onRequesterReady;

  Map<String, RemoteNode> nodes = await getRemoteNodeRecursive(benchmarkPath, ignore: (String path) {
    return path.startsWith("/conns/rnd");
  });
  List<RemoteNode> metrics = nodes.values.where((x) => x.configs.containsKey(r"$type")).toList();

  var count = 0;
  var mc = 0;

  for (RemoteNode metric in metrics) {
    var path = new Path(metric.remotePath);
    if (metric.remotePath.startsWith("/conns/Benchmark-") && path.name.startsWith("Metric_") && path.name != "Metric_Count") {
      mc++;
      r.subscribe(metric.remotePath, (ValueUpdate update) {
        count++;
      });
    }
  }

  Scheduler.every(new Interval.forMilliseconds(sampleRate), () {
    var c = count;
    count = 0;
    if (!silent) {
      if (rid != null) {
        print("${rid} - Count: ${c}");
        print("${rid} - Percentage: ${c / mc}");
      } else {
        print("Count: ${c}");
        print("Percentage: ${c / mc}");
      }
    }

    link.val("/Count", c);
    link.val("/Percentage", (c / mc) * 10);
  });
}

Future<Map<String, RemoteNode>> getRemoteNodeRecursive(String path, {bool ignore(String path)}) async {
  if (ignore != null) {
    var result = ignore(path);
    if (result) {
      return {};
    }
  }

  var root = await getRemoteNode(path);
  var map = {};
  map[path] = root;

  for (RemoteNode child in root.children.values) {
    map.addAll(await getRemoteNodeRecursive(child.remotePath, ignore: ignore));
  }

  return map;
}

Future<RemoteNode> getRemoteNode(String path) async {
  return (await r.list(path).first).node;
}


