using System;
using Vector.Tools;
using Vector.CANoe.Runtime;
using Vector.CANoe.Threading;
using Vector.CANoe.TFS;
using NetworkDB;
using System.Text;

public class CentralLockingSystemLibrary
{
  #region Reuse of test cases by subclassing

  public abstract class LockStateTestBase
  {
    [TestCase]
    public void Execute()
    {
      Report.TestCaseTitle(Title);

      InitSUT();

      EngineRunning.Value = 1;

      // Increasing the velocity up to 55
      // Example for code reuse using a generic class -- see SignalGenerators
      using (SignalGenerators.RampGenerator<Velocity> generator = new SignalGenerators.RampGenerator<Velocity>(55, 0, 0, 2500, 500, 2500, 50, false))
      {
        generator.Start();

        // template method pattern; the concrete test is done by the subclass
        DoConcreteTest();

        generator.Stop();
      }
    }

    private void InitSUT()
    {
      Report.TestPatternBegin("Init", "Initializes the system under test.");
      // Initialize some signals
      Velocity.Value = 0;
      CrashDetected.Value = 0;
      LockRequest.Value = 0;
      EngineRunning.Value = 0;
      LockState.Value = 0;

      // Wait until the system conditions are fulfilled
      Criterion initCriterion = new Criterion();
      initCriterion.AddMandatory(new ValueCriterion<Velocity>(0));
      initCriterion.AddMandatory(new ValueCriterion<CrashDetected>(0));
      initCriterion.AddMandatory(new ValueCriterion<EngineRunning>(0));
      initCriterion.AddMandatory(new ValueCriterion<LockState>(0));

      if (Execution.Wait(initCriterion, 500) == Execution.WAIT_TIMEOUT)
      {
        Report.TestStepFail("Init SUT", "The initialization of the system under test fails");
        Report.TestPatternEnd(Verdict.Failed);
      }
      else
        Report.TestPatternEnd(Verdict.Passed);
    }

    protected abstract void DoConcreteTest();  // concrete test functionality is defined by the subclass
    protected abstract String Title { get; }   // the test case title is defined by the subclass
  }

  /************************************************************************/
  /* The test case checks the lock state depending to the velocity. If the
   * velocity is increasing the car should be locked automatically if the 
   * velocity is greater than 50. If the velocity is decreasing the car 
   * should stay locked.
  /************************************************************************/
  public class LockStateDependsOnlyOnVelocity : LockStateTestBase
  {
    protected override String Title
    {
      get { return "Lock the car at great velocities"; }
    }

    protected override void DoConcreteTest()
    {
      // Wait until the velocity is greater than 50
      if (Execution.Wait(new ValueCriterion<Velocity>(Relation.Greater, 50), 3000) == Execution.WAIT_TIMEOUT)
        Report.TestStepFail("Check lock state", "Increasing the velocity within the timeout fails.");

      // Check the verdict of the test pattern
      if ((new LockStateTest()).Execute() == Verdict.Failed)
      {
        // Set the value manually, so the test for the falling edge can be done anyway
        LockState.Value = 1;
        Execution.Wait<LockState>(1);
      }

      // The lock state should not change while decreasing the velocity
      using (ICheck lockedCondition = new ValueCheck<LockState>(1))
      {
        lockedCondition.Activate();

        // Wait until the velocity is zero
        if (Execution.Wait<Velocity>(0, 4000) == Execution.WAIT_TIMEOUT)
          Report.TestStepFail("Check lock state", "Decreasing the velocity within the timeout fails.");
        lockedCondition.Deactivate();
      }
    }
  }

  /************************************************************************/
  /* The test case checks the crash detection system of the car. In case
   * of crash detection the car must be unlocked within a specified time.
   * If the velocity changes after the crash detection the car should stay 
   * unlocked.
  /************************************************************************/
  public class LockStateDependsOnCrashDetection : LockStateTestBase
  {
    protected override string Title
    {
      get { return "Unlock the car because of crash detection"; }
    }

    protected override void DoConcreteTest()
    {
      // Wait until the car is locked
      Execution.Wait<LockState>(1);

      // Test Pattern - Crash Detection function test
      CrashDetectionTest crashTest = new CrashDetectionTest();
      crashTest.Execute();

      // The lock state should not change while decreasing the velocity
      using (ICheck unLockedCondition = new ValueCheck<LockState>(0))
      {
        unLockedCondition.Activate();

        // Wait until the velocity is zero
        if (Execution.Wait<Velocity>(0, 4000) == Execution.WAIT_TIMEOUT)
          Report.TestStepFail("Check lock state", "Decreasing the velocity within the timeout fails.");

        unLockedCondition.Deactivate();
      }
    }
  }

