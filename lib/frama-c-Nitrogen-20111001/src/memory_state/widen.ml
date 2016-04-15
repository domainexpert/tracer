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

(** Undocumented. 
    Do not use this module if you don't know what you are doing. *)

(* [JS 2011/10/03] To the authors/users of this module: please write a mli and 
   document it. *)

open Cil_types
open Cil_datatype

class widen_visitor kf init_widen_hints init_enclosing_loop_info = object
  (* visit all sub-expressions from [kf] definition *)

  inherit Visitor.generic_frama_c_visitor
    (Project.current ()) (Cil.inplace_visit())

  val widen_hints = init_widen_hints
  val enclosing_loop_info = init_enclosing_loop_info

  method vstmt (s:stmt) =
    begin
      let infer_widen_variables bl enclosing_loop_info =
        (* Look at the if-goto and if-break statements.
           The variables of the condition are added to the
           widening variable set for this loop.
           These variables may control the loop. That may be not the case ! *)
        (* Format.printf "Look at widening variables.\n" ; *)
        let visitor = new widen_visitor kf widen_hints enclosing_loop_info
        in
        ignore (Visitor.visitFramacBlock visitor bl);
        Cil.SkipChildren
      in
      begin match s.skind with
      | Loop (_, bl, _, _, _) ->
          let annot = Annotations.get_all_annotations s in
          let l_pragma =
            Ast_info.lift_annot_list_func
              Logic_utils.extract_loop_pragma annot
          in
          let widening_stmts = match bl.bstmts with
            | [] -> [ s]
            | x :: _ -> [ s; x ]
          in
          (* Look at the loop pragmas *)
          let is_pragma_widen_variables = ref false
          in let f p =
            match p with
            | Widen_variables l ->
                let f (lv, lt) t =
                  match t with
                  | { term_node= TLval (TVar {lv_origin = Some vi}, _)} ->
                      let vid = Base.create_varinfo vi in
                      (* Format.printf "Reading user pragma for widening variable: %a.\n"
                         Base.pretty (Base.Var vi); *)
                      (vid::lv, lt)
                  | _ -> (lv, t::lt)
                in
                begin match List.fold_left f ([], []) l with
                | (lv, []) ->
                    (* the annotation is empty or else,
                       there are only variables *)
                    let var_hints =
                      List.fold_left
                        (fun s x -> Base.Set.add x s)
                        Base.Set.empty
                        lv
                    in
                    List.iter
                      (fun widening_stmt ->
                         widen_hints :=
                           Widen_type.add_var_hints
                           widening_stmt
                           var_hints
                           !widen_hints)
                      widening_stmts;
                    is_pragma_widen_variables := true

                | (_lv, _lt) ->
                  Kernel.warning ~once:true ~current:true
                    "could not interpret loop pragma relative to widening \
 variables"
                end
            | Widen_hints l ->
                let f (lv, lnum, lt) t =
                  match t with
                  | { term_node=
                        TLval (TVar { lv_origin = Some vi}, _)} ->
                      let vid = Base.create_varinfo vi in
                      (vid::lv, lnum, lt)
                  | { term_node= TConst (CInt64(v,_,_))} ->
                      let v = Ival.Widen_Hints.V.of_int64 (My_bigint.to_int64 v)
                      in (lv, v::lnum, lt)
                  | _ -> (lv, lnum, t::lt)
                in begin match List.fold_left f ([], [], []) l with
                | (lv, lnum, []) ->
                    (* the annotation is emty or else, there are only variables *)
                    let hints =
                      List.fold_right Ival.Widen_Hints.add lnum Ival.Widen_Hints.empty
                    in
                    List.iter
                      (fun key ->
                         List.iter
                           (fun widening_stmt -> widen_hints :=
                              Widen_type.add_num_hints (Some(widening_stmt))
                                (Widen_type.VarKey(key)) hints !widen_hints)
                           widening_stmts)
                      lv
                | _ ->
                  Kernel.warning ~once:true ~current:true
                    "could not interpret loop pragma relative to widening hint"
                end
            | _ -> ()
          in List.iter f l_pragma ;
          if not !is_pragma_widen_variables then
            let loop =
              try Loop.get_loop_stmts kf s
              with Loop.No_such_while -> assert false
            in
            (* There is no Widen_variables pragma for this loop. *)
            infer_widen_variables bl (Some (widening_stmts, loop))
          else
            Cil.DoChildren
      | If (exp, bl_then, bl_else, _) ->
          begin
            match enclosing_loop_info with
            | None -> ()
            | Some (widening_stmts, loop_stmts) ->
                List.iter
                  (fun bl ->
                     match bl with
                     | {bstmts = []} -> ()
                     | {bstmts =
                           ({skind = Break _; succs = [stmt]}|
                                 {skind = Goto ({contents=stmt},_)})::_}
                         when not (Stmt.Set.mem stmt loop_stmts) ->
                         let varinfos = Cil.extract_varinfos_from_exp exp
                         in let var_hints =
                           Varinfo.Set.fold
                             (fun vi lv ->
                                (*Format.printf "Inferring pragma for widening variable: %a.\n" Base.pretty (Base.Var vi);*)
                               Base.Set.add (Base.create_varinfo vi) lv)
                             varinfos
                             Base.Set.empty
                         in
                         List.iter
                           (fun widening_stmt ->
                              widen_hints :=
                                Widen_type.add_var_hints
                                  widening_stmt
                                  var_hints
                                  !widen_hints)
                           widening_stmts
                     | _ -> ())
                  [bl_then ; bl_else]
          end;
          Cil.DoChildren
      | _ -> 
	Cil.DoChildren
      end ;
    end
  method vexpr (e:exp) = begin
    let with_succ v = [v ; Ival.Widen_Hints.V.succ v]
    and with_pred v = [Ival.Widen_Hints.V.pred v ; v ]
    and with_s_p_ v = [Ival.Widen_Hints.V.pred v; v; Ival.Widen_Hints.V.succ v]
    and default_visit e =
      match Cil.isInteger e with
      | Some _int64 ->
          (*
            let v = Ival.Widen_Hints.V.of_int64 int64
            in widen_hints := Db.Widen_Hints.add_to_all v !widen_hints ;
          *)
          Cil.SkipChildren
      | _ -> 
	Cil.DoChildren
    and comparison_visit add1 add2 e1 e2 =
      let add key set =
        let hints =
          List.fold_right
            Ival.Widen_Hints.add
            set
            Ival.Widen_Hints.empty
        in
        (*Format.printf "Adding widen hint %a for base %a@\n" Ival.Widen_Hints.pretty hints
          Base.pretty key;*)
        widen_hints := 
	  Widen_type.add_num_hints
	  None (Widen_type.VarKey key) hints !widen_hints
      in
      begin
        let e1,e2 = Cil.constFold true e1, Cil.constFold true e2 in
        match (Cil.isInteger e1, Cil.isInteger e2, e1, e2) with
        | Some int64, _,
          _, {enode=(CastE(_, { enode=Lval (Var varinfo, _)})
			| Lval (Var varinfo, _))}->
            add
              (Base.create_varinfo varinfo)
              (add1 int64);
            Cil.SkipChildren
        | _, Some int64,
          {enode=(CastE(_, { enode=Lval (Var varinfo, _)})
		     | Lval (Var varinfo, _))}, _ ->
            add
              (Base.create_varinfo varinfo)
              (add2 int64);
            Cil.SkipChildren
        | _ -> 
	  Cil.DoChildren
      end
    in
    match e.enode with
    | BinOp (Lt, e1, e2, _)
    | BinOp (Gt, e2, e1, _)
    | BinOp (Le, e2, e1, _)
    | BinOp (Ge, e1, e2, _) ->
        comparison_visit with_succ with_pred e1 e2
    | BinOp (Eq, e1, e2, _)
    | BinOp (Ne, e1, e2, _) ->
        comparison_visit with_s_p_ with_s_p_ e1 e2
    | _ -> default_visit e
  end
end

let compute_widen_hints kf _s default_widen_hints = (* [s] isn't used yet *)
  let widen_hints =
    begin
      match kf.fundec with
        | Declaration _ -> default_widen_hints
        | Definition (fd,_) ->
            begin
              let widen_hints = ref default_widen_hints in
	      let visitor = new widen_visitor kf widen_hints None in
	      ignore (Visitor.visitFramacFunction visitor fd);
              !widen_hints
            end
    end
  in widen_hints

module Hints =
  Kernel_function.Make_Table
    (Widen_type)
    (struct
       let name = "Widen.Hints"
       let size = 97
       let dependencies = [ Ast.self ]
       let kind = `Tuning
     end)

let getWidenHints (kf:kernel_function) (s:stmt) =
  let widen_hints_map =
    Hints.memo (fun kf -> compute_widen_hints kf s Widen_type.default) kf
  in
  Widen_type.hints_from_keys s widen_hints_map

(*
Local Variables:
compile-command: "make -C ../.."
End:
*)
