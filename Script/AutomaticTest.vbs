'-----------------------------------------------------------------------------
' This VBScript uses the CANoe COM-API
' It starts CANoe, runs all test modules in the first test enviroment
'  gathers the summary verdict and returns (errorlevel) the number of failed modules
' It outputs information on stdout and into a log file
' requires 2 parameters:
'  1st: path to CANoe configuration to use (it will not store changes in this file)
'  2nd: path to log file (any writeable text file path+name). It will rewrite the file on every run.
'-----------------------------------------------------------------------------
' Copyright (c) 2016 by Vector Informatik GmbH. All rights reserved.

Option Explicit

  Dim CfgFilePath, LogFilePath
  Dim CanoeApp, Configuration
  Dim MeasurementRunning, ReportGenerated
  Dim LastTestResult, TestResults
  Dim TestEnvs, TestEnv, TestModule, TestConfigurations, TestConfiguration
  Dim FSO
  Set FSO = CreateObject("Scripting.FileSystemObject")
    
  Call ProcessCommandLine
  Call LogCreate()
  
  WScript.Quit(Main)

  
rem -----------------------------------------------------------------------------------------------------
Function Main  
  Set CanoeApp = CreateObject("CANoe.Application")
  Set Configuration = CanoeApp.Configuration
  
  Set TestResults = WScript.CreateObject("Scripting.Dictionary")
  Call StopMeasurement()
  
  Call PrepareAndRunAllTests
  ExitCANoe

  Call ShowTestResults

  Main = GetScriptResult()
End Function

rem -----------------------------------------------------------------------------------------------------
Sub ProcessCommandLine
  If WScript.Arguments.Count = 2 Then
      CfgFilePath = WScript.Arguments(0)
      LogFilePath = WScript.Arguments(1)
  Else
     Wscript.Echo "Provide following arguments: CANoeConfigPath LogFilePath"
     Wscript.Echo "sample: AutomaticTest.vbs '..\Cfg\TestConfig.cfg' 'logs\TestConfig.log'"
     Wscript.Quit
  End If  
End Sub

rem -----------------------------------------------------------------------------------------------------
Sub PrepareAndRunAllTests

  Call OpenConfiguration(CfgFilePath)
  CompileAll

  RunTest "StandardTests", 1  
 
End Sub

rem -----------------------------------------------------------------------------------------------------
Sub CompileAll
    LogEntry "*********** Activate and compile all modules ***********"
    LogEntry "Compile all nodes of configuration: " & Configuration.Name  
    Call StopMeasurement()
    Configuration.CompileAndVerify
End Sub

rem -----------------------------------------------------------------------------------------------------
Sub StandardTests
    Call StopMeasurement()
    
    Set TestEnvs = Configuration.TestSetup.TestEnvironments
    Set TestConfigurations = Configuration.TestConfigurations
    
    Call PrepareTestEnvironments()
    Call PrepareTestConfigurations()
    
    Call StartMeasurement()

    Call ExecuteTestModules
    Call ExecuteTestConfigurations

    Call StopMeasurement()
End Sub

rem -----------------------------------------------------------------------------------------------------
' Sum up all child elements (test cases)
' if failed = true -> sum up only not successful test cases
Function CountTestcasesTestModule(element, failed)
    Dim subElementsCount, i, subElement, found
    subElementsCount = 0
    found = 0
    'LogEntry "* Element is " & element.Name
    on error resume next
    
    subElementsCount = element.Sequence.Count
    'LogEntry "* Element " & element.Name & " contains " & subElementsCount & " children."
    If (subElementsCount > 0) Then
      For i = 1 To subElementsCount
        Set subElement = element.Sequence.Item(i)
        If (subElement.Sequence.Count > 0) Then
            'LogEntry "+    " & subElement.Ident & "     " & subElement.Name
            found = found + CountTestcasesTestModule(subElement, failed)
		Else 
        End If
      Next
	'Else
    ElseIf ((failed = False And element.Verdict > 0) Or (failed = True And element.Verdict > 1)) Then
  	  'LogEntry "-   " & subElement.Ident & "     " & subElement.Name
	  found = 1
    End If
    
    CountTestcasesTestModule = found	

    Set subElement = Nothing
    Set subElementsCount = Nothing
End Function

rem -----------------------------------------------------------------------------------------------------
Function CountExecutableElements(element, level, failed)
  Dim child
  Dim executableElements
  
  For Each child in element.Elements
    ' Count only Test case, test sequence and executed elements
    if((child.Type = 4 or child.Type = 5) and child.Verdict <> 0) then
      if (failed) then
        if (child.Verdict <> 1 and child.Verdict <> 3) then
          executableElements = executableElements + 1
         End If
      else
        executableElements = executableElements + 1
      End If
    End If
    executableElements = executableElements + CountExecutableElements(child, level + 1, failed)
  Next

  CountExecutableElements = executableElements
  
End Function

rem -----------------------------------------------------------------------------------------------------
Function GetVerdictText(verdict)
  Dim verdictText

  If (verdict = 1) Then 
    verdictText = "Passed" 
  ElseIf (verdict = 2) Then 
    verdictText = "Failed" 
  ElseIf (verdict = 3) Then 
    verdictText = "None" 
  ElseIf (verdict = 4) Then 
    verdictText = "Inconclusive" 
  ElseIf (verdict = 5) Then 
    verdictText = "Error in testsystem" 
  Else 
    verdictText = "Not available"
  End If
  
  GetVerdictText = verdictText
End Function

rem -----------------------------------------------------------------------------------------------------
Sub ConnectMeasurement
  WScript.ConnectObject CanoeApp.Measurement, "Measurement_"
End Sub

Sub DisonnectMeasurement
  WScript.DisconnectObject CanoeApp.Measurement
End Sub

Sub Measurement_OnStart()
  MeasurementRunning = True
End Sub

Sub Measurement_OnStop()
  MeasurementRunning = False
End Sub

rem -----------------------------------------------------------------------------------------------------
Sub ConnectTestModuleReport()
  WScript.ConnectObject TestModule, "TestModule_"
End Sub

Sub DisconnectTestModuleReport()
  WScript.DisconnectObject TestModule
End Sub

Sub TestModule_OnReportGenerated(Success, SourceFullName, GeneratedFullName)
  ReportGenerated = True
End Sub

rem -----------------------------------------------------------------------------------------------------
Sub ConnectTestConfigurationReport()
  WScript.ConnectObject TestConfiguration.Report, "TestConfigurationReport_"
End Sub

Sub DisconnectTestConfigurationReport()
  WScript.DisconnectObject TestConfiguration.Report
End Sub

Sub TestConfigurationReport_OnGenerated(Success, SourceFullName, GeneratedFullName)
  ReportGenerated = True
End Sub

rem -----------------------------------------------------------------------------------------------------
Sub StartMeasurement()
  Call ConnectMeasurement
  MeasurementRunning = CanoeApp.Measurement.Running
  If Not MeasurementRunning Then
    CanoeApp.Measurement.Start
    Call WaitFor(MeasurementRunning, True)
  End If
  Call DisonnectMeasurement
End Sub

rem -----------------------------------------------------------------------------------------------------
Sub PrepareTestEnvironments
  For Each TestEnv In TestEnvs
    TestEnv.Enabled = true
    TestEnv.Report.Enabled = true
    
    For Each TestModule In TestEnv.TestModules
      TestModule.Enabled = true
      TestModule.Report.Enabled = true
    next
  next
  
End Sub

rem -----------------------------------------------------------------------------------------------------
Sub PrepareTestConfigurations
  For Each TestConfiguration In TestConfigurations
    TestConfiguration.Enabled = true
    TestConfiguration.Report.UseJointReport = true
  next
End Sub

