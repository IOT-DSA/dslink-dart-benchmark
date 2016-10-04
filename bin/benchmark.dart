import "dart:async";

import "package:args/args.dart";
import "package:dslink/dslink.dart";
import 'dart:io';
import 'requester.dart';
import 'responder.dart';

main(List<String> args) async {
  var benchmarkResponder = new BenchmarkResponder([
    '--broker',
    'http://localhost:8080/conn',
    '--nodes=10',
    '--metrics=10',
    '--interval=10',
    '--type=1'
  ]);

  var benchmarkRequester = new BenchmarkRequester([
    '--broker',
    'http://localhost:8080/conn',
    '--sample 1000'
    '--path /downstream/Benchmark'
  ]);

  print("starting responder");
  await benchmarkResponder.start();
  print("starting requester");
  await benchmarkRequester.start();
  print("started");
}
