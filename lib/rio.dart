library rio;

import 'dart:io';
import 'dart:convert';
import 'dart:async';
import 'package:hub/hub.dart';
import 'package:bass/bass.dart';

abstract class RioView{
  Future render(d,HttpResponse r,[dynamic m]);
}

class RioFile extends RioView{
  static create() => new RioFile();
  Future render(d,r,[m]){
     var ff = d is Uri ? new File.fromUri(d) : new File(d);
     return ff.exist().then((c){
        ff.openRead()
         .transform(UTF8.decoder)
         .stream(r);
       return ff;
     })
  }
}

class RioDefferedFile extends RioView{
  static create() => new RioDefferedFile();
  Future render(d,r,[m]){
     var data = [],f = new Completer() , ff = d is Uri ? new File.fromUri(d) : new File(d);
     ff.exist().then((c){
        ff.openRead()
         .transform(UTF8.decoder)
         .listen((r){
           data.push(r);
         },onDone:(){
             f.complete(data.join(''));
         },onError:(e){
             f.completeError(e);
         });
     });
     return f.future;
  }
}

class RioText extends RioView{
  static create() => new RioText();
  Future render(d,r,[m]){
    var pd = Funcs.prettyPrint(d);
    r.write(pd);
    return new Future.value(d);
 }
}

class RioHtml extends RioView{
  static create() => new RioHtml();
  Future render(w,r,[m]){
     var d = w.replaceAll(r'\n','\\n').
      replaceAll(r'\r','\\r').
      replaceAll(r"'","\\").
      replaceAll(r"/&","&amp").
      replaceAll(r'<','&lt;').
      replaceAll(r'>','&gt;').
      replaceAll(r'>','&gt;').
      replaceAll(r'\"','%quot;');
      r.write(d);
    return new Future.value(d);
  }
}

class RioBassSVG extends RioView{
  final SVG ink = SVG.create();
  static create() => new RioBassSVG();
  Future render(g,r,[m]){
    this.ink.clear();
    this.ink.bindOnce((m) => r.write(m['markup']));
    this.ink.sel('svg',g);
    this.ink.compile();
    return new Future.value(null);
  }
}

class RioBassHtml extends RioView{
  final HTML markup = SVG.create();
  static create() => new RioBassHtml();
  Future render(g,r,[m]){
    this.markup.clear();
    this.markup.bindOnce((m) => r.write(m['markup']));
    this.markup.sel('HTML',g);
    this.markup.compile();
    return new Future.value(null);
  }
}

class Rio{
  HttpRequest _req;
  MapDecorator _builds;
  MapDecorator headers;
  Distributor _readydist;

  static MapDecorator ViewRenderers = MapDecorator.useMap({
    'html': RioHtml.create(),
    'text': RioText.create(),
    'bassSvg': RioBassSVG.create(),
    'bassHtml': RioBassHtml.create(),
    'file': RioFile.create(),
    'dfile': RioDefferedFile.create()
  });

  static create() => new Rio();
  Rio(){
    this._builds = MapDecorator.create();
    this.headers = MapDecorator.create();
    this._readydist = Distributor.create('readylist');
    this._readydist.on((n){});
    this._readydist.whenDone((n){
        this.res.close();
    });
  }

  void use(HttpRequest r){
    this.reset();
    this._req = r;
    this._req.headers.forEach((k,v){
       this.set(k,v);
    });
  }

  void reset(){
    this._req = null;
    this._builds.clear();
    this.headers.clear();
  }

  dynamic get req => this._req;
  dynamic get res => this._req.response;

  void build([Function g]){
    this._builds.clear();
    Enums.eachAsync(this.headers.core,(e,i,o,fn){

      Funcs.when(Valids.notCollection(e),(){
        this._builds.update(i,e);
      });

      Funcs.when(Valids.isCollection(e),(){

        Funcs.when(Valids.isMap(e),(){
          var val = new StringBuffer();

          Enums.eachAsync(e,(f,h,b,gn){
             val.write("$h=$f");
             return gn(null);
          },(_,err){
            this._builds.update(i,val.toString());
          });

       });

       Funcs.when(Valids.isList(e),(){
          this._builds.update(i,e.join(';'));
       });

      });

      return fn(null);
    },(_,err){
       Valids.exist(g) && g(new Map.from(this._builds.core));
    });
  }

  Map get heads {
    var vals = {};
    this.build((n){
      vals.addAll(n);
    })
    return vals;
  }

  void _modHeaders(String n,dynamic vals,[Function before]){
    if(Valids.exist(before)) before(this.headers);
    Funcs.when(Valids.notCollection(vals),(){
      this.headers.update(n,vals);
    });
    Funcs.when(Valids.isCollection(vals),(){
      Funcs.when(Valids.isMap(vals),(){
        var m = Funcs.switchUnless(this.headers.get(n),{});
        this.headers.update(n,(Enums.merge(m,vals)));
      });
      Funcs.when(Valids.isList(vals),(){
        var m = Funcs.switchUnless(this.headers.get(n),[]);
        m.addAll(vals);
        this.headers.update(n,m);
      });
    });
  }

  void blow(String n) => this.headers.update(n,null);
  void mod(String n,vals) => this._modHeaders(n,vals);
  void set(String n,vals) => this._modHeaders(n,vals,(v) => v.destroy(n));
  dynamic get(String n) => this.headers.get(n);
  dynamic get info => this.res.connectionInfo;
  dynamic get views => Rio.ViewRenderers;

  Future send(dynamic m,[String n,dynamic data]){
    var comp = new Completer();
    n = Funcs.switchUnless(n,'text');
    var rv = this.views.has(n) ? this.views.get(n) : this.views.get('text');
    this._readydist.once((f){ 
      rv.render(m,this.res,data).then((f) => comp.complete(f),onError:(e) => comp.completeError(e))
      .catchError((e) => comp.completeError(e));
    });
    return comp.future;
  }

  Future sendView(String path,dynamic model,String view){
    if(this.views.has(view)) return this.send(path,view,model);
    return new Future.value(null);
  }

  Future sendText(String n) => this.send(n,'text');
  Future sendHtml(String n) => this.send(n,'html');
  Future sendFile(String n) => this.send(n,'file');
  Future sendHttpFile(Uri n) => this.send(n,'file');
  Future useFile(String n) => this.send(n,'dfile');
  Future useHttpFile(Uri n) => this.send(n,'dfile');

  dynamic end(){
    this.build((n){
      Enums.eachAsync(n,(e,i,o,fn){
        this.res.headers.set(i,e);
        return fn(null);
      },(_,err){
        this._readydist.emit(true);
      });
    });
  }

}