rem -----------------------------------------------------------------------------------------------------
Sub ExecuteTestModules() 
  if (TestEnvs.Count > 0) Then
    LogEntry ""
    LogEntry "*********** Execution of all test modules in all test environments started *********** "
    LogEntry "Hint: test modules in sub folders are not be considered."
    
    For Each TestEnv In TestEnvs
      LogEntry ""
      LogEntry "---------- Executing TestEnvironment: '"&  TestEnv.Name & "' (" & TestEnv.FullName & ") ----------"
      LogEntry "Found " &  TestEnv.TestModules.Count & " test module(s)."
      
      For Each TestModule In TestEnv.TestModules
        If TestModule.Enabled Then 
          LogEntry " - executing testmodule: '" &  TestModule.Name & "'"
        
          Call ConnectTestModuleReport()
          ReportGenerated = false
          Call TestModule.Start()
          
          ' wait until testmodul is finished
          While Not ReportGenerated
            Wscript.Sleep 100
          Wend
          
          Call DisconnectTestModuleReport()
          
          LogEntry "     --> Verdict: " & GetVerdictText(TestModule.Verdict) & ". Number of test cases/unsuccessful test cases: " & CountTestcasesTestModule(TestModule, false) & "/" & CountTestcasesTestModule(TestModule, true)
          If TestModule.Verdict <> 1 and TestModule.Verdict <> 3 Then 
            LogEntry "         FAIL: Test module did not report success."
            LastTestResult = False		
          End If
        Else
          LogEntry " - will NOT run disabled testmodule: '" &  TestModule.Name & "'"
        End If
      Next
      LogEntry "---------- Executing of TestEnvironment: '"&  TestEnv.Name & "' finished ----------"
    Next  rem foreach TestEnvs
    LogEntry ""
    LogEntry "*********** Execution of all test modules in all test environments finished *********** "
  End If
End Sub

rem -----------------------------------------------------------------------------------------------------
Sub ExecuteTestConfigurations() 
  if (TestConfigurations.Count > 0) Then
    LogEntry ""
    LogEntry "********************* Execution of all test configurations ********************* "
    LogEntry "Found " &  TestConfigurations.Count & " test configuration(s)."

    For Each TestConfiguration In TestConfigurations
      LogEntry ""
      LogEntry "---------- Executing TestConfiguration: '"&  TestConfiguration.Name & " ----------"
      
      If TestConfiguration.Enabled Then 
        LogEntry " - executing test configuration: '" &  TestConfiguration.Name & "'"
      
        Call ConnectTestConfigurationReport()
        ReportGenerated = false
        Call TestConfiguration.Start()
        
        ' wait until testmodul is finished
        While Not ReportGenerated
          Wscript.Sleep 100
        Wend
        
        Call DisconnectTestConfigurationReport()
        
        LogEntry "     --> Verdict: " & GetVerdictText(TestConfiguration.Verdict) & ". Number of test cases/unsuccessful test cases: " & CountExecutableElements(TestConfiguration, 0, false) & "/" & CountExecutableElements(TestConfiguration, 0, true)
        If TestConfiguration.Verdict <> 1 and TestConfiguration.Verdict <> 3 Then 
          LogEntry "         FAIL: Test module did not report success."
          LastTestResult = False		
        End If
      Else
        LogEntry " - will NOT run disabled test configuration: '" &  TestConfiguration.Name & "'"
      End If
      
      LogEntry "---------- Executing of TestConfiguration: '"&  TestConfiguration.Name & "' finished ----------"
    Next  rem foreach TestEnvs
    LogEntry ""
    LogEntry "********************* Execution of all test configurations finished ********************* "
  End If
End Sub

rem -----------------------------------------------------------------------------------------------------
Sub StopMeasurement()
  Call ConnectMeasurement
  MeasurementRunning = CanoeApp.Measurement.Running
  If MeasurementRunning Then
    CanoeApp.Measurement.Stop ' StopEx needed to simulate two pass stopping
    Call WaitFor(MeasurementRunning, False)
  End If
  Call DisonnectMeasurement
End Sub

rem -----------------------------------------------------------------------------------------------------
Sub ExitCANoe()
  Call StopMeasurement

  WScript.Sleep 2000
  CanoeApp.Configuration.Modified = False
  CanoeApp.Quit
End Sub

