About
=====

FBMLD is a FreeBASIC Memory Leak Detector.
FBMLD replaces the built-in allocate functions
and produces a report of memory that hasn't been freed at the end of the program.
It also notifies you immediately when attempting to double-free or free a pointer that wasn't returned from an allocate function.
It works in single- and multi-module programs, and it is thread-safe/reentrant.

Usage
=====

To use FBMLD, include the header (which can be placed either in the same directory as your code or in the global `FreeBASIC/inc/` directory) before any other code.
The memory leak report will be printed to `stderr` (generally, `stderr` is the console).

    #include "fbmld.bi"

    ' code involving allocate/callocate/reallocate/deallocate

To use FBMLD in a multi-module program, include the header in each source file (`.bas`) you wish to monitor for memory leaks.
Allocated memory is tracked globally, so memory allocated in one module may be freed in another.

If you do not want to link with the multithreaded runtime or do not need FBMLD to be thread-safe,
define `FBMLD_NO_MULTITHREADING` with the preprocessor before including the header:

    #define FBMLD_NO_MULTITHREADING
    #include "fbmld.bi"

