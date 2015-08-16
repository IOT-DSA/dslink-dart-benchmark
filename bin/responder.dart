import "dart:async";
import "dart:math";

import "package:args/args.dart";

import "package:dslink/dslink.dart";
import "package:dslink/nodes.dart";

LinkProvider link;

int current = 0;

main(List<String> args) {
  link = new LinkProvider(args, "Benchmark-", defaultNodes: {
    "Generate": {
      r"$invokable": "write",
      r"$is": "generate",
      r"$params": [
        {
          "name": "count",
          "type": "number",
          "default": 50
        }
      ]
    },
    "Reduce": {
      r"$invokable": "write",
      r"$is": "reduce",
      r"$params": [
        {
          "name": "target",
          "type": "number",
          "default": 1
        }
      ]
    },
    "Tick_Rate": {
      r"$name": "Tick Rate",
      r"$type": "number",
      r"$writable": "write",
      "?value": 300
    },
    "RNG_Maximum": {
      r"$name": "Maximum Random Number",
      r"$type": "number",
      r"$writable": "write",
      "?value": max
    },
    "Node_Count": {
      r"$name": "Node Count",
      r"$type": "number",
      "?value": 0
    },
    "Metrics_Count": {
      r"$name": "Metrics Count",
      r"$type": "number",
      "?value": 0
    }
  }, profiles: {
    "generate": (String path) => new SimpleActionNode(path, (Map<String, dynamic> params) {
      var count = params["count"] != null ? params["count"] : 50;
      generate(count);
    }),
    "reduce": (String path) => new SimpleActionNode(path, (Map<String, dynamic> params) {
      var target = params["target"] != null ? params["target"] : 1;
      for (var name in link["/"].children.keys.where((it) => it.startsWith("Node_")).toList()) {
        link.removeNode("/${name}");
      }
      generate(target);
    }),
    "test": (String path) {
      CallbackNode node;

      node = new CallbackNode(path, onCreated: () {
        nodes.add(node);
      }, onRemoving: () {
        nodes.remove(node);
      });

      return node;
    }
  }, autoInitialize: false, isRequester: true, isResponder: true);

  var argp = new ArgParser();
  var nodeCount = 0;
  var millis = 0;
  argp.addOption("nodes", help: "Node Count", defaultsTo: "10");
  argp.addOption("interval", help: "RNG Update Interval", defaultsTo: "10");
  argp.addOption("metrics", help: "Metrics Count", defaultsTo: "10");
  link.configure(argp: argp, optionsHandler: (opts) {
    nodeCount = int.parse(opts["nodes"]);
    millis = int.parse(opts["interval"]);
    rngPer = int.parse(opts["metrics"]);
  });

  link.init();

  link.onValueChange("/Tick_Rate").listen((ValueUpdate u) {
    if (schedule != null) {
      schedule.cancel();
      schedule = null;
    }

    schedule = Scheduler.every(new Interval.forMilliseconds(u.value), update);
  });

  link.onValueChange("/RNG_Maximum").listen((ValueUpdate u) {
    max = u.value;
  });

  generate(nodeCount);

  link.connect();

  link.val("/Tick_Rate", millis);
  link.val("/Metrics_Count", rngPer);

  schedule = Scheduler.every(new Interval.forMilliseconds(millis), update);

  print("Benchmark Configuration:");
  print("  ${nodeCount} nodes");
  print("  ${rngPer} metrics per node");
  print("  ${millis}ms update interval");
}

Timer schedule;
int max = 100;
int rngPer = 0;

void update() {
  nodes.forEach((node) {
    node.children.forEach((k, n) {
      if (n.hasSubscriber) {
        flag = !flag;
        n.updateValue(flag ? 1 : 0);
      }
    });
  });
}

bool flag = false;

Random random = new Random();
List<SimpleNode> nodes = [];

void generate(int count) {
  for (var i = 1; i <= count; i++) {
    var m = {
      r"$is": "test",
      r"$name": "Node ${i}"
    };

    for (var x = 1; x <= rngPer; x++) {
      m["Metric_${x}"] = {
        r"$name": "Metric ${x}",
        r"$type": "number"
      };
    }

    link.addNode("/Node_${i}", m);
    current++;
  }

  link.val("/Node_Count", nodes.length);
}
