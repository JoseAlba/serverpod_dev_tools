# Serverpod DevTools Example Application

This example demonstrates how to integrate and use [`serverpod_dev_tools`](https://pub.dev/packages/serverpod_dev_tools) within a Serverpod application.

## 📁 Project Structure

```
example/
├── example_client/       # Serverpod client package
├── example_server/       # Serverpod server package (with serverpod_dev_tools integrated)
│   ├── config/           # Serverpod configuration files (development, production)
│   ├── http/             # Sample .http files scanned by DevTools HTTP Suite
│   │   ├── greeting.http
│   │   └── dev_tools.http
│   ├── lib/
│   │   ├── server.dart   # Server entrypoint with ServerpodDevTools.initialize(pod)
│   │   └── src/
│   │       ├── greetings/ # Default greetings endpoint & model
│   │       └── models/    # Sample models with relations (Author & Article)
│   └── pubspec.yaml
└── pubspec.yaml          # Monorepo workspace pubspec
```

## 🚀 How to Run the Example

### 1. Start the Serverpod Server

From the `example/example_server` directory:

```bash
cd example/example_server
dart run bin/main.dart
# or if you have the serverpod CLI installed:
serverpod start
```

When started, Serverpod will launch:
- Main RPC Server on port `8080`
- Insights & WebServer on port `8082`

`ServerpodDevTools.initialize(pod)` mounts the DevTools REST fallback endpoints at:
`http://localhost:8082/serverpod_dev_tools/api/**`

### 2. Open Serverpod DevTools

1. Open Dart DevTools in VS Code (Command Palette: `Dart: Open DevTools`) or Chrome.
2. Connect to the running Serverpod instance using the VM Service URI (printed in the terminal or saved in `example/example_server/.dart_tool/serverpod/vm-service-info.pod.json`).
3. Select the **Serverpod DevTools** extension tab.

### 3. Explore Features

- **ER Schema Visualizer**: View the entity relationship diagram for `Author`, `Article`, and `Greeting`.
- **Live DB Inspector**: Browse live database tables, filter rows, and inspect columns.
- **Endpoint Explorer**: Inspect and call `GreetingEndpoint` RPC methods directly from DevTools.
- **HTTP Workspace Suite**: View and execute the requests in `http/greeting.http` and `http/dev_tools.http`.
- **Mock Data Generator**: Generate mock fixtures in topological order (`Author` before `Article`).
