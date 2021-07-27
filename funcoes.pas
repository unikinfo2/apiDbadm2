unit funcoes;

interface
uses QBXMLRP2Lib_TLB, Vcl.Dialogs, inifiles, SysUtils, System.Classes, strUtils,
     Xml.XMLDoc, Xml.xmldom, Xml.XMLIntf, Xml.Win.msxmldom,
     Data.DB,
     ZAbstractConnection,
     ZConnection,
     ZAbstractRODataset,
     ZAbstractDataset,
     ZDataset,
     FireDAC.Stan.Intf, FireDAC.Stan.Option,
     FireDAC.Stan.Error, FireDAC.UI.Intf, FireDAC.Phys.Intf, FireDAC.Stan.Def,
     FireDAC.Stan.Pool, FireDAC.Stan.Async, FireDAC.Phys, FireDAC.VCLUI.Wait,
     FireDAC.Comp.Client ,
     FireDAC.Phys.FB, FireDAC.Phys.FBDef,
     FireDAC.Stan.Param,
     FireDAC.DatS, FireDAC.DApt.Intf, FireDAC.DApt, FireDAC.Comp.DataSet;

function OpenConQb(pArqQb : wideString='') : Boolean;
function CloseConQb : Boolean;
function OpenSession(pArqQb : wideString='') : Boolean;
function CloseSession() : Boolean;
function RequestQbXml( pXml : WideString ) : WideString;
function RequestQb( pXml : WideString; salvaArquivo : Boolean = False; pNomeArq:String='';pVersao:String='13.0' ) : WideString;
procedure GravarIni(vArquivoIni,vSecao,vChave,vValor: String);
function LerIni(vArquivoIni,vSecao,vChave: String): String;
function criptografar(const key, texto: String): String;
function descriptografar(const key, texto: String): String;
function EmpresaQB(var pEmp: String): Boolean;
function Proximo(Tabela,Campo:String; Condicao:String=''): Integer;
function DataHoraSql(pData: TDateTime; pHora : String='00:00') : String;

var
  qb : TRequestProcessor2;
  arqIni, pastaXml, vArqQB,
  strXMLRequest, strXMLResponse : String;
  Sessao         : String;
  Versao         : String;
  CompanyName,
  CompanyName2   : String;
  empresaAutorizada : Boolean;
  db : TZConnection;


const
  sistema : String = 'BuscadorQB';

implementation

function OpenSession(pArqQb : wideString='') : Boolean;
begin
  result := false;
  try
    if Sessao <> '' then
      qb.EndSession(Sessao);
  except
  end;

  try
    Sessao := qb.BeginSession(pArqQb, qbFileOpenDoNotCare); //pArqQb  qbFileOpenMultiUser - qbFileOpenDoNotCare
    result := true;
  except
    on E: Exception do
      begin
        messagedlg(E.Message, mtWarning,[mbOk],0);
        //CloseConQb;
      end;
  end;
end;

function OpenConQb(pArqQb : wideString='') : Boolean;
begin
  try
    if qb <> nil then
    begin
      result := true;
      exit;
    end;
    qb := QBXMLRP2Lib_TLB.TRequestProcessor2.Create(nil);
    //qb.AutoConnect := true;
    qb.OpenConnection(sistema, 'Uni-K '+sistema);
    result := true;
    Sessao := qb.BeginSession(pArqQb, qbFileOpenDoNotCare); // qbFileOpenDoNotCare    omDontCare
    result := openSession(pArqQb);
    //frmPrincipal.memo1.lines.add('Sessao: '+sessao);
  except
    on E: Exception do
    begin
      messagedlg(E.Message, mtWarning,[mbOk],0);
      //CloseConQb;
      result := False;
    end;
  end;
end;

function CloseConQb : Boolean;
begin
  try
    qb.EndSession(sessao);
    qb.CloseConnection;
    qb.Disconnect;
    qb.Free;
    qb := nil;
    sessao := '';
    Result := True;
  except
    result := False;
  end;
end;

function CloseSession() : Boolean;
begin
  result := false;
  try
    if Sessao <> '' then
      qb.EndSession(Sessao);
    sessao := '';
  except
  end;
end;

function RequestQb( pXml : WideString; salvaArquivo : Boolean = False; pNomeArq:String='';pVersao:String='13.0' ) : WideString;
var sStream : TStringStream;
    fStream : TFileStream;
    sArqRQ, sArqRS : String;
