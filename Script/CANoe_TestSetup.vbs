' This VB-Script makes modifications in the CentralLockingSystem demo and starts
' a measurement afterwards
'-----------------------------------------------------------------------------
' Copyright (c) 2006 by Vector Informatik GmbH.  All rights reserved.

  Dim App, Measurement, Config, TestSetup, TestEnvs, TestEnv
  Dim Tester, IsMeasurementRunning, IsTesterExecuting, TesterStopReason
  Dim FullName

  ' get the ToolInfo object
  Set Tool = CreateObject("CANutil.ToolInfo")

  If Tool.ShowApplicationDisclaimer("CANoe.Application") <> 1 Then
    Wscript.Quit
  End If

  Set App         = CreateObject("CANoe.Application")
  Set Measurement = App.Measurement
  WScript.ConnectObject Measurement, "Measurement_"

  ' stop running measurement
  If Measurement.Running Then
    IsMeasurementRunning = True
    Measurement.Stop()
    
    While IsMeasurementRunning
      Wscript.Sleep 200
    Wend    
  Else
    IsMeasurementRunning = False
  End If

  OpenConfig("\..\CentralLockingSystem.cfg")

  Set Measurement = App.Measurement
  Set Config      = App.Configuration
  Set TestSetup   = Config.TestSetup
  Set TestEnvs    = TestSetup.TestEnvironments
  Set TestEnv     = TestEnvs.Item(1)
  Set Tester      = TestEnv.Items.Item(1)  
  Set TestTree    = Tester.Sequence
  Set TG1         = TestTree.Item(1)
  Set TG2         = TestTree.Item(2)

  WScript.ConnectObject Tester, "Tester_"
  WScript.ConnectObject Measurement, "Measurement_"  

  ' deactivate the second test group
  TG2.Enabled = False
  
  ' start the measurement
  Measurement.Start()    
  While (Not IsMeasurementRunning)
    Wscript.Sleep 200
  Wend    

  ' start the test module
  IsTesterExecuting = False
  Tester.Start()
  While (Not IsTesterExecuting)
    Wscript.Sleep 200
  Wend    
  
  ' Wait until execution of test is finished
  While (IsTesterExecuting)
    Wscript.Sleep 500
  Wend

  ' Stop measurement
  Measurement.Stop() 
  While IsMeasurementRunning
    Wscript.Sleep 200
  Wend      
    
  ' Show result
  TMVerdict = Tester.Verdict

  Select Case TMVerdict
    Case 0
      MsgBox "Verdict not available"
    Case 1
      MsgBox "Verdict Passed"
    Case 2
      MsgBox "Verdict Failed"
    Case Else
      MsgBox "Error: Invalid Verdict Value"
  End Select  
  
  Set App 		   = Nothing
  Set Measurement 	   = Nothing
  Set Config 		   = Nothing
  Set TestSetup 	   = Nothing
  Set TestEnvs 		   = Nothing
  Set TestEnv 		   = Nothing
  Set Tester 		   = Nothing
  Set IsMeasurementRunning = Nothing
  Set IsTesterExecuting    = Nothing
  Set TesterStopReason     = Nothing
  Set CountryStream        = Nothing
  Set StrictStream         = Nothing
  Set FSO 		   = Nothing

  MsgBox "CANoe Testsetup script done..."

  Function GetFullName(relpath)
    Dim FSO, FullPath

    Set FSO     = CreateObject("Scripting.FileSystemObject")
    FullPath    = FSO.GetFile(WScript.ScriptFullName).ParentFolder & relpath
    GetFullName = FSO.GetFile(FullPath).Path
    Set FSO     = Nothing
  End Function

  Sub OpenConfig(relpath)  'Open the specified config (if it isn't already)
    On Error Resume Next  

    FullName = GetFullName(relpath)
    App.Open(FullName)
   
    If Err.Number Then
      MsgBox "Error opening configuration!" & Chr(10) & "(" & Err.Description & ")", VBOKOnly + VBCritical, "Error" 
      WScript.Quit
    End If
  End Sub

  Sub Measurement_OnStart()
    IsMeasurementRunning = True
  End Sub
    
  Sub Measurement_OnStop()
    IsMeasurementRunning = False
  End Sub
    
  Sub Tester_OnStart()
    IsTesterExecuting = True
  End Sub
    
  Sub Tester_OnStop(reason)
    IsTesterExecuting = False
    TesterStopReason  = reason
  End Sub
