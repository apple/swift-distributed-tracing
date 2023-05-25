## Tracing Dinner Sample App

In order to try this sample app, and visualize traces it produces, you should first run `docker-compose` in order
to launch a docker containers which host a Zipkin UI and collector:

```
# cd Samples/Dinner

docker-compose -f docker/docker-compose.yaml up --build
```

and then run the sample app which will produce a number of traces:

```
swift run -c release
```

Refer to the "Trace Your Application" guide in the documentation to learn more about how to interpret this sample.