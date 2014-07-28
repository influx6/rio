library spec;

import 'dart:io';
import 'dart:async';
import 'package:rio/rio.dart';
import 'package:hub/hub.dart';

void main(){


   HttpServer.bind('127.0.0.1',3000).then((s){
       var req = Rio.create();
      
       req.enableDefaults();
       req.on('get',(r){
          req.mod('Content-Type','text/html');
          req.sendHtml("""<html encoding='utf8'>
            <head>
              <title>Welcome to Rio (HttpRequest Scaffold)</title>
            </head>
            <body>
              <h1>Welcome To Rio</h1>
            </body>
          </html>""");

          req.end();
       });

       req.on('post',(r){
          req.getBody().then(Funcs.tag('body')).then((f){
            print('about to send out res');
            req.mod('Status-Code',200);
            req.mod('Content-Length',-1);
            req.send('ok!');
            req.end();
          });
       });

       s.listen((r){
          req.use(r);
       });
   });
   
}