  #endregion

  #region Test Cases by simple functions
  /************************************************************************/
  /* The test case checks the crash detection while the engine is off.
  /* The car should stay locked.
  /************************************************************************/
  [TestCase("Crash detection while engine is off")]
  public void CrashDetection()
  {
    // Engine is off and car is locked
    EngineRunning.Value = 0;
    LockState.Value = 1;
    Execution.Wait(500);

    CrashDetectionTest crashTest = new CrashDetectionTest();
    crashTest.lockState = 1; // car should stay locked
    crashTest.Execute();

    LockState.Value = 0;
  }
  /************************************************************************/
  /* The test case checks the open and close of the windows.
  /************************************************************************/
  [TestCase]
  public void SimpleWindowTest(UInt16 open)
  {
    Report.TestCaseTitle(open == 1 ? "Open the window" : "Close the window");
    WindowTest checkWindows = new WindowTest();
    // Start the window lifts
    checkWindows.Description = open == 1 ? "Start opening the window. Check if the window is really opened." : "Start closing the window. Check if the window is really closed.";
    checkWindows.Wait = 1500;
    checkWindows.KeyDown = open == 1 ? 1 : 0;
    checkWindows.KeyUp = open == 1 ? 0 : 1;
    checkWindows.WindowMotion = open == 1 ? 2 : 1;
    checkWindows.Execute();
    // Stop the window lifts
    checkWindows.Description = open == 1 ? "Stop opening the window. Check if the window is halted very soon." : "Stop closing the window. Check if the window is halted very soon.";
    checkWindows.Wait = 100;
    checkWindows.KeyDown = 0;
    checkWindows.KeyUp = 0;
    checkWindows.WindowMotion = 0;
    checkWindows.Execute();
  }
  /************************************************************************/
  /* The test case checks the comfort close of the car.
  /************************************************************************/
  [TestCase("Check comfort close")]
  public void ComfortClose()
  {
    Report.TestStep("Open the window");
    KeyDown.Value = 1;
    Execution.Wait(1500);
    KeyDown.Value = 0;
    Execution.Wait(50);

    Report.TestStep("Start comfort close and check the closing of the windows");
    LockRequest.Value = 3;
    Execution.Wait(500);
    ICheck observeClosing = new ValueCheck<WindowMotion>(1);
    observeClosing.Activate();
    Execution.Wait(1000);
    LockRequest.Value = 0;
    Execution.Wait(1000);
    observeClosing.Deactivate();
    LockRequest.Value = 2;
    Execution.Wait(200);
  }

  #endregion

  #region Test Patterns
  /************************************************************************/
  /* Test pattern to check the lock state after a specified time.
  /************************************************************************/
  public class LockStateTest : StateChange
  {
    public LockStateTest()
    {
      Description = "Checks the lock state of the car";
      Wait = 110;
    }

    [Expected(typeof(LockState), Relation.Equal)]
    public double lockState = 1;
  }

  /************************************************************************/
  /* Test pattern to check the crash detection.
  /************************************************************************/
  public class CrashDetectionTest : StateChange
  {
    public CrashDetectionTest()
    {
      Description = "Checks the unlock of the car, if a crash will be detected";
      Wait = 200;
    }

    [Input(typeof(NetworkDB.CrashDetected))]
    public double crashDetected = 1;

    [Expected(typeof(NetworkDB.LockState), Relation.Equal)]
    public double lockState = 0;
  }

  /************************************************************************/
  /* Test pattern to check the window lifts.
  /************************************************************************/
  public class WindowTest : StateChange
  {
    [Input(typeof(NetworkDB.KeyUp))]
    public double KeyUp = 0;
    [Input(typeof(NetworkDB.KeyDown))]
    public double KeyDown = 0;
    [Expected(typeof(NetworkDB.WindowMotion))]
    public double WindowMotion = 0;
  }

  #endregion

  #region CriterionHandler
  /************************************************************************/
  /* Handler that is used for global observation of the anti theft system
   * The anti-theft system should active, if the engine is not running
   * and the car is locked.
  /************************************************************************/
  [Criterion]
  [OnChange(typeof(AntiTheftSystemActive))]
  [OnChange(typeof(LockState))]
  bool AntiTheftSystemCriterion()
  {
    if((EngineRunning.Value == 0) && (LockState.Value == 1))
      return (AntiTheftSystemActive.Value == 1);
    else
      return (AntiTheftSystemActive.Value == 0);
  }
  #endregion
}

