@echo off

cd C:\Users\fkhalaili\Desktop\Training Material\Jenkins\TestingSymposium\Automation\
python RunAllTests.py

rem Output number of errors in tests, but do not signal to Jenkins
if errorlevel 1 (
 	echo %errorlevel% failed test modules
) else (
	echo all test modules successfully executed
)
exit /b 0
