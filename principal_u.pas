unit principal_u;

interface

uses
  Winapi.Windows, Winapi.Messages, System.SysUtils, System.Classes, Vcl.Graphics,
  Vcl.Controls, Vcl.SvcMgr, Vcl.Dialogs,
  System.Json,
  Horse,
  Horse.Compression,
  Horse.BasicAuthentication,
  Horse.Commons,
  Horse.Jhonson,
  Horse.CORS,
  Horse.HandleException,
  Data.DB,
  ZDatasetUtils,
  ZAbstractConnection,
  ZConnection,
  ZAbstractRODataset,
  ZAbstractDataset,
  ZDataset,
  ZEncoding,
  ZCompatibility,
  ZDbcIntfs,

  System.StrUtils,
  DataSet.Serialize,

  FireDAC.Stan.Intf, FireDAC.Stan.Option,
  FireDAC.Stan.Error, FireDAC.UI.Intf, FireDAC.Phys.Intf, FireDAC.Stan.Def,
  FireDAC.Stan.Pool, FireDAC.Stan.Async, FireDAC.Phys, FireDAC.VCLUI.Wait,
  FireDAC.Comp.Client ,
  FireDAC.Phys.FB, FireDAC.Phys.FBDef,
  FireDAC.Stan.Param,
  FireDAC.DatS, FireDAC.DApt.Intf, FireDAC.DApt, FireDAC.Comp.DataSet;


type
  Tprincipal_f = class(TService)
    db2: TFDConnection;
    FDTransaction1: TFDTransaction;
    procedure ServiceStart(Sender: TService; var Started: Boolean);
  private
    function abreConn: Boolean;
    function abreConn2: Boolean;
    { Private declarations }
  public
    function GetServiceController: TServiceController; override;
    { Public declarations }
  end;


var
  principal_f: Tprincipal_f;
  retorno, corpo, dados : TJSONObject;
  jArray : TJsonArray;
  vJson, vNome, codEmpresa, mensagem, vStr : String;
  qry3 : TZQuery;
  qry1, qry2: TFDQuery;
  idSE, historicoDias : Integer;
  vHandle: Thandle;
  log: TStrings;


implementation
uses funcoes;

{$R *.dfm}

procedure ServiceController(CtrlCode: DWord); stdcall;
begin
  principal_f.Controller(CtrlCode);
end;

function Tprincipal_f.GetServiceController: TServiceController;
begin
  Result := ServiceController;
end;

procedure Tprincipal_f.ServiceStart(Sender: TService; var Started: Boolean);
begin
  ArqIni := ExtractFilePath(ParamStr(0)) + 'apiDbAdm.ini';
  //log := TStringList.Create;

  try
    {fileStream := TFileStream.Create(ExtractFilePath(ParamStr(0)) + 'log-'+formatdatetime('yyyymmddhhnnss', now)+'.txt',
               fmCreate or fmOpenWrite or fmShareDenyNone);
    Writer := TWriter.Create(fileStream, $FF);}
    //AssignFile(log, ExtractFilePath(ParamStr(0)) + 'log-'+formatdatetime('yyyymmddhhnnss', now)+'.txt');
    //Rewrite(log);
    THorse.Use(Compression())
    .Use(Jhonson)
    .Use(HandleException)
    .Use(CORS);

    //db := TZConnection.Create(nil);
    //db2 := TFDConnection.Create(nil);

    //writeln(log, formatDateTime('dd/mm/yyyy hh:nn', now)+': ','Webservice inicado com sucesso !!!');

    THorse.Get('/api/clientes',
      procedure(req: THorseRequest; res: THorseResponse; Next: TProc)
      begin
        //log.add(formatDateTime('dd/mm/yyyy hh:nn', now)+': '+' metodo: clientes'+#13#10);
        try
          vNome := req.query['nome'];
        except
          vNome := '';
        end;

        abreConn2();
        db2.StartTransaction;
        qry1 := TFDQuery.Create(Nil);
        qry1.Connection := db2;
        qry1.Close;
        if vNome = '' then
        begin
          qry1.SQL.Text := 'select * from con_clifor order by razao_clifor';
        end
        else
        begin
          qry1.SQL.Text := 'select * from con_clifor where razao_clifor like ''%'+vNome+'%'' order by razao_clifor';
        end;
        try
          qry1.Open;
          jArray := qry1.ToJSONArray();
          res.Send(jArray);
          db2.Commit;
          qry1.close;
          freeAndNil(qry1);
          db2.Close;
          //res.Send(jArray);
        except on e : Exception do
          begin
            //log.add(formatDateTime('dd/mm/yyyy hh:nn', now)+': '+'erro: '+e.Message+#13#10);
          end
        end;

      end
    );

    THorse.Get('/api/clientes/:id',
      procedure(req: THorseRequest; res: THorseResponse; Next: TProc)
      begin
        //log.add(formatDateTime('dd/mm/yyyy hh:nn', now)+': '+'metodo: clientes/id'+#13#10);
        abreConn2();
        db2.StartTransaction;
        qry1 := TFDQuery.Create(Nil);
        qry1.Connection := db2;
        try
          qry1.Close;
          qry1.SQL.Text := 'select * from con_clifor where cod_clifor = '+req.Params['id'];
          qry1.Open;
          jArray := qry1.ToJSONArray();
          qry1.close;
          freeAndNil(qry1);
          db2.Commit;
          db2.Close;
          res.Send(jArray);
        except on e : Exception do
          begin
            //log.add(formatDateTime('dd/mm/yyyy hh:nn', now)+': '+'erro: '+e.Message+#13#10);
          end
        end;
      end
    );

    THorse.Post('/api/validausuario',
      procedure(req: THorseRequest; res: THorseResponse; Next: TProc)
      begin
        //log.add(formatDateTime('dd/mm/yyyy hh:nn', now)+': '+'metodo: validausuario'+#13#10);
        CodEmpresa := '1';
        mensagem   := '';
        retorno := TJSONObject.Create;
        vStr    := Req.Body;
        corpo   := TJSONObject.ParseJSONValue(vStr) as TJSONObject;
        //corpo.AddPair('body', Req.Body);
        abreConn2();
        //db2.StartTransaction;
        qry1 := TFDQuery.Create(Nil);
        qry1.Connection := db2;
        with qry1 do
        begin
          close;
          sql.clear;
          sql.add( 'select * from seg_usuario u '+
                   ' left join seg_departamento d on (u.cod_depto=d.cod_depto) '+
                   ' where u.apelido_usu = ' + #39 + ansiUpperCase(corpo.GetValue('username').Value) + #39 );
          open;
          if eof then
          begin
            mensagem := 'Usuario nao cadastrado, tente outro nome -> '+ corpo.GetValue('username').Value;
            retorno := TJSONObject.ParseJSONValue('{"dados": "", "status": "erro", "mensagem": "'+mensagem+'"}') as TJSONObject;
          end
          else if corpo.GetValue('password').Value = FieldByName('senha_usu').AsString then
          begin
            retorno := TJSONObject.ParseJSONValue('{"dados": { '+
                   '"codusuario": "'+FieldByName('cod_usu').asString+'", '+
                   '"emailusuario": "'+FieldByName('email_usu').asString+'", '+
                   '"nomeusuario": "'+FieldByName('nome_usu').asString+'", '+
                   '"deptousuario": "'+FieldByName('cod_depto').asString+'", '+
                   '"deptonome": "'+FieldByName('desc_depto').asString+'", '+
                   '"responsavel": "'+FieldByName('responsavel_usu').asString+'"'+
                   '}, "status": "ok", "mensagem": "Acesso Liberado"}') as TJSONObject;
          end
          else
          begin
            retorno := TJSONObject.ParseJSONValue('{"dados": "", "status": "erro", "mensagem": "Senha nao confere."}') as TJSONObject;
          end;
          close;
        end;
        freeAndNil(qry1);
        res.Send(retorno);
        //db2.commit;
        db2.Close;
      end
    );

    THorse.Get('/api/tiposservicosextras',
      procedure(req: THorseRequest; res: THorseResponse; Next: TProc)
      begin
        try
          //log.add(formatDateTime('dd/mm/yyyy hh:nn', now)+': '+'metodo: tiposservicosextras'+#13#10);
          abreConn2();
          //db2.StartTransaction;
          qry1 := TFDQuery.Create(Nil);
          qry1.Connection := db2;

          qry1.sql.clear;
          qry1.sql.add('select COD_AUX, CODIGO_AUX, DESC_AUX from con_auxiliar where tipo_aux = ' + #39 + 'TPSERVEXTR' + #39 );
          qry1.open;
          jArray := qry1.ToJSONArray();
          res.Send(jArray);
          qry1.close;
          freeAndNil(qry1);
          db2.Close;
        except on e : Exception do
          begin
            res.Send('erro: '+ e.Message + ' - '+ qry1.sql.Text + ' - banco: '+db2.Connected.ToString + ' Tabela: '+qry1.Active.ToString());
            //log.add(formatDateTime('dd/mm/yyyy hh:nn', now)+': '+'erro: '+e.Message+#13#10);
          end
        end;
      end
    );

    THorse.Post('/api/salvaservicoextra',
      procedure(req: THorseRequest; res: THorseResponse; Next: TProc)
      begin
        //log.add(formatDateTime('dd/mm/yyyy hh:nn', now)+': '+'metodo: SalvaServicoExtra'+#13#10);
        CodEmpresa := '1';
        mensagem   := '';
        retorno := TJSONObject.Create;
        vStr    := Req.Body;
        dados   := TJSONObject.ParseJSONValue(vStr) as TJSONObject;

        abreConn2();
        db2.StartTransaction;
        qry1 := TFDQuery.Create(Nil);
        qry1.Connection := db2;
        qry1.close;
        qry1.sql.Text := 'select max(idSE) as ultimoID from CON_SERVICOEXTRA';
        qry1.open;
        try
          idSE := qry1.fieldByName('ultimoID').AsInteger + 1;
        except
          idSE := 1;
        end;
        qry2 := TFDQuery.Create(Nil);
        qry2.Connection := db2;
        qry2.close;
        qry2.sql.Text := 'select * from CON_CLIFOR where cod_clifor = :cod_clifor';
        qry2.ParamByName('cod_clifor').asString := dados.GetValue('cliente').Value;
        qry2.open;
        vNome := qry2.fieldbyname('razao_clifor').asString;

        qry2.close;
        qry2.sql.Text := 'select COD_AUX, CODIGO_AUX, DESC_AUX from con_auxiliar where cod_aux = :idTpServ';
        qry2.ParamByName('idTpServ').asString := dados.GetValue('tpservico').Value;
        qry2.open;
        vStr := qry2.fieldbyname('desc_aux').asString;

        try
          qry1.close;
          qry1.sql.clear;
          qry1.sql.add('insert into CON_SERVICOEXTRA ('+
                  'IDSE, '+
                  'IDEMPRESA, '+
                  'IDCLIENTE, '+
                  'NMCLIENTE, '+
                  'IDTPSERVEXTR, '+
                  'NMTPSERVEXTR, '+
                  'DTSOLICITACAO, '+
                  'IDDEPTO, '+
                  'NMDEPTO, '+
                  'IDUSUARIO, '+
                  'NMUSUARIO, '+
                  'DESCDOC, '+
                  'VALORSERVICO, '+
                  'PORCDESCONTO, '+
                  'VALORCOBRACA, '+
                  'DETALHECOB, '+
                  'MOTIVOSERVICO, '+
                  'COBRARCLIENTE, '+
                  'IDSERVICO, '+
                  'NMSERVICO, '+
                  'IDUSUARIOAUTORIZOU, '+
                  'NMUSUARIOAUTORIZOU, '+
                  'DTAUTORIZACAO'+
                  ') values ( '+
                  ':IDSE, '+
                  ':IDEMPRESA, '+
                  ':IDCLIENTE, '+
                  ':NMCLIENTE, '+
                  ':IDTPSERVEXTR, '+
                  ':NMTPSERVEXTR, '+
                  ':DTSOLICITACAO, '+
                  ':IDDEPTO, '+
                  ':NMDEPTO, '+
                  ':IDUSUARIO, '+
                  ':NMUSUARIO, '+
                  ':DESCDOC, '+
                  ':VALORSERVICO, '+
                  ':PORCDESCONTO, '+
                  ':VALORCOBRACA, '+
                  ':DETALHECOB, '+
                  ':MOTIVOSERVICO, '+
                  ':COBRARCLIENTE, '+
                  ':IDSERVICO, '+
                  ':NMSERVICO, '+
                  ':IDUSUARIOAUTORIZOU, '+
                  ':NMUSUARIOAUTORIZOU, '+
                  ':DTAUTORIZACAO'+
                  ')');
          qry1.ParamByName('IDSE').asInteger              := idSE;
          qry1.ParamByName('IDEMPRESA').asString          := codEmpresa;
          qry1.ParamByName('IDCLIENTE').asString          := dados.GetValue('cliente').Value;
          qry1.ParamByName('NMCLIENTE').asString          := vNome;
          qry1.ParamByName('IDTPSERVEXTR').asString       := dados.GetValue('tpservico').Value;
          qry1.ParamByName('NMTPSERVEXTR').asString       := vStr;
          qry1.ParamByName('DTSOLICITACAO').asDateTime    := strToDate(dados.GetValue('dtsolicitacao').Value);
          qry1.ParamByName('IDDEPTO').asString            := dados.GetValue('deptousuario').Value;
          qry1.ParamByName('NMDEPTO').asString            := dados.GetValue('deptonome').Value;
          qry1.ParamByName('IDUSUARIO').asString          := dados.GetValue('codusuario').Value;
          qry1.ParamByName('NMUSUARIO').asString          := dados.GetValue('username').Value;
          qry1.ParamByName('DESCDOC').asString            := dados.GetValue('descdoc').Value;
          qry1.ParamByName('VALORSERVICO').asString       := dados.GetValue('valorservico').Value;
          qry1.ParamByName('PORCDESCONTO').asString       := dados.GetValue('desconto').Value;
          qry1.ParamByName('VALORCOBRACA').asString       := dados.GetValue('valcomdesconto').Value;
          qry1.ParamByName('DETALHECOB').asString         := dados.GetValue('detalhescob').Value;
          //qry1.ParamByName('MOTIVOSERVICO').asString      := dados.GetValue('').Value;
          qry1.ParamByName('COBRARCLIENTE').asString      := dados.GetValue('cobrarcliente').Value;
          qry1.ParamByName('IDSERVICO').asString          := dados.GetValue('tpservico').Value;
          //qry1.ParamByName('NMSERVICO').asString          := dados.GetValue('').Value;
          //qry1.ParamByName('IDUSUARIOAUTORIZOU').asString := dados.GetValue('').Value;
          //qry1.ParamByName('NMUSUARIOAUTORIZOU').asString := dados.GetValue('').Value;
          //qry1.ParamByName('DTAUTORIZACAO').asDateTime    := null;
          qry1.ExecSQL;
          qry1.close;
          qry1.sql.Text := 'select * from CON_SERVICOEXTRA where idSE = :idSE';
          qry1.paramByName('idSE').AsInteger := idSE;
          qry1.open;
          jArray := qry1.ToJSONArray();
          res.Send(jArray);
          db2.Commit;
          qry1.close;
          freeAndNil(qry1);
        except on E: Exception do
          begin
            res.Send(TJSONObject.ParseJSONValue('[]'));
            //log.add(formatDateTime('dd/mm/yyyy hh:nn', now)+': '+E.ClassName+ ': '+ E.Message+#13#10);
          end;
        end;
        freeAndNil(qry1);
        db2.Close;
      end
    );

    THorse.Get('/api/servicosextras',
      procedure(req: THorseRequest; res: THorseResponse; Next: TProc)
      begin
        //log.add(formatDateTime('dd/mm/yyyy hh:nn', now)+': '+'metodo: servicosextras'+#13#10);
        try
          vNome := req.query['nmcliente'];
        except
          vNome := '';
        end;
        try
          historicoDias := strToInt(lerIni(ArqIni, 'Aplicacao', 'qtdeDiasHistorico'));
        except
          historicoDias := 30;
        end;

        abreConn2();
        db2.StartTransaction;
        qry1 := TFDQuery.Create(Nil);
        qry1.Connection := db2;
        qry1.Close;
        if vNome = '' then
        begin
          qry1.SQL.Text := 'select * from con_servicoextra where dtsolicitacao >= '+DataHoraSql(date-historicoDias)+' order by idSE desc';
        end
        else
        begin
          qry1.SQL.Text := 'select * from con_servicoextra where dtsolicitacao >= '+DataHoraSql(date-historicoDias)+' and nmcliente like ''%'+vNome+'%'' order by idSE desc';
        end;
        try
          qry1.Open;
          jArray := qry1.ToJSONArray();
          res.Send(jArray);
          db2.Commit;
          qry1.close;
          freeAndNil(qry1);
          db2.Close;
          //res.Send(jArray);
        except on e : Exception do
          begin
            //log.add(formatDateTime('dd/mm/yyyy hh:nn', now)+': '+'erro: '+e.Message+#13#10);
          end
        end;

      end
    );

    THorse.Listen(3001);
    db2.Close;
    //db2.Free;
    //log.add(formatDateTime('dd/mm/yyyy hh:nn', now)+': '+'webService fechado'+#13#10);
    //log.SaveToFile(ExtractFilePath(ParamStr(0)) + 'log-'+formatdatetime('yyyymmddhhnnss', now)+'.txt');
    //log.Free;

  except
    on E: Exception do
    begin
      //log.add(formatDateTime('dd/mm/yyyy hh:nn', now)+': '+ E.ClassName+ ': '+ E.Message+#13#10);
      //log.SaveToFile(ExtractFilePath(ParamStr(0)) + 'log-'+formatdatetime('yyyymmddhhnnss', now)+'.txt');
      //log.Free;
      exit;
    end;
  end;
end;

function Tprincipal_f.abreConn():Boolean;
begin
  try
    with db do
    begin
      if Connected then
        Disconnect;
      Protocol        := 'firebird';//lerIni(ArqIni, 'BANCO_LOCAL', 'DRIVER');
      LibraryLocation := lerIni(ArqIni, 'BANCO_LOCAL', 'DLLCLIENT');
      Database := lerIni(ArqIni, 'BANCO_LOCAL', 'DATABASE');
      HostName := lerIni(ArqIni, 'BANCO_LOCAL', 'HOST');
      ControlsCodePage := cCP_UTF16;
      //Properties.Add('CHARACTER SET=WIN1252')
      //Connection.Options.CharSet := 'ISO8859_1';
      //Connection.Options.UseUnicode := false
      // clientCodePage := ISO8859_1;
      Properties.Add('isc_dpb_lc_ctype=WIN1252');
      TransactIsolationLevel := tiReadCommitted;
      try
        Port     := strToInt(lerIni(ArqIni, 'BANCO_LOCAL', 'Port'));
      except
        Port     := 3050;
      end;
      User := lerIni(ArqIni, 'BANCO_LOCAL', 'USER_NAME');
      Password := lerIni(ArqIni, 'BANCO_LOCAL', 'PASSWORD');
      Connect;
    end;
  except
    on E: Exception do
    begin
      //log.add(formatDateTime('dd/mm/yyyy hh:nn', now)+': '+ E.ClassName+ ': '+ E.Message);
      result := false;
    end;
  end;
end;

function Tprincipal_f.abreConn2():Boolean;
begin
  try
    db2.Connected := false;
    db2.Params.Clear;
    db2.Params.UserName := lerIni(ArqIni, 'BANCO_LOCAL', 'USER_NAME');
    db2.Params.Password := lerIni(ArqIni, 'BANCO_LOCAL', 'PASSWORD');
    db2.Params.Database := lerIni(ArqIni, 'BANCO_LOCAL', 'DATABASE');
    db2.Params.DriverID := 'FB';
    db2.Params.Add('Port='+lerIni(ArqIni, 'BANCO_LOCAL', 'Port'));
    db2.Params.Add('Server='+lerIni(ArqIni, 'BANCO_LOCAL', 'HOST'));
    db2.Params.Add('CharacterSet=WIN1252');
    db2.LoginPrompt     := False;
    //db2.Transaction     := FDTransaction1.;
    db2.Connected       := true;
    //FDTransaction1.Active := true;
  except
    on E: Exception do
    begin
      raise(E);
      //log.add(formatDateTime('dd/mm/yyyy hh:nn', now)+': '+E.ClassName+ ': '+ E.Message);
      //result := false;
    end;
  end;
end;


end.
