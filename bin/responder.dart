import "dart:async";
import "dart:math";

import "package:args/args.dart";

import "package:dslink/dslink.dart";
import "package:dslink/nodes.dart";

class UpdateType {
  static const int IntegerFlip = 0;
  static const int JsonMessage = 1;
}

class BenchmarkResponder {
  int current = 0;
  int nodeCount = 0;
  int millis = 0;
  int updateType = UpdateType.IntegerFlip;
  LinkProvider link;
  Function update;

  // UpdateType specific variables
  bool flag = false;
  int counter = 0;

  BenchmarkResponder(List<String> args) {
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
    argp.addOption("nodes", help: "Node Count", defaultsTo: "10");
    argp.addOption("interval", help: "RNG Update Interval", defaultsTo: "10");
    argp.addOption("metrics", help: "Metrics Count", defaultsTo: "10");
    argp.addOption("type", help: "Update Type", defaultsTo: UpdateType.IntegerFlip.toString());
    link.configure(argp: argp, optionsHandler: (opts) {
      nodeCount = int.parse(opts["nodes"]);
      millis = int.parse(opts["interval"]);
      rngPer = int.parse(opts["metrics"]);
      updateType = int.parse(opts["type"]);
    });

    link.init();

    switch (this.updateType)
    {
      case UpdateType.JsonMessage:
        print("a");
        this.update = this.JsonMessage;
        break;
      case UpdateType.IntegerFlip:
      default:
        print("b");
        this.update = this.IntegerFlip;
      break;
    }

    link.onValueChange("/Tick_Rate").listen((ValueUpdate u) {
      if (schedule != null) {
        schedule.cancel();
        schedule = null;
      }

      schedule = Scheduler.every(new Interval.forMilliseconds(u.value), this.update);
    });

    link.onValueChange("/RNG_Maximum").listen((ValueUpdate u) {
      max = u.value;
    });

    generate(nodeCount);
  }

  Future start() async {
    link.connect();

    link.val("/Tick_Rate", millis);
    link.val("/Metrics_Count", rngPer);

    schedule = Scheduler.every(new Interval.forMilliseconds(millis), this.update);

    print("Benchmark Configuration:");
    print("  ${nodeCount} nodes");
    print("  ${rngPer} metrics per node");
    print("  ${millis}ms update interval");
  }

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

  Function JsonMessage()
  {
    Map message = {
      "msgNum": this.counter,
      "msg": randomString(64)
    };

    nodes.forEach((node) {
      node.children.forEach((k, n) {
        if (n.hasSubscriber) {
          n.updateValue(message);
        }
      });
    });

    counter++;
  }

  Function IntegerFlip()
  {
    flag = !flag;
    nodes.forEach((node) {
      node.children.forEach((k, n) {
        if (n.hasSubscriber) {
          n.updateValue(flag ? 1 : 0);
        }
      });
    });
  }
}

main(List<String> args) {
  var br = new BenchmarkResponder(args);
  br.start();
}

String randomString(int length) {
  var codeUnits = new List.generate(
      length,
      (index){
    return random.nextInt(33)+89;
  }
  );

  return new String.fromCharCodes(codeUnits);
}

Timer schedule;
int max = 100;
int rngPer = 0;

Random random = new Random();
List<SimpleNode> nodes = [];