begin
  if qb <> nil then
  begin
    try
      strXMLRequest  :=                 '<?xml version="1.0" encoding="ISO-8859-1"?> ';
      strXMLRequest  := strXMLRequest + '<?qbxml version="'+pVersao+'"?> ';
      strXMLRequest  := strXMLRequest + '<QBXML> ';
      strXMLRequest  := strXMLRequest + '  <QBXMLMsgsRq onError="continueOnError" responseData="includeAll"> ';
      strXMLRequest  := strXMLRequest + pXml;
      strXMLRequest  := strXMLRequest + '  </QBXMLMsgsRq> ';
      strXMLRequest  := strXMLRequest + '</QBXML> ';
      if salvaArquivo then
      begin
        if pNomeArq = '' then
        begin
          sArqRq := extractFilePath(ParamStr(0))+'xml\Request.xml';
          sArqRs := extractFilePath(ParamStr(0))+'xml\Response.xml';
        end
        else
        begin
          sArqRq := extractFilePath(ParamStr(0))+'xml\'+pNomeArq+'Rq.xml';
          sArqRs := extractFilePath(ParamStr(0))+'xml\'+pNomeArq+'Rs.xml';
        end;
        // Salva o Arquivo Request
        sStream := TStringStream.Create(strXMLRequest);
        fStream := TFileStream.Create(sArqRq, fmCreate);
        fStream.CopyFrom(sStream, sStream.Size);
        fStream.Destroy;
        FreeAndNil(sStream);

        //frmPrincipal.memLog.lines.add('Sessao antes de processar: '+sessao);
        strXMLResponse := qb.ProcessRequest(Sessao, strXMLRequest);
        strXMLResponse := ansiReplaceText(strXMLResponse, '<?xml version="1.0" ?>', '<?xml version="1.0" encoding="ISO-8859-1" ?>');
        Result         := strXMLResponse;

        // Salva o Arquivo Response
        sStream := TStringStream.Create(strXMLResponse);
        fStream := TFileStream.Create(sArqRs, fmCreate);
        fStream.CopyFrom(sStream, sStream.Size);
        fStream.Destroy;
        FreeAndNil(sStream);
      end
      else
      begin
        strXMLResponse := qb.ProcessRequest(Sessao, strXMLRequest);
        strXMLResponse := ansiReplaceText(strXMLResponse, '<?xml version="1.0" ?>', '<?xml version="1.0" encoding="ISO-8859-1" ?>');
        Result         := strXMLResponse;
      end;
    finally
    end;
  end
  else
  begin
    Result := 'Não foi possivel estabelecer a conexão com o Quickbooks ';
  end;
end;

function RequestQbXml( pXml : WideString ) : WideString;
begin
  {Result := TStringsList.Create;}
  OpenConQB;
  try
    OpenSession(vArqQB);
    strXMLResponse := qb.ProcessRequest(Sessao, pXml);
    Result         := strXMLResponse;
  finally
    CloseConQb;
  end;
end;

function LerIni(vArquivoIni,vSecao,vChave: String): String;
var
  iniFile : TIniFile;
begin
  vArquivoIni := vArquivoIni;
  iniFile := TIniFile.Create(vArquivoIni);
  Result  := iniFile.ReadString(vSecao,vChave,'');
  iniFile.Free;
end;

procedure GravarIni(vArquivoIni,vSecao,vChave,vValor: String);
var
  iniFile : TIniFile;
begin
  vArquivoIni := vArquivoIni;
  iniFile := TIniFile.Create(vArquivoIni);
  iniFile.WriteString(vSecao,vChave,vValor);
  iniFile.Free;
end;

function criptografar(const key, texto: String): String;
var I: Integer;
    C: Byte;
begin
  Result := '';
  for I := 1 to Length(texto) do begin
    if Length(Key) > 0 then
      C := Byte(Key[1 + ((I - 1) mod Length(Key))]) xor Byte(texto[I])
    else
      C := Byte(texto[I]);
    Result := Result + AnsiLowerCase(IntToHex(C, 2));
  end;
end;

function descriptografar(const key, texto: String): String;
var I: Integer;
    C: Char;
begin
  Result := '';
  for I := 0 to Length(texto) div 2 - 1 do begin
    C := Chr(StrToIntDef('$' + Copy(texto, (I * 2) + 1, 2), Ord(' ')));
    if Length(Key) > 0 then
      C := Chr(Byte(Key[1 + (I mod Length(Key))]) xor Byte(C));
    Result := Result + C;
  end;
end;

function EmpresaQB(var pEmp : String):Boolean;
var strPesquisa : String;
    xmlAux : IXmlDocument;
    vNode : IXMLNode;
begin
  result := False;
  try
    strPesquisa     := '<CompanyQueryRq>'+
                       '</CompanyQueryRq>';
    xmlAux          :=  TXMLDocument.Create(nil);
    xmlAux.Active   := false;
    xmlAux.xml.Text := RequestQb(strPesquisa, false, '', Versao);
    xmlAux.xml.Text := ansiReplaceText(xmlAux.XML.Text, '<?xml version="1.0" ?>', '<?xml version="1.0" encoding="ISO-8859-1" ?>');
    xmlAux.Active   := true;

    vNode   := xmlAux.ChildNodes['QBXML'].ChildNodes['QBXMLMsgsRs'].ChildNodes['CompanyQueryRs'].ChildNodes['CompanyRet'];

    //vNode.ChildNodes.Get(i)

    result := (pEmp = vNode.ChildNodes.FindNode('CompanyName').NodeValue) or (pEmp = '');
    pEmp   := vNode.ChildNodes.FindNode('CompanyName').NodeValue;
  except
    pEmp   := '';
  end;
end;

function Proximo(Tabela, Campo, Condicao: String): Integer;
var vStr : String;
begin
  with TZQuery.Create(Nil) do
  begin
    Connection := db;
    vStr := '';
    if condicao <> '' then
      vStr := ' WHERE ' + condicao;
    Sql.Text := 'SELECT MAX(' + CAMPO + ') AS CODIGO FROM '+ TABELA +
                vStr;
    Open;
    if FieldByName('Codigo').AsString = '' then
      result := 1
    else
      result := FieldByName('Codigo').AsInteger + 1;
  end;
end;

function DataHoraSql(pData: TDateTime; pHora : String='00:00') : String;
begin
  result := #39 + formatdatetime('yyyy-mm-dd', pData) + ' ' + pHora + #39;
end;


end.
