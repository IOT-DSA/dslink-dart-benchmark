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

  RemoteNode conns = await getRemoteNode("/conns");
  List<RemoteNode> cn = conns.children.values.toList();

  var count = 0;
  var mc = 0;

  var paths = [];

  for (var n in cn) {
    if (!n.remotePath.startsWith("/conns/Benchmark-")) {
      continue;
    }

    var nc = await getNodeValue(n.remotePath + "/Node_Count");
    var mc = await getNodeValue(n.remotePath + "/Metrics_Count");
    for (var a = 1; a <= nc; a++) {
      for (var b = 1; b <= mc; b++) {
        paths.add(n.remotePath + "/Node_${a}/Metric_${b}");
      }
    }
  }

  mc = paths.length;

  print("Metrics Count: ${mc}");

  for (String path in paths) {
    r.subscribe(path, (ValueUpdate update) {
      count++;
    }, 1);
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
    link.val("/Percentage", ((c / mc) * 10).clamp(0, 100));
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

Future<Object> getNodeValue(String path) async {
  var c = new Completer<Object>();
  ReqSubscribeListener l;
  l = r.subscribe(path, (ValueUpdate update) {
    c.complete(update.value);
    l.cancel();
  });
  return await c.future;
}
