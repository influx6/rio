library spec;

import 'dart:io';
import 'dart:async';
import 'package:rio/rio.dart';
import 'package:hub/hub.dart';

void main(){


   HttpServer.bind('127.0.0.1',3000).then((s){
       var req = Rio.create();
      
       req.onDefault('head',(r) => req.end());
       req.onDefault('get',(r) => req.end());
       req.onDefault('put',(r) => req.end());
       req.onDefault('delete',(r) => req.end());
       req.onDefault('post',(r) => req.end());

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

       s.listen((r){
          req.use(r);
       });
   });
   
}