rem -----------------------------------------------------------------------------------------------------
Sub OpenConfiguration(relpath)  'Open the specified config (If it isn't already)
  'On Error Resume Next
  Dim path, config

  path = FSO.GetFile(WScript.ScriptFullName).ParentFolder & relpath
  config = FSO.GetFile(path).Path
  If IsNull(Configuration) or (not Configuration.FullName = config) Then
    CanoeApp.Open(config)
  End If

  LogEntry "CFG:" & config
  If Err.Number Then
    Err.Clear
    CanoeApp.Open(config)
  End If

  If Err.Number Then
    MsgBox "Error opening configuration!" & vbNewLine & "(" & Err.Description & ")", VBOKOnly + VBCritical, "Error"
    WScript.Quit
  End If
End Sub

rem -----------------------------------------------------------------------------------------------------
Sub LogCreate()
  Dim logFileObj
  On Error Resume Next
  If FSO.FileExists(LogFilePath) Then
    Set logFileObj = FSO.OpenTextFile(LogFilePath, 2, True)
    logFileObj.Write("")	' empty file
	logFileObj.Close
  End If
  Call LogEntry("------------------------------------------------------------")
  Call LogEntry("Test started: " & Now)
  Call LogEntry("------------------------------------------------------------")
End Sub
rem -----------------------------------------------------------------------------------------------------
Sub LogEntry(entry)
  Dim stream
  On Error Resume Next
  Set stream = FSO.OpenTextFile(LogFilePath, 8, True) ' Open for appending
  stream.Write(vbNewLine & entry)
  stream.Close
  WScript.StdOut.WriteLine entry
End Sub

rem -----------------------------------------------------------------------------------------------------
Sub RunTest(name, retries)
  Do
    LastTestResult = True
    LogEntry ""
    LogEntry "Running " + name + "..."
    LogEntry ""
    Execute(name)
    
    retries = retries - 1
  Loop While (not LastTestResult and retries>0)

  Dim result
  set result = new TestItem
  result.Name = name
  result.Result = LastTestResult
  TestResults.Add TestResults.count, result
End Sub

rem -----------------------------------------------------------------------------------------------------
Class TestItem
  Private mName, mResult
  Private Sub Class_Initialize
    mName = ""
    mResult = False
  End Sub
  Public Property Let Name(value)
    mName = value
  End Property
  Public Property Get Name
    Name = mName
  End Property
  Public Property Let Result(value)
    mResult = value
  End Property
  Public Property Get Result
    Result = mResult
  End Property
End Class

rem -----------------------------------------------------------------------------------------------------
Sub ShowTestResults
  Dim key, res, failed
  failed = false
  LogEntry vbNewLine
  LogEntry "------------------------------------------------------------"
  LogEntry "TEST RESULTS"
  LogEntry "------------------------------------------------------------"
  For Each key In TestResults.Keys
    If TestResults.Item(key).Result Then
      res = "PASSED"
    Else
      res = "FAILED"
      failed = true
    End If
    LogEntry vbTab & res & vbTab & TestResults.Item(key).Name
  Next
  LogEntry "------------------------------------------------------------"
  If failed Then
    LogEntry "Test contains errors."
  Else
    LogEntry "Test finished successfully."
  End If
  LogEntry "------------------------------------------------------------"
End Sub


rem -----------------------------------------------------------------------------------------------------
rem calcutes the number of failed tests
Function GetScriptResult
  Dim key, failed
  failed = 0
  For Each key In TestResults.Keys
    If not TestResults.Item(key).Result Then
      failed = failed + 1
    End If
  Next
  If (failed>0) Then
    LogEntry "GetScriptResult: found " & failed & " failed test(s)."
  End If
  
  rem errorlevel max=255.
  If (failed>255) Then 
    failed=255 
  End If 

  GetScriptResult = failed
End Function


rem -----------------------------------------------------------------------------------------------------
Sub WaitFor(ByRef variable, state)
  Dim i
  i = 0
  While not variable = state
    Wscript.Sleep 100
    If i = 1000 Then
      ' wait maximum 10 seconds
      Exit Sub
    End If
    i = i + 1
  Wend
End Sub