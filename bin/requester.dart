import "dart:async";

import "package:args/args.dart";
import "package:dslink/dslink.dart";

class BenchmarkRequester {
  int sampleRate;
  String path = "/downstream/Benchmark";
  String rid;
  bool silent = false;
  Requester requester;
  LinkProvider link;
  Function doSample;

  BenchmarkRequester(args, {Function doSample : null}) {
    this.doSample = doSample;
    var argp = new ArgParser();
    argp.addOption("path", help: "Responder Path", defaultsTo: "/downstream/Benchmark");
    argp.addOption("sample", help: "Sample Rate", defaultsTo: "1000");
    argp.addOption("id", help: "Requester ID");
    argp.addFlag("silent", help: "Silent Mode", defaultsTo: false);

    this.link = new LinkProvider(args, "Benchmarker-", isRequester: true, isResponder: true, defaultNodes: {
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
      this.path = opts["path"];
      this.sampleRate = int.parse(opts["sample"]);
      this.rid = opts["id"];
      this.silent = opts["silent"];
    });

    link.init();
  }

  Future start() async {
    link.connect();
    requester = await link.onRequesterReady;
    RemoteNode watchNode = await getRemoteNode(path);

    var count = 0;
    var nc = 0;
    var mc = 0;

    var paths = [];

    // asdf
    print("DEBUG: child node is ${watchNode.remotePath}");
    print("DEBUG: path is ${path}");
    nc = await getNodeValue(watchNode.remotePath + "/Node_Count");
    print("DEBUG1");
    mc = await getNodeValue(watchNode.remotePath + "/Metrics_Count");
    print("DEBUG2");
    for (var a = 1; a <= nc; a++) {
      for (var b = 1; b <= mc; b++) {
        print("DEBUG3");
        paths.add(watchNode.remotePath + "/Node_${a}/Metric_${b}");
      }
    }

    mc = paths.length;

    print("Metrics Count: ${mc}");

    for (String path in paths) {
      print("Subscribing to $path");
      requester.subscribe(path, (ValueUpdate update) {
        count++;
      });
    }

    Scheduler.every(new Interval.forMilliseconds(sampleRate), () {
      this.sample(count, mc);
    });
  }

  void sample(int count, int metricsCount)
  {
    if (doSample != null)
    {
      doSample();
      return;
    }

    var c = count;
    count = 0;
    if (!silent) {
      if (rid != null) {
        print("${rid} - Count: ${c}");
        print("${rid} - Percentage: ${c / metricsCount}");
      } else {
        print("Count: ${c}");
        print("Percentage: ${c / metricsCount}");
        if (doSample != null)
          doSample();
      }
    }

    link.val("/Count", c);
    link.val("/Percentage", ((c / metricsCount) * 10).clamp(0, 100));
  }

  Future<RemoteNode> getRemoteNode(String path) async {
    return (await requester.list(path).first).node;
  }

  Future<Object> getNodeValue(String path) async {
    var c = new Completer<Object>();
    ReqSubscribeListener l;
    l = requester.subscribe(path, (ValueUpdate update) {
      c.complete(update.value);
      l.cancel();
    });
    return await c.future;
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
}

main(List<String> args) async {
  var br = new BenchmarkRequester(args);
  br.start();
}
