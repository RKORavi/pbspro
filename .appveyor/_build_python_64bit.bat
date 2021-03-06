@echo off
REM Copyright (C) 1994-2019 Altair Engineering, Inc.
REM For more information, contact Altair at www.altair.com.
REM
REM This file is part of the PBS Professional ("PBS Pro") software.
REM
REM Open Source License Information:
REM
REM PBS Pro is free software. You can redistribute it and/or modify it under the
REM terms of the GNU Affero General Public License as published by the Free
REM Software Foundation, either version 3 of the License, or (at your option) any
REM later version.
REM
REM PBS Pro is distributed in the hope that it will be useful, but WITHOUT ANY
REM WARRANTY; without even the implied warranty of MERCHANTABILITY or FITNESS FOR A
REM PARTICULAR PURPOSE.  See the GNU Affero General Public License for more details.
REM
REM You should have received a copy of the GNU Affero General Public License along
REM with this program.  If not, see <http://www.gnu.org/licenses/>.
REM
REM Commercial License Information:
REM
REM The PBS Pro software is licensed under the terms of the GNU Affero General
REM Public License agreement ("AGPL"), except where a separate commercial license
REM agreement for PBS Pro version 14 or later has been executed in writing with Altair.
REM
REM Altair’s dual-license business model allows companies, individuals, and
REM organizations to create proprietary derivative works of PBS Pro and distribute
REM them - whether embedded or bundled with other software - under a commercial
REM license agreement.
REM
REM Use of Altair’s trademarks, including but not limited to "PBS™",
REM "PBS Professional®", and "PBS Pro™" and Altair’s logos is subject to Altair's
REM trademark licensing policies.

@echo on
setlocal

call "%~dp0set_paths.bat" %~1

cd "%BINARIESDIR%"

if not defined PYTHON_VERSION (
    echo "Please set PYTHON_VERSION to Python version!"
    exit /b 1
)

if exist "%BINARIESDIR%\python_x64" (
    echo "%BINARIESDIR%\python_x64 exist already!"
    exit /b 0
)

if not exist "%BINARIESDIR%\cpython-%PYTHON_VERSION%.zip" (
    "%CURL_BIN%" -qkL -o "%BINARIESDIR%\cpython-%PYTHON_VERSION%.zip" https://github.com/python/cpython/archive/v%PYTHON_VERSION%.zip
    if not exist "%BINARIESDIR%\cpython-%PYTHON_VERSION%.zip" (
        echo "Failed to download python"
        exit /b 1
    )
)
2>nul rd /S /Q "%BINARIESDIR%\cpython-%PYTHON_VERSION%"
"%UNZIP_BIN%" -q "%BINARIESDIR%\cpython-%PYTHON_VERSION%.zip"
cd "%BINARIESDIR%\cpython-%PYTHON_VERSION%"

REM Restore externals directory if python_externals.tar.gz exists
if exist "%BINARIESDIR%\python_externals.tar.gz" (
    if not exist "%BINARIESDIR%\cpython-%PYTHON_VERSION%\externals" (
        "%MSYSDIR%\bin\bash" --login -i -c "cd \"$BINARIESDIR_M/cpython-$PYTHON_VERSION\" && tar -xf \"$BINARIESDIR_M/python_externals.tar.gz\""
    )
) else (
    call "%BINARIESDIR%\cpython-%PYTHON_VERSION%\PCbuild\get_externals.bat"
)

REM workaround to openssl build fail
2>nul del /Q /F "%BINARIESDIR%\cpython-%PYTHON_VERSION%\externals\openssl-1.0.2j\ms\nt64.mak"

if exist "%VS90COMNTOOLS%..\..\VC\bin\amd64\vcvarsamd64.bat" (
    call "%VS90COMNTOOLS%..\..\VC\bin\amd64\vcvarsamd64.bat"
) else if exist "%VS90COMNTOOLS%..\..\VC\bin\vcvarsx86_amd64.bat" (
    call "%VS90COMNTOOLS%..\..\VC\bin\vcvarsx86_amd64.bat"
) else (
    echo "Could not find x64 build tools for Visual Studio"
    exit /b 1
)

call "%BINARIESDIR%\cpython-%PYTHON_VERSION%\PC\VS9.0\build.bat" -e -p x64
if not %ERRORLEVEL% == 0 (
    echo "Failed to compile Python 64bit"
    exit /b 1
)

REM Workaround for cabarc.exe, required by msi.py
if not exist "%BINARIESDIR%\cabarc.exe" (
    if not exist "%BINARIESDIR%\supporttools.exe" (
        "%CURL_BIN%" -qkL -o "%BINARIESDIR%\supporttools.exe" http://download.microsoft.com/download/d/3/8/d38066aa-4e37-4ae8-bce3-a4ce662b2024/WindowsXP-KB838079-SupportTools-ENU.exe
        if not exist "%BINARIESDIR%\supporttools.exe" (
            echo "Failed to download supporttools.exe"
            exit /b 1
        )
    )
    2>nul rd /S /Q "%BINARIESDIR%\cpython-%PYTHON_VERSION%\cabarc_temp"
    mkdir "%BINARIESDIR%\cpython-%PYTHON_VERSION%\cabarc_temp"
    "%BINARIESDIR%\supporttools.exe" /C /T:"%BINARIESDIR%\cpython-%PYTHON_VERSION%\cabarc_temp"
    expand "%BINARIESDIR%\cpython-%PYTHON_VERSION%\cabarc_temp\support.cab" -F:cabarc.exe "%BINARIESDIR%"
)
set PATH=%BINARIESDIR%;%PATH%

REM Workaround for python2713.chm
mkdir "%BINARIESDIR%\cpython-%PYTHON_VERSION%\Doc\build\htmlhelp"
echo "dummy chm file to make msi.py happy" > "%BINARIESDIR%\cpython-%PYTHON_VERSION%\Doc\build\htmlhelp\python%PYTHON_VERSION:.=%.chm"

cd PC
REM we need 32bit compiler as python icons does not compile in 64bit
call "%VS90COMNTOOLS%vsvars32.bat"
nmake /f "%BINARIESDIR%\cpython-%PYTHON_VERSION%\PC\icons.mak"
if not %ERRORLEVEL% == 0 (
    echo "Failed to build icons for Python 64bit"
    exit /b 1
)

REM Restore back 64 bit compiler
if exist "%VS90COMNTOOLS%..\..\VC\bin\amd64\vcvarsamd64.bat" (
    call "%VS90COMNTOOLS%..\..\VC\bin\amd64\vcvarsamd64.bat"
) else if exist "%VS90COMNTOOLS%..\..\VC\bin\vcvarsx86_amd64.bat" (
    call "%VS90COMNTOOLS%..\..\VC\bin\vcvarsx86_amd64.bat"
) else (
    echo "Could not find x64 build tools for Visual Studio"
    exit /b 1
)

cd "%BINARIESDIR%\cpython-%PYTHON_VERSION%\Tools\msi"
set PCBUILD=PC\VS9.0\amd64
set SNAPSHOT=0
"%BINARIESDIR%\cpython-%PYTHON_VERSION%\%PCBUILD%\python.exe" -m ensurepip -U --default-pip
if not %ERRORLEVEL% == 0 (
    echo "Failed to run ensurepip for Python 64bit"
    exit /b 1
)
set PIP_EXTRA_ARGS=
if exist "%BINARIESDIR%\pypiwin32-219-cp27-none-win_amd64.whl" (
    set PIP_EXTRA_ARGS=--no-index --find-links="%BINARIESDIR%" --no-cache-dir
)
"%BINARIESDIR%\cpython-%PYTHON_VERSION%\%PCBUILD%\python.exe" -m pip install %PIP_EXTRA_ARGS% pypiwin32==219
if not %ERRORLEVEL% == 0 (
    echo "Failed to install pypiwin32 for Python 64bit"
    exit /b 1
)
"%BINARIESDIR%\cpython-%PYTHON_VERSION%\%PCBUILD%\python.exe" msi.py
if not exist "%BINARIESDIR%\cpython-%PYTHON_VERSION%\Tools\msi\python-%PYTHON_VERSION%150.amd64.msi" (
    echo "Failed to generate msi Python 64bit"
    exit /b 1
)

start /wait msiexec /qn /a "%BINARIESDIR%\cpython-%PYTHON_VERSION%\Tools\msi\python-%PYTHON_VERSION%150.amd64.msi" TARGETDIR="%BINARIESDIR%\python_x64"
if not %ERRORLEVEL% == 0 (
    echo "Failed to extract msi Python 64bit to %BINARIESDIR%\python_x64"
    exit /b 1
)
"%BINARIESDIR%\python_x64\python.exe" -Wi "%BINARIESDIR%\python_x64\Lib\compileall.py" -q -f -x "bad_coding|badsyntax|site-packages|py3_" "%BINARIESDIR%\python_x64\Lib"
"%BINARIESDIR%\python_x64\python.exe" -O -Wi "%BINARIESDIR%\python_x64\Lib\compileall.py" -q -f -x "bad_coding|badsyntax|site-packages|py3_" "%BINARIESDIR%\python_x64\Lib"
"%BINARIESDIR%\python_x64\python.exe" -c "import lib2to3.pygram, lib2to3.patcomp;lib2to3.patcomp.PatternCompiler()"
"%BINARIESDIR%\python_x64\python.exe" -m ensurepip -U --default-pip
if not %ERRORLEVEL% == 0 (
    echo "Failed to run ensurepip in %BINARIESDIR%\python_x64 for Python 64bit"
    exit /b 1
)
"%BINARIESDIR%\python_x64\python.exe" -m pip install %PIP_EXTRA_ARGS% pypiwin32==219
if not %ERRORLEVEL% == 0 (
    echo "Failed to install pypiwin32 in %BINARIESDIR%\python_x64 for Python 64bit"
    exit /b 1
)
copy /B /Y "%VS90COMNTOOLS%..\..\VC\redist\amd64\Microsoft.VC90.CRT\msvcr90.dll" "%BINARIESDIR%\python_x64\"
if not %ERRORLEVEL% == 0 (
    echo "Failed to copy msvcr90.dll in %BINARIESDIR%\python_x64 for Python 64bit"
    exit /b 1
)
copy /B /Y "%VS90COMNTOOLS%..\..\VC\redist\amd64\Microsoft.VC90.CRT\Microsoft.VC90.CRT.manifest" "%BINARIESDIR%\python_x64\"
if not %ERRORLEVEL% == 0 (
    echo "Failed to copy Microsoft.VC90.CRT.manifest in %BINARIESDIR%\python_x64 for Python 64bit"
    exit /b 1
)


cd "%BINARIESDIR%"
2>nul rd /S /Q "%BINARIESDIR%\cpython-%PYTHON_VERSION%"
2>nul del /Q /F "%BINARIESDIR%\cabarc.exe"

exit /b 0

