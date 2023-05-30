import 'package:args/command_runner.dart';
import 'package:ok_ziggy/ok_ziggy.dart';

void main(List<String> arguments) async {
  CommandRunner("ziggy",
      "A dynamic proxy, enabling seamless interaction with multiple services via OpenAPI Specification.")
    ..addCommand(RunProxyCommand())
    ..run(arguments);
}

class RunProxyCommand extends Command {
  @override
  String get description => "Starts the Ok Ziggy Server";

  @override
  String get name => "start";

  RunProxyCommand() {
    argParser.addOption('port',
        abbr: 'p', defaultsTo: "8080", help: "server port");
    argParser.addOption('scheme',
        defaultsTo: "http", help: "protocol: http or https");
    argParser.addOption('host');
    argParser.addOption('dataDir', defaultsTo: "data");
  }

  @override
  Future<void> run() async {
    final port = int.parse(argResults?["port"]);
    final scheme = argResults?["scheme"];
    final host = argResults?["host"] ?? "localhost:$port";
    final dataDir = argResults?["dataDir"];
    ;
    runServer(scheme, host, port, dataDir);
  }
}
