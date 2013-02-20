''
'' fbmld (FB Memory Leak Detector) version 0.5
'' Copyright (C) 2006 Daniel R. Verkamp
''
'' This software is provided 'as-is', without any express or implied warranty. 
'' In no event will the authors be held liable for any damages arising from 
'' the use of this software.
'' 
'' Permission is granted to anyone to use this software for any purpose, 
'' including commercial applications, and to alter it and redistribute it 
'' freely, subject to the following restrictions:
'' 
'' 1. The origin of this software must not be misrepresented; you must not claim 
'' that you wrote the original software. If you use this software in a product, 
'' an acknowledgment in the product documentation would be appreciated but is 
'' not required.
'' 
'' 2. Altered source versions must be plainly marked as such, and must not be 
'' misrepresented as being the original software.
'' 
'' 3. This notice may not be removed or altered from any source 
'' distribution. 
''

#ifndef __FBMLD__
#define __FBMLD__

#include "crt.bi"

#undef allocate
#undef callocate
#undef reallocate
#undef deallocate

#define allocate(bytes) fbmld_allocate((bytes), __FILE__, __LINE__)
#define callocate(bytes) fbmld_callocate((bytes), __FILE__, __LINE__)
#define reallocate(pt, bytes) fbmld_reallocate((pt), (bytes), __FILE__, __LINE__)
#define deallocate(pt) fbmld_deallocate((pt), __FILE__, __LINE__, #pt)

type fbmld_t
	pt as any ptr
	bytes as uinteger
	file as string
	linenum as integer
	_next as fbmld_t ptr
	_prev as fbmld_t ptr
end type

common shared fbmld_list as fbmld_t ptr
common shared fbmld_atexit_installed as integer
common shared fbmld_mutex as any ptr
common shared fbmld_instances as integer

private sub fbmld_print(byref s as string)
	fprintf(stderr, "(FBMLD) " & s & chr(10))
end sub

private sub fbmld_mutexlock( )
#ifndef FBMLD_NO_MULTITHREADING
	mutexlock(fbmld_mutex)
#endif
end sub

private sub fbmld_mutexunlock( )
#ifndef FBMLD_NO_MULTITHREADING
	mutexunlock(fbmld_mutex)
#endif
end sub

private function fbmld_find(byval pt as any ptr) as fbmld_t ptr
	dim elem as fbmld_t ptr
	
	fbmld_mutexlock
	
	elem = fbmld_list
	
	do while elem <> 0
		if elem->pt = pt then
			fbmld_mutexunlock
			return elem
		end if
		
		elem = elem->_next
	loop
	
	fbmld_mutexunlock
	
	return 0
end function

private sub fbmld_add(byval pt as any ptr, byval bytes as uinteger, byref file as string, byval linenum as integer)
	dim elem as fbmld_t ptr
	
	fbmld_mutexlock
	
	elem = calloc(1, sizeof(fbmld_t))
	elem->pt = pt
	elem->bytes = bytes
	elem->file = file
	elem->linenum = linenum
	elem->_next = fbmld_list
	if fbmld_list <> 0 then
		fbmld_list->_prev = elem
	end if
	fbmld_list = elem
	
	fbmld_mutexunlock
	
end sub

private sub fbmld_remove(byval elem as fbmld_t ptr)
	dim _next as fbmld_t ptr
	
	fbmld_mutexlock
	
	if elem->_next <> 0 then
		elem->_next->_prev = elem->_prev
	end if
	
	if elem->_prev <> 0 then
		elem->_prev->_next = elem->_next
	end if
	
	elem->file = ""
	_next = elem->_next
	
	free(elem)
	
	if elem = fbmld_list then
		fbmld_list = _next
	end if
	
	fbmld_mutexunlock
	
end sub

private sub fbmld_init() constructor
	if fbmld_instances = 0 then
#ifndef FBMLD_NO_MULTITHREADING
		fbmld_mutex = mutexcreate()
#endif
	end if
	fbmld_instances += 1
end sub

private sub fbmld_exit() destructor
	dim elem as fbmld_t ptr, n as fbmld_t ptr
	
	fbmld_instances -= 1
	
	if fbmld_instances = 0 then
		
		if fbmld_list <> 0 then
			
			elem = fbmld_list
			fbmld_list = 0
			
			do while elem <> 0
				fbmld_print(elem->bytes & " bytes allocated at " & elem->file & ":" & elem->linenum & " [&H" & hex(elem->pt) & "] not deallocated!")
				elem->file = ""
				n = elem->_next
				free(elem)
				elem = n
			loop
		else
			fbmld_print("All memory deallocated")
		end if
		
#ifndef FBMLD_NO_MULTITHREADING
		if fbmld_mutex <> 0 then
			mutexdestroy(fbmld_mutex)
			fbmld_mutex = 0
		end if
#endif
	end if
end sub

private function fbmld_allocate(byval bytes as uinteger, byref file as string, byval linenum as integer) as any ptr
	dim ret as any ptr
	
	ret = malloc(bytes)
	fbmld_add(ret, bytes, file, linenum)
	return ret
end function

private function fbmld_callocate(byval bytes as uinteger, byref file as string, byval linenum as integer) as any ptr
	dim ret as any ptr
	
	ret = calloc(1, bytes)
	fbmld_add(ret, bytes, file, linenum)
	return ret
end function

private function fbmld_reallocate(byval pt as any ptr, byval bytes as uinteger, byref file as string, byval linenum as integer) as any ptr
	dim ret as any ptr
	dim elem as fbmld_t ptr
	
	ret = realloc(pt, bytes)
	elem = fbmld_find(pt)
	if elem = 0 then
		fbmld_add(ret, bytes, file, linenum)
	else
		elem->pt = ret
		elem->bytes = bytes
		elem->file = file
		elem->linenum = linenum
	end if
	
	return ret
end function

private sub fbmld_deallocate(byval pt as any ptr, byref file as string, byval linenum as integer, byref varname as string)
	dim elem as fbmld_t ptr
	
	if pt <> 0 then
		elem = fbmld_find(pt)
	end if
	if elem = 0 then
		fbmld_print("Invalid deallocate(" & varname & ") [&H" & hex(pt) & "] at " & file & ":" & linenum)
	else
		fbmld_remove(elem)
	end if
	
	free(pt)
end sub

#endif '' __FBMLD__