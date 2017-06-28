# Benchmark DSLink

This is a DSLink for measuring DSA performance.

## Usage

Run Responder:

```
dart bin/responder.dart -b http://127.0.0.1:8080/conn --name Benchmark-1 --nodes=20 --metrics=20 --interval=10
```

to start multiple responder, use a different name for each responder.  the name needs to start with `Benchmark-` otherwise the requester won't listen to it.


Run Requester:

```
dart bin/requester.dart -b http://127.0.0.1:8080/conn --path /downstream/Benchmark --sample 1000
```



## Results

The requester will give you the total number of value updates received within the sample interval.

