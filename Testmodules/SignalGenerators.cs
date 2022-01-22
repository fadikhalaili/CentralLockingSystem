using System;
using System.Collections.Generic;
using System.Text;
using Vector.CANoe.Runtime;
using Vector.Tools;

namespace SignalGenerators
{
  /// <summary>
  /// Interface for a signal generator.
  /// </summary>
  public interface IGenerator : IDisposable
  {
    bool Start();
    void Stop();
  }

  /// <summary>
  /// Abstract base class for a generator. Provides the infrastructure
  /// </summary>
  /// <typeparam name="T"> The signal that should be used by the generator </typeparam>
  public abstract class AbstractGenerator<T> : IGenerator where T : class, Vector.CANoe.Runtime.IRuntimeValue
  {
    protected AbstractGenerator(int cycle)
    {
      CycleTime = cycle;
    }

    // Concrete generators have to calculate the signal value here
    protected abstract double CalcValue(TimeSpan currentTime);

    // Concrete signal generators have to check their parameters to allow the start of the generator
    protected abstract bool ParametersOK();

    // Concrete signal generators need that to calculate the next value
    protected double StartTime { get { return mStartTime; } }

    public int CycleTime
    {
      get { return mCycleTime; }
      set
      {
        mCycleTime = value;
        if (mStarted)
        {
          mSignalPushTimer.Interval = TimeSpan.FromMilliseconds(mCycleTime);
        }
      }
    }

    private bool AllParametersOK()
    {
      return (mCycleTime > 0) && ParametersOK();
    }

    // Timer elapsed handler - calculates and sets the signal value
    public void PushValue(Object o, ElapsedEventArgs e)
    {
      RuntimeObject<T>.Value = CalcValue(Measurement.CurrentTime);
    }

    public bool Start()
    {
      if (!mStarted)
      {
        if (AllParametersOK())
        {
          if (mSignalPushTimer == null)
            mSignalPushTimer = new Timer(PushValue);

          mSignalPushTimer.AutoReset = true;
          mStartTime = Measurement.CurrentTime.TotalMilliseconds;
          mSignalPushTimer.Interval = TimeSpan.FromMilliseconds(mCycleTime);
          mSignalPushTimer.Start();
          mStarted = true;
          return true;
        }
        else
          Vector.Tools.Output.WriteLine("Preconditions are not fulfilled to start the signal generator", "Test");
      }

      return false;
    }

    public void Stop()
    {
      if (mStarted)
      {
        mSignalPushTimer.Stop();
        mSignalPushTimer.Dispose();
        mSignalPushTimer = null;
        mStarted = false;
      }
    }

    public void Dispose()
    {
      Stop();
    }

    private int mCycleTime;
    private Timer mSignalPushTimer;
    private bool mStarted = false;
    private double mStartTime = 0;
  }

  /// <summary>
  /// Ramp generator
  /// </summary>
  public class RampGenerator<T> : AbstractGenerator<T> where T : class, Vector.CANoe.Runtime.IRuntimeValue
  {
    public RampGenerator(double highBorder, double lowBorder, int delayBefore,
                         int riseTime, int holdTime, int fallTime, int cycleTime, bool repeat)
      : base(cycleTime)
    {
      mHighBorder = highBorder;
      mLowBorder = lowBorder;
      mDelayBefore = delayBefore;
      mRiseTime = riseTime;
      mHoldTime = holdTime;
      mFallTime = fallTime;
      mRepeat = repeat;
      CalcFactors();
      CalcPeriod();
    }

    // calculates the factors of the rising and falling edge
    private void CalcFactors()
    {
      double diff = mHighBorder - mLowBorder;
      mRiseFactor = mRiseTime != 0 ? diff / mRiseTime : 0.0;
      mFallFactor = mFallTime != 0 ? diff / mFallTime : 0.0;
    }

    // calculates the period of the ramp
    private void CalcPeriod() { mPeriod = mDelayBefore + mRiseTime + mHoldTime + mFallTime; }

    protected override double CalcValue(TimeSpan currentTime)
    {
      // calculate time difference since start of the generator
      double time = currentTime.TotalMilliseconds - StartTime;

      if (mRepeat)
        time %= mPeriod;         // calculate the time within a single period
      else if (time >= mPeriod)
        return mLowBorder;       // if there is no repeat mode the low border value is returned

      // delay before rising the value
      if (time <= mDelayBefore)
        return mLowBorder;

      // value of the rising edge
      time -= mDelayBefore;
      if (time < mRiseTime)
        return mHighBorder - (mRiseTime - time) * mRiseFactor;

      // value of the hold time
      time -= mRiseTime;
      if (time <= mHoldTime)
        return mHighBorder;

      // value of the falling edge
      time -= mHoldTime;
      if (time < mFallTime)
        return mLowBorder - (time - mFallTime) * mFallFactor;

      return mLowBorder;
    }

    protected override bool ParametersOK()
    {
      return (mPeriod > 0) && (mHighBorder > mLowBorder);
    }

    private double mHighBorder;
    private double mLowBorder;
    private int mDelayBefore;
    private int mRiseTime;
    private int mHoldTime;
    private int mFallTime;
    private bool mRepeat;

    private double mRiseFactor;
    private double mFallFactor;
    private int mPeriod;
  }
}
