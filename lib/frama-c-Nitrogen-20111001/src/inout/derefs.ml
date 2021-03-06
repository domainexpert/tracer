(**************************************************************************)
(*                                                                        *)
(*  This file is part of Frama-C.                                         *)
(*                                                                        *)
(*  Copyright (C) 2007-2011                                               *)
(*    CEA (Commissariat � l'�nergie atomique et aux �nergies              *)
(*         alternatives)                                                  *)
(*                                                                        *)
(*  you can redistribute it and/or modify it under the terms of the GNU   *)
(*  Lesser General Public License as published by the Free Software       *)
(*  Foundation, version 2.1.                                              *)
(*                                                                        *)
(*  It is distributed in the hope that it will be useful,                 *)
(*  but WITHOUT ANY WARRANTY; without even the implied warranty of        *)
(*  MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the         *)
(*  GNU Lesser General Public License for more details.                   *)
(*                                                                        *)
(*  See the GNU Lesser General Public License version 2.1                 *)
(*  for more details (enclosed in the file licenses/LGPLv2.1).            *)
(*                                                                        *)
(**************************************************************************)

open Cil_types
open Cil
open Db
open Locations
open Abstract_value
open Abstract_interp


class virtual do_it_ = object(self)
  inherit [Zone.t] Cumulative_analysis.cumulative_visitor as super
  val mutable derefs = Zone.bottom

  method bottom = Zone.bottom

  method result = derefs

  method join new_ =
    derefs <- Zone.join new_ derefs;

  method vlval (base,_ as lv) =
    begin match base with
      | Var _ -> ()
      | Mem e ->
          let state =
            Value.get_state
              (Kstmt (Cilutil.out_some self#current_stmt))
          in
          let r = !Value.eval_expr  ~with_alarms:CilE.warn_none_mode state e in
          self#join
            (valid_enumerate_bits ~for_writing:false
                (loc_without_size_to_loc lv r))
    end;
    DoChildren

  method compute_funspec (_: kernel_function) =
    Zone.bottom

  method clean_kf_result (_ : kernel_function) (r: Locations.Zone.t) = r

end

module Analysis = Cumulative_analysis.Make(
  struct
    let analysis_name ="derefs"

    type t = Locations.Zone.t
    module T = Locations.Zone
    let bottom = Locations.Zone.bottom

    class virtual do_it = do_it_
end)

let get_internal = Analysis.kernel_function

let externalize _return fundec x =
  Zone.filter_base
    (fun v -> not (Base.is_formal_or_local v fundec))
    x

module Externals =
  Kf_state.Make
    (struct
       let name = "External derefs"
       let dependencies = [ Analysis.Memo.self ]
       let kind = `Correctness
     end)

let get_external =
  Externals.memo
    (fun kf ->
       !Value.compute ();
       if Kernel_function.is_definition kf then
         try
           externalize
             (Kernel_function.find_return kf)
             (Kernel_function.get_definition kf)
             (get_internal kf)
         with Kernel_function.No_Statement ->
           assert false
       else
         (* assume there is no deref for leaf functions *)
         Zone.bottom)

let compute_external kf = ignore (get_external kf)

let pretty_internal fmt kf =
  Format.fprintf fmt "@[Derefs (internal) for function %a:@\n@[<hov 2>  %a@]@]@\n"
    Kernel_function.pretty kf
    Zone.pretty (get_internal kf)

let pretty_external fmt kf =
  Format.fprintf fmt "@[Derefs for function %a:@\n@[<hov 2>  %a@]@]@\n"
    Kernel_function.pretty kf
    Zone.pretty (get_external kf)

let () =
  Db.Derefs.self_internal := Analysis.Memo.self;
  Db.Derefs.self_external := Externals.self;
  Db.Derefs.get_internal := get_internal;
  Db.Derefs.get_external := get_external;
  Db.Derefs.compute := compute_external;
  Db.Derefs.display := pretty_external;
  Db.Derefs.statement := Analysis.statement
