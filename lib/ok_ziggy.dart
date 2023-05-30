import 'dart:convert';
import 'dart:io';

import 'package:http/http.dart' as http;
import 'package:shelf/shelf.dart' as shelf;
import 'package:shelf/shelf.dart';
import 'package:shelf/shelf_io.dart' as io;
import 'package:shelf_cors_headers/shelf_cors_headers.dart';
import 'package:shelf_static/shelf_static.dart';

Future<void> runServer(scheme, host, port, dataDir) async {
  final overrideHeaders = {
    ACCESS_CONTROL_ALLOW_ORIGIN: 'https://chat.openai.com',
    ACCESS_CONTROL_ALLOW_METHODS: 'GET,POST,DELETE,PUT,OPTIONS',
    ACCESS_CONTROL_ALLOW_HEADERS: "*"
  };
  final catalogDir = "$dataDir/catalog";
  final metaDir = "$dataDir/meta";
  final publicDir = "$dataDir/public";
  final serviceMapFile = File('$catalogDir/domain-map.json');
  final serviceIdMap = await readMap(serviceMapFile);
  final contentTypesFile = File('$catalogDir/content-types.json');
  final contentTypesMap = await readMap(contentTypesFile);
  final proxyMapFile = File('$catalogDir/api-map.json');
  final proxyMap = await readMap(proxyMapFile);
  final staticHandler =
      createStaticHandler(publicDir, defaultDocument: 'index.html');

  final handler = const shelf.Pipeline()
      .addMiddleware(shelf.logRequests())
      .addMiddleware(corsHeaders(headers: overrideHeaders))
      .addHandler(RequestHandler(
        serviceIdMap: serviceIdMap,
        proxyMap: proxyMap,
        contentTypes: contentTypesMap,
        catalogDir: catalogDir,
        metaDir: metaDir,
        host: host,
        scheme: scheme,
        staticHandler: staticHandler,
      ).handle);

  final ip = InternetAddress.anyIPv4;
  final server = await io.serve(handler, ip, port);
  print('Server listening on port ${server.port}');
}

Future<Map<String, dynamic>> readMap(file) async {
  if (!await file.exists()) {
    throw Exception('Map file does not exist! ${file.path}');
  }
  String contents = await file.readAsString();
  return json.decode(contents);
}

class RequestHandler {
  final Map<String, dynamic> serviceIdMap;
  final Map<String, dynamic> proxyMap;
  final Map<String, dynamic> contentTypes;
  final String catalogDir;
  final String metaDir;
  final String host;
  final String scheme;
  final Handler staticHandler;

  RequestHandler(
      {required this.serviceIdMap,
      required this.proxyMap,
      required this.contentTypes,
      required this.catalogDir,
      required this.metaDir,
      required this.host,
      required this.scheme,
      required this.staticHandler});

  Future<shelf.Response> handle(shelf.Request request) async {
    final path = request.url.path;
    if (request.method == 'OPTIONS') {
      return shelf.Response.ok(null, headers: {});
    } else if (path.startsWith('api/v1/proxy')) {
      return createProxyResponse(request);
    } else if (path.startsWith("api/v1/specs")) {
      final serviceId = request.url.pathSegments.last;
      return createSpecsResponse(serviceId);
    } else if (path.startsWith("api/v1/services")) {
      return createServicesResponse();
    } else if (path.endsWith("ai-plugin.json")) {
      return createManifestResponse();
    } else if (path.endsWith("openapi.yaml")) {
      return createSpecResponse();
    } else {
      return staticHandler(request);
    }
  }

  Future<shelf.Response> createProxyResponse(request) async {
    try {
      return proxyHandler(request);
    } catch (e) {
      print(request.readAsString());
      return shelf.Response(400,
          body: 'Invalid JSON format: ${request.readAsString()}');
    }
  }

  Future<shelf.Response> createSpecsResponse(serviceId) async {
    final domain = serviceIdMap[serviceId];
    final specFileJson = File("$catalogDir/specs/$domain.json");
    final specFileYaml = File("$catalogDir/specs/$domain.yaml");

    if (specFileJson.existsSync()) {
      final body = await specFileJson.readAsString();
      return shelf.Response.ok(body,
          headers: {"content-type": "application/json"});
    } else if (specFileYaml.existsSync()) {
      final body = await specFileYaml.readAsString();
      return shelf.Response.ok(body, headers: {"content-type": "text/yaml"});
    } else {
      return shelf.Response.notFound('Spec not found');
    }
  }

  Future<shelf.Response> createServicesResponse() async {
    final file = File("$catalogDir/services.json");
    final body = await file.readAsString();
    return shelf.Response.ok(body,
        headers: {"content-type": "application/json"});
  }

  Future<shelf.Response> createSpecResponse() async {
    final properties = {"host": host, "scheme": scheme};
    final templateFile = File("$metaDir/openapi.yaml");
    final body = await writeTemplate(templateFile, properties);
    return shelf.Response.ok(body, headers: {"content-type": "text/yaml"});
  }

  Future<shelf.Response> createManifestResponse() async {
    final promptFile = File("$metaDir/prompt.txt");
    final prompt = await promptFile.readAsString();
    final cleanPrompt = prompt.replaceAll('\n', '').replaceAll('\r', '');
    final properties = {"host": host, "prompt": cleanPrompt, "scheme": scheme};
    final templateFile = File("$metaDir/ai-plugin.json");
    final body = await writeTemplate(templateFile, properties);
    return shelf.Response.ok(body,
        headers: {"content-type": "application/json"});
  }

  Future<shelf.Response> proxyHandler(shelf.Request request) async {
    final bodyStr = await request.readAsString();
    final body = json.decode(bodyStr);
    final serviceId = body['serviceId'];
    final httpMethod = body['httpMethod'];
    final operationPath = body['path'].replaceFirst(RegExp(r'^/'), '');
    final requestBody = body['requestBody'] ?? {};
    final operationId = body['operationId'] ?? '';
    final headers = Map<String, String>.from(body['headers'] ?? {});
    final contentType = contentTypes["$serviceId/$operationId"];
    if (contentType != null) {
      headers[HttpHeaders.contentTypeHeader] = contentType;
    }

    final specDomain = proxyMap[serviceId];
    if (specDomain == null) {
      return shelf.Response(404, body: 'Service not found: $serviceId');
    }

    final uri = Uri.parse("https://$specDomain/$operationPath");

    try {
      http.Response response;
      switch (httpMethod.toUpperCase()) {
        case 'GET':
          final encodedUri = Uri(
            scheme: uri.scheme,
            host: uri.host,
            pathSegments: uri.pathSegments,
            queryParameters: uri.queryParameters,
          );
          response = await http.get(encodedUri, headers: headers);
          break;
        case 'POST':
          response = await http.post(uri, headers: headers, body: requestBody);
          break;
        case 'PUT':
          response = await http.put(uri, headers: headers, body: requestBody);
          break;
        case 'DELETE':
          response = await http.delete(uri, headers: headers);
          break;
        default:
          print('Unsupported HTTP method $httpMethod');
          return shelf.Response(400, body: 'Unsupported HTTP method');
      }
      return shelf.Response(response.statusCode, body: response.body);
    } catch (e) {
      print('Failed to make a request to the service: $e');
      return shelf.Response.internalServerError(
          body: 'Failed to make a request to the service');
    }
  }

  Future<String> writeTemplate(templateFile, properties) async {
    final template = await templateFile.readAsString();
    return substituteTemplateProperties(template, properties);
  }

  RegExp placeholderPattern = RegExp(r'\$\{([^\}]+)\}');

  String substituteTemplateProperties(
      String template, Map<String, dynamic> templateProperties) {
    String modifiedTemplate = template.replaceAllMapped(placeholderPattern,
        (Match match) => (templateProperties[match[1]] ?? "").toString());
    return modifiedTemplate;
  }
}
