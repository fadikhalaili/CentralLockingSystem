using System;
using System.Collections.Generic;
using System.Linq;
using System.Text;
using System.Threading.Tasks;
using System.Threading;

namespace csharp_script
{
    class Program
    {
        static void Main(string[] args)
        {
            // access to the application object:
            CANoe.Application application = new CANoe.Application();

            // load a configuration (actual configuration must be unchanged)
            //application.Open(@"C:\Training\TestingSymposium\Automation\CentralLockingSystem\CentralLockingSystem.cfg");
            application.Open(@"C:\Users\fkhalaili\Desktop\Training Material\Jenkins\TestingSymposium\Automation\CentralLockingSystem\CentralLockingSystem.cfg");


            // start measurement and wait 2 seconds
            CANoe.Measurement measurement = application.Measurement;
            measurement.Start();
            Thread.Sleep(2000);  // needs ‘using System.Threading;’

            // Get first testenvirnment and first test module
            CANoe.TestEnvironment testEnvironment = application.Configuration.TestSetup.Testenvironments.Item(1);
            CANoe.TSTestModule testModule = testEnvironment.Items.Item(1);

            // start test mode and wait for completion
            testModule.Start();
            Thread.Sleep(5000);  // needs ‘using System.Threading;’

            //// stope measurement and quit CANoe
            measurement.Stop();
            application.Quit();

        }
    }
}
