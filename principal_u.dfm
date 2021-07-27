object principal_f: Tprincipal_f
  OldCreateOrder = False
  DisplayName = 'apiDbadm'
  OnStart = ServiceStart
  Height = 468
  Width = 916
  object db2: TFDConnection
    Params.Strings = (
      'DriverID=FB'
      'User_Name=sysdba'
      'Password=masterkey')
    LoginPrompt = False
    Transaction = FDTransaction1
    Left = 88
    Top = 56
  end
  object FDTransaction1: TFDTransaction
    Connection = db2
    Left = 160
    Top = 64
  end
end
