(**************************************************************************)
(*                                                                        *)
(*  Copyright (C) 2001-2003                                               *)
(*   George C. Necula    <necula@cs.berkeley.edu>                         *)
(*   Scott McPeak        <smcpeak@cs.berkeley.edu>                        *)
(*   Wes Weimer          <weimer@cs.berkeley.edu>                         *)
(*   Ben Liblit          <liblit@cs.berkeley.edu>                         *)
(*  All rights reserved.                                                  *)
(*                                                                        *)
(*  Redistribution and use in source and binary forms, with or without    *)
(*  modification, are permitted provided that the following conditions    *)
(*  are met:                                                              *)
(*                                                                        *)
(*  1. Redistributions of source code must retain the above copyright     *)
(*  notice, this list of conditions and the following disclaimer.         *)
(*                                                                        *)
(*  2. Redistributions in binary form must reproduce the above copyright  *)
(*  notice, this list of conditions and the following disclaimer in the   *)
(*  documentation and/or other materials provided with the distribution.  *)
(*                                                                        *)
(*  3. The names of the contributors may not be used to endorse or        *)
(*  promote products derived from this software without specific prior    *)
(*  written permission.                                                   *)
(*                                                                        *)
(*  THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDERS AND CONTRIBUTORS   *)
(*  "AS IS" AND ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT     *)
(*  LIMITED TO, THE IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS     *)
(*  FOR A PARTICULAR PURPOSE ARE DISCLAIMED. IN NO EVENT SHALL THE        *)
(*  COPYRIGHT OWNER OR CONTRIBUTORS BE LIABLE FOR ANY DIRECT, INDIRECT,   *)
(*  INCIDENTAL, SPECIAL, EXEMPLARY, OR CONSEQUENTIAL DAMAGES (INCLUDING,  *)
(*  BUT NOT LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS OR SERVICES;      *)
(*  LOSS OF USE, DATA, OR PROFITS; OR BUSINESS INTERRUPTION) HOWEVER      *)
(*  CAUSED AND ON ANY THEORY OF LIABILITY, WHETHER IN CONTRACT, STRICT    *)
(*  LIABILITY, OR TORT (INCLUDING NEGLIGENCE OR OTHERWISE) ARISING IN     *)
(*  ANY WAY OUT OF THE USE OF THIS SOFTWARE, EVEN IF ADVISED OF THE       *)
(*  POSSIBILITY OF SUCH DAMAGE.                                           *)
(*                                                                        *)
(*  File modified by CEA (Commissariat � l'�nergie atomique et aux        *)
(*                        �nergies alternatives).                         *)
(**************************************************************************)

open Cil_types
let gcc = {
(* Generated by code in cil/src/machdep.c *)
	 version_major    = 1;
	 version_minor    = 0;
	 version          = 
    "x86 16 bits mode (gcc like compiler) with big or huge memory model";
	 sizeof_short     = 2;
	 sizeof_int       = 2;
	 sizeof_long      = 4;
	 sizeof_longlong  = 8;
	 sizeof_ptr       = 4;
	 sizeof_float     = 4;
	 sizeof_double    = 8;
	 sizeof_longdouble  = 16;
	 (*sizeof_wchar     = 4;*)
	 (*sizeof_sizeof    = 4;*)
	 sizeof_void      = 1;
	 sizeof_fun       = 1;
	 alignof_short = 2;
	 alignof_int = 2;
	 alignof_long = 4;
	 alignof_longlong = 4;
	 alignof_ptr = 4;
	 alignof_float = 4;
	 alignof_double = 8;
	 alignof_longdouble = 16;
	 alignof_str = 1;
	 alignof_fun = 1;
	 alignof_char_array = 1;
         alignof_aligned= 8;
         (* I don't know if attribute aligned is supported by any 16bits 
            compiler. *)
	 char_is_unsigned = false;
	 const_string_literals = true;
	 little_endian = true;
	 underscore_name = true ;
	 size_t = "unsigned int";
	 wchar_t = "int";
	 ptrdiff_t = "int";
}
let hasMSVC = false
let msvc = {
(* Generated by code in cil/src/machdep.c *)
	 version_major    = 1;
	 version_minor    = 0;
	 version          = 
    "x86 16 bits mode (msvc like compiler) with big or huge memory model";
	 sizeof_short     = 2;
	 sizeof_int       = 2;
	 sizeof_long      = 4;
	 sizeof_longlong  = 8;
	 sizeof_ptr       = 4;
	 sizeof_float     = 4;
	 sizeof_double    = 8;
	 sizeof_longdouble  = 16;
	 (*sizeof_wchar     = 4;*)
	 (*sizeof_sizeof    = 4;*)
	 sizeof_void      = 1;
	 sizeof_fun       = 1;
	 alignof_short = 2;
	 alignof_int = 2;
	 alignof_long = 4;
	 alignof_longlong = 4;
	 alignof_ptr = 4;
	 alignof_float = 4;
	 alignof_double = 8;
	 alignof_longdouble = 16;
	 alignof_str = 1;
	 alignof_fun = 1;
	 alignof_char_array = 1;
         alignof_aligned= 8;
         (* I don't know if attribute aligned is supported by any 16bits 
            compiler. *)
	 char_is_unsigned = false;
	 const_string_literals = true;
	 little_endian = true;
	 underscore_name = true ;
	 size_t = "unsigned int";
	 wchar_t = "int";
	 ptrdiff_t = "int";
}
let gccHas__builtin_va_list = true
let __thread_is_keyword = true
