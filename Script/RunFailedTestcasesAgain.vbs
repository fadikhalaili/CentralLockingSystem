' Example: TestFeatureSet
'
' This script demonstrates the usage of some COM-functions to control a 
' test setup.
'
' Exact description of the script:
' 1) First test module of a test setup is chosen.
' 2) Check if the selected test module has already a verdict
'    a) if no verdict is available
'       - show information
'       - Start measurement
'       - Start test module
'    b) if verdict is available
'       - show information 
' 3) The sequence (testgroups + testcases) of the selected test module 
'    is displayed
' 4) All passed and all failed testcases are listed
' 5) All passed testcases are disabled
' 6) The test module is started again
' 7) The verdict of the test module is shown
' 8) All  failed testcases are listed
' 
'
' To guarantee the descripted functions the first test module of the test 
' setup has to be a XML test module!
'
' The display is done in the Write-Window of the configuration.  
'
'-----------------------------------------------------------------------------
' Copyright (c) 2008 by Vector Informatik GmbH.  All rights reserved.

  Dim testmoduleCount, setupCount
  Dim currentTestmodule
  Dim IsTestmoduleRunning, IsMeasurementRunning
  Dim foundTestmodule, testmoduleIsFound
  
  IsTestmoduleRunning = False
  IsMeasurementRunning = False
  testmoduleIsFound = False

  ' -----------------------------------------------------------------------------
  ' Display the CANoe disclaimer
  ' -----------------------------------------------------------------------------
  ' get the ToolInfo object
  Dim tool
  Set tool = CreateObject( "CANutil.ToolInfo")

  ' show disclaimer (language, strict, beta, education)
  Dim language, strict, beta, education
  language = 1
  strict = 1
  beta = 0
  education = 0
  If tool.ShowDisclaimer( language, strict, beta, education) <> 1 Then
    WScript.quit 1
  End If

  ' release the ToolInfo object
  Set tool = nothing
  
  ' -----------------------------------------------------------------------------
