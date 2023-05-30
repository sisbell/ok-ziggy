A dynamic proxy, enabling seamless interaction with multiple services via 
OpenAPI Specification.


## Install This tool
Make sure your have dart installed. Follow the instructions, in the link below.

https://dart.dev/get-dart

After installation, you can install ziggy and ziggy tools with the following commands

> dart pub global activate ok_ziggy_tools

> dart pub global activate ok_ziggy

## Initialize Server Project
Go to the directory where you would like to initialize the chatbot server.

> zigt init

This will generate your server files under the data directory. For a more detailed
explanation of the file see the tools project: https://github.com/sisbell/ok-ziggy-tools

<img width="319" alt="project-setup" src="https://github.com/sisbell/ok-ziggy/assets/64116/af01316d-9f37-46f0-a1e4-1273be77152e">

## Running Chatbot Server
Run the **Ok Ziggy** server with the following command

> ziggy start

If you need to configure the startup

```
Starts the Ok Ziggy Server

Usage: ziggy start [arguments]
-h, --help       Print this usage information.
-p, --port       server port
                 (defaults to "8080")
    --scheme     protocol: http or https
                 (defaults to "http")
    --host       
    --dataDir    (defaults to "data")
```

Now go through the process of "Develop your own plugin" and installing it

<img width="864" alt="install-manifest" src="https://github.com/sisbell/ok-ziggy/assets/64116/bd8fadeb-7260-4afc-ac25-a3e539546cf6">

## Sample Chat
https://chat.openai.com/share/f56091cb-bfb2-461f-a82e-b5068003f32f


## Updating with new services
The _sample-domains.json_ file contains just 3 services but you can add a lot more.


```json
[
  "api.speak.com",
  "trip.com",
  "server.shop.app"
]
```
Just go to the following site and pick out what you like.
https://github.com/sisbell/chatgpt-plugin-store

<img width="268" alt="manifests" src="https://github.com/sisbell/ok-ziggy/assets/64116/0b57c884-ff49-416e-bb81-9526179ae198">

The domain names you need are right in the file name. so _agones.gr.json_ has a domain
name of *agones.gr*. Add it

```json
[
"api.speak.com",
"trip.com",
"server.shop.app",
"agones.gr"
]
```

Note before adding any service, go to the
manifest file and make sure that there is no authentication required. Also keep in
mind that not all services may work as expected so test them out.

```json
  "auth": {
    "type": "none"
  },
```
After adding, you need to regenerate the catalog.

> zigt create -i data/sample-domains.json

Now copy the new files into your catalog directory

> zigt copy

Restart your server

> ziggy start

Now you can see football results by asking Ziggy. 

<img width="653" alt="new-service" src="https://github.com/sisbell/ok-ziggy/assets/64116/9265a23f-68b9-480e-a464-840280d617ab">

Note: delete the build directory when deleting services.