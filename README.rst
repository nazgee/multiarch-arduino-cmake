=============
Arduino multiarch & multiplatform CMake
=============

This project is based on https://github.com/queezythegreat/arduino-cmake,
however assumptions made by the project owner forced me to do almost
a complete rewrite. I really did not hardcoding programmer and compiler
invocations, hence this was created.


Features DONE (ESP toolchain only)
------------

* Integrates with *Arduino SDK* and parses it's configuration
* Supports multiple boards & platforms (boiler plate is ready to support any Arduino architecture)
* Generates firmware images
* Generates libraries
* Uploads images to target using default programmer
* Supports multiple build system types (Makefiles, Eclipse, KDevelop, CodeBlocks, XCode, etc).
* Extensible build system, thanks to CMake

Features TODO
-------------

* Supports more arduino toolchains (e.g. AVR, so far only ESP toolchain file is ready)
* Cleanup & fixes
* Add HOWTO