' Start CANoe
' -----------------------------------------------------------------------------
  ' connect to CANoe
  On Error Resume Next
  Set App = CreateObject("canoe.application")
  ExceptionHandling Err.Number, "CANoe run failure"
  On Error Resume Next

  If WScript.Version < "5.1" Then
    busy = 0
  Else
    busy = 1 ' set busy flag
    WScript.ConnectObject App, "App_"
  End If

  
  Do 
    Err.Clear
    If Len(App.configuration.Name) = 0 Then
        PopUpMsgBoxError "No CANoe configuration is opened."
    Else
        busy = 0
    End If

    WScript.Sleep 500
  Loop While busy = 1 'Error: User interface is busy
  
  On Error Resume Next
  Set WriteWindow = App.UI.Write
  ExceptionHandling Err.Number, "Write window connection failure"
  
  WriteWindow.Output "TFS Example: TestFeatureSet Example is started"

  ' -----------------------------------------------------------------------------
  ' Get first testmodule
  ' -----------------------------------------------------------------------------
 
  WScript.ConnectObject App.Measurement, "Meas_"
  
  On Error Resume Next
  ' get the number of all test modules
  setupCount = App.configuration.TestSetup.TestEnvironments.Count
  
  'no test setup available
  If setupCount = 0 Then
    PopUpMsgBoxError "The current configuration does not contain any test setup. The script is aborted."
  End If
 
  testmoduleCount = App.configuration.TestSetup.TestEnvironments.Item(1).Items.Count
  
  'no test module available
  If testmoduleCount = 0 Then
    PopUpMsgBoxError "The current configuration does not contain any test module. The script is aborted."
  End If
   
  Set currentTestmodule = App.configuration.TestSetup.TestEnvironments.Item(1)
  
  Set foundTestmodule = Nothing
  'get the first test module
  StartTestmodule(currentTestmodule)
  
  Set currentTestmodule = foundTestmodule
  
  if testmoduleIsFound = False then
    PopUpMsgBoxError "The current configuration does not contain any test module. The script is aborted."  
  End If

  ' -----------------------------------------------------------------------------
  ' Get verdict of first testmodule
  ' Write the structure of the testmodule in the write window
  ' List all passed and failed test cases in the write window
  ' -----------------------------------------------------------------------------
  
  ' set up connection to event handlers
  WScript.ConnectObject currentTestmodule, "TestModule_"
  
  if currentTestmodule.Verdict = 0 then 'verdict not available
    MsgBox "TFS Example: The verdict of the first test module is not available."_
                & vbNewLine & vbNewLine & _
                "Therefore the script starts the testmodule."_
                & vbNewLine & "Afterwards the structure of the test module "_
                & vbNewLIne &  "and the verdicts of all test cases are displayed in the write window."
    
    If Not App.Measurement.Running Then
      'Start measurement
      On Error Resume Next
      App.CAPL.Compile
      ExceptionHandling Err.Number, "CAPL compile failure"
  
      App.Measurement.Start
    
      While (Not IsMeasurementRunning)
        WScript.Sleep(200)
      Wend
    End If
              
    currentTestmodule.Start()
    WScript.Sleep(200)
    
    ' Wait until test module is stopped
    While (IsTestmoduleRunning)
      WScript.Sleep(200)
    Wend
    WScript.Sleep(2000)
    
    
  else
    MsgBox "TFS Example: The first test module has already been executed."_
                & vbNewLine & vbNewLine & _
                "The structure of the test module and the verdicts"_
                & vbNewLIne &  "of all test cases are displayed in the write window."
  End If
  

      
  'iterate through all testmodule items (testgroups and testcases)
  WriteWindow.Output
  WriteWindow.Output "TFS Example: Test structure of the current test module '" & currentTestmodule.Name & "':"
  WriteWindow.Output
  
  GetAllItems currentTestmodule, ""
  WriteWindow.Output
 
  ' List the passed and failed test cases
  WriteWindow.Output
  WriteWindow.Output "TFS Example: List of the passed test cases:"
  GetAllTestcasesWithVerdict currentTestmodule, 1, false
  
  WriteWindow.Output
  WriteWindow.Output "TFS Example: List of the failed test cases:"
  GetAllTestcasesWithVerdict currentTestmodule, 2, false
  WriteWindow.Output
   
  ' -----------------------------------------------------------------------------
  ' Disable all testcases with verdict "passed"
  ' -----------------------------------------------------------------------------
  
  GetAllTestcasesWithVerdict currentTestmodule, 1, true
  
  MsgBox "TFS Example: All test cases with verdict 'passed' are disabled by the script."_
              & vbNewLine & "Please review the selection of the test cases."_
              & vbNewLine & vbNewLine & "Click 'OK' to start the test module again."     
  
  ' -----------------------------------------------------------------------------
  ' Start the current testmodule again
  ' -----------------------------------------------------------------------------
  
  if Not App.Measurement.Running Then
    
    'Start measurement
    On Error Resume Next
    App.CAPL.Compile
    ExceptionHandling Err.Number, "CAPL compile failure"
  
    App.Measurement.Start
    
    While (Not IsMeasurementRunning)
      WScript.Sleep(200)
    Wend
  End If
                
  WriteWindow.Output "TFS Example: Start the current test module again."
  WriteWindow.Output
  currentTestmodule.Start()
  WScript.Sleep(200)
  
  ' Wait until test module is stopped
  While (IsTestmoduleRunning)
    WScript.Sleep(200)
  Wend
  WScript.Sleep(2000)

  ' -----------------------------------------------------------------------------
  ' Display the verdict of the testmodule
  ' -----------------------------------------------------------------------------
  
  WriteWindow.Output
  Dim stringVerdict
  Select Case (currentTestmodule.Verdict)
      Case 0
        stringVerdict = "Verdict not available"
      Case 1
        stringVerdict = "PASSED"
      Case 2
        stringVerdict = "FAILED"
    End Select
  WriteWindow.Output "TFS Example: Verdict of the test module is: " & stringVerdict
  
  
  MsgBox "TFS Example: Verdict of the test module is: " & stringVerdict _
                & vbNewLine & vbNewLine & _
                "The script is finished."_
                & vbNewLine & "Its sequence is documented in the write window."
  Set stringVerdict = Nothing
  
  WriteWindow.Output
  WriteWindow.Output "TFS Example: List of the failed test cases:"
  GetAllTestcasesWithVerdict currentTestmodule, 2, false
  
  ' -----------------------------------------------------------------------------
  ' Finish the script
  ' -----------------------------------------------------------------------------             
  WriteWindow.Output
  WriteWindow.Output "TFS Example: TestFeatureSet Example finished."

  Set testmoduleCount = Nothing
  Set setupCount = Nothing
  Set currentTestmodule = Nothing
  Set foundTestmodule = Nothing
  Set testmoduleIsFound = Nothing
  Set IsTestmoduleRunning = Nothing
  Set IsMeasurementRunning = Nothing
  Set WriteWindow = Nothing
  Set App = Nothing
  Set FSO = Nothing
  
  







' =============================================================================
' script warning: pop up MsgBox
' =============================================================================
  Sub PopUpMsgBoxWarning(text)
    msgbox text , vbOKOnly , cMsgBoxLabel
  End Sub

