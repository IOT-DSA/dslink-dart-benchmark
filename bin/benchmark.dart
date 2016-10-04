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
    '--interval=10'
  ]);

  var benchmarkRequester = new BenchmarkRequester([
    '--broker',
    'http://localhost:8080/conn',
    '--sample 1000'
    '--path /downstream/Benchmark'
  ]);

  await benchmarkResponder.start();
  await benchmarkRequester.start();
}