' =============================================================================
' script error: pop up MsgBox and exit script
' =============================================================================
  Sub PopUpMsgBoxError(text)
    msgbox text , vbOKOnly , cMsgBoxLabel
    
    ' stops the measurement
    If App.Measurement.Running Then
      App.Measurement.Stop
    End If
 
    WScript.quit 1
  End Sub
  
  ' =============================================================================
' Exception handling
' =============================================================================
  Private Sub ExceptionHandling (errNum, msgDescr)
    If Err.Number <> CLng (0) Then
      If (IsNull (msgDescr) OR IsEmpty (msgDescr) OR msgDescr = "") Then
        msgDescr = "???"
      End If
      MsgBox "Error # " & CStr(Err.Number) & " " & Err.Description & " " & Err.Source & "."_
                        & vbNewLine & msgDescr  & "."_
                        & vbNewLine & "Invalid CANoe installation?" & vbNewLine & "The Script is aborted!"
      Err.Clear   ' Clear the error.
      Set App = Nothing
      Set FSO = Nothing
      Set F = Nothing
      WScript.quit 1
    End If
  End sub
  
  ' =============================================================================
  ' Returns the first test module
  ' =============================================================================
  Private Function StartTestmodule(Folder)
    
    Dim Item
    StartTestmodule = False
   
    For Each Item in Folder.Items
      
      if IsFolder(Item) Then
        StartTestmodule = StartTestmodule(Item)
      Else
        StartTestmodule = True
      End If
      
      If StartTestmodule = True then
        Set foundTestmodule = Item
        testmoduleIsFound = True
        StartTestmodule = True
        break 
      End If
      
    Next
   
  End Function
  
  ' =============================================================================
  ' Checks if TestSetupItem is a TestSetupFolder
  ' =============================================================================
  Function IsFolder(TestSetupItem)
    On Error Resume Next

    Err.Clear()
    
    StartOnKey = TestSetupItem.StartOnKey
    
    if Err.Number = 0 Then
      isFolder = False           
    Else
      isFolder = True
    End If
  end Function

  
  ' =============================================================================
  ' Returns all items of the first test module
  ' =============================================================================
  Private Function GetAllItems(element, engageString)
    Dim subElementsCount, i, subElement
    
    subElementsCount = 0
    
    on error resume next
    subElementsCount = element.Sequence.Count
    
    if subElementsCount <> 0 Then
      
      for i = 1 to subElementsCount
        Set subElement = element.Sequence.Item(i)
        WriteWindow.Output engageString & subElement.Name
        
        engageString = engageString & "    "
        GetAllItems subElement, engageString
        engageString = Left(engageString, Len(engageString)-4) 
      Next
      
    End If
    
    Set subElementsCount = Nothing
    Set subElement = Nothing 
  End Function
  
  ' =============================================================================
  ' Goes through all test cases of a testmodule.
  ' If "disable" is true, all test cases with verdict "verdict" are disabled.
  ' If "disable" is false, then the names of the testcases with verdict "verdict"
  ' are written to the write window.
  ' =============================================================================
  Private Function GetAllTestcasesWithVerdict(element, verdict, disabled)
    Dim subElementsCount, i, subElement, verdictSubElement
    
    subElementsCount = 0
    
    on error resume next
    subElementsCount = element.Sequence.Count
    
    if subElementsCount <> 0 Then
      
      for i = 1 to subElementsCount
        Set subElement = element.Sequence.Item(i)
        verdictSubElement = 0
        verdictSubElement = subElement.Verdict
         
        if verdictSubElement = verdict Then
          if disabled = false then
            WriteWindow.Output "    " & subElement.Ident & "     " & subElement.Name
          else
            subElement.Enabled = false
          End If
        End If
        
        GetAllTestcasesWithVerdict subElement, verdict, disabled
      Next
      
    End If
    
    Set subElementsCount = Nothing
    Set subElement = Nothing
    Set verdictSubElement = Nothing
  End Function
  
  ' =============================================================================
  '  Events 
  ' =============================================================================
  
  Sub TestModule_OnStart()
    IsTestmoduleRunning = True
  End Sub
  
  Sub TestModule_OnStop(reason)
    IsTestmoduleRunning = False
    Select Case (reason)
      Case 1
        PopUpMsgBoxError "Test module was stopped by the user."
      Case 2
        PopUpMsgBoxError "Test module was stopped by measurement stop"
    End Select

  End Sub

  Sub Meas_OnStart()
    IsMeasurementRunning = True
  End Sub
  
  Sub Meas_OnStop()
    IsMeasurementRunning = False
  End Sub